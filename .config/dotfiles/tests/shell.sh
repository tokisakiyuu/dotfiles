#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# shellcheck disable=SC2031 # Repository helpers deliberately isolate their variables in subshells.
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
trap 'printf "Shell fixture failed at line %s\n" "$LINENO" >&2' ERR
umask 077
metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../install/worktree.sh
source "$metadata/install/worktree.sh"
stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-shell-test.XXXXXX")
trap 'result=$?; if ((result)) && [[ -f "$stage/session.out" ]]; then cat "$stage/session.out" >&2; fi; rm -rf -- "$stage"; exit "$result"' EXIT
stage=$(cd "$stage" && pwd -P)
fixture="$stage/home workspace"
mkdir -p "$fixture/.config/dotfiles" "$fixture/.config/fish/conf.d" "$fixture/.config/fish/functions" "$fixture/.github/workflows"
cp "$metadata"/*.sh "$fixture/.config/dotfiles/"
cp -R "$metadata/install" "$metadata/hooks" "$fixture/.config/dotfiles/"
# Prove temporary shells do not need the platform-specific setup entry point.
printf '#!/bin/bash\necho "Unexpected setup invocation." >&2\nexit 91\n' > "$fixture/.config/dotfiles/setup.sh"
dotfiles_read_policy "$metadata/../../.dotfiles.git" "$metadata/../.." .gitignore > "$fixture/.gitignore"
cp "$metadata/../../.config/fish/functions/dotfile.fish" "$fixture/.config/fish/functions/"
printf '[attr]private filter=git-crypt diff=git-crypt -text\n.config/fish/conf.d/env.secret.fish private\n' > "$fixture/.gitattributes"
printf '.config/fish/conf.d/env.secret.fish\n' > "$fixture/.config/dotfiles/private-files"
printf 'set -gx CI_SECRET dummy\n' > "$fixture/.config/fish/conf.d/env.secret.fish"
printf '# shared fixture\n' > "$fixture/.config/fish/config.fish"
printf '# helper fixture\n' > "$fixture/.config/fish/functions/helper.fish"
printf 'README fixture\n' > "$fixture/README.md"
printf 'name: fixture\n' > "$fixture/.github/workflows/fixture.yml"
export GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE DOTFILES_SHELL_ROOT
g() { command git --git-dir="$fixture/.dotfiles.git" --work-tree="$fixture" -C "$fixture" "$@"; }
git init --bare -q --initial-branch=main "$fixture/.dotfiles.git"
g config user.name 'Shell Fixture'
g config user.email shell@example.invalid
g crypt init > "$stage/keygen.log" 2>&1
/bin/bash "$metadata/key-file.sh" normalize "$fixture/.dotfiles.git/git-crypt/keys/default" --output "$fixture/.config/dotfiles/git-crypt.key"
g add -- .gitignore .gitattributes README.md .config
g add -f -- .github/workflows/fixture.yml
g commit -qm 'Disposable shell baseline'
g config remote.origin.url https://github.com/tokisakiyuu/dotfiles.git
g update-ref refs/remotes/origin/main HEAD
(
    # shellcheck source=../install/lib.sh
    source "$fixture/.config/dotfiles/install/lib.sh"
    write_machine macmini-m4 "$fixture/.config/dotfiles/machine"
    configure_dotfiles_repository "$fixture"
)
[[ ! -e "$fixture/README.md" && ! -e "$fixture/.gitignore" && ! -e "$fixture/.github" ]]
[[ ! -e "$fixture/.gitattributes" ]]
[[ -f "$fixture/.config/fish/config.fish" && ! -L "$fixture/.config/fish/config.fish" ]]
echo 'PASS: sparse HOME contains real configuration files while project metadata stays tracked and absent.'

cat > "$stage/driver.sh" <<'DRIVER'
#!/bin/bash
# shellcheck disable=SC1090 # Fixture source and command file are explicit driver arguments.
set -euo pipefail
source "$1/.config/dotfiles/shell.sh"
export DOTFILES_TEST_COMMANDS=$2 DOTFILES_TEST_VISITED=$3 DOTFILES_TEST_SOURCE=$1
mkdir -p "$(dirname "$shell_pending")"
shell_open() {
    printf '%s\n' "$PWD" > "$DOTFILES_TEST_VISITED"
    # Real fish/Git/git-crypt, scripted input, no user startup or history writes.
    command fish --no-config --private < "$DOTFILES_TEST_COMMANDS"
}
shell_main
DRIVER
run_session() { /bin/bash "$stage/driver.sh" "$fixture" "$stage/commands.fish" "$stage/visited" > "$stage/session.out" 2>&1; }
bad_session() { if run_session; then echo 'A session expected to retain its workspace succeeded.' >&2; exit 1; fi; }
cli() { (cd "$fixture" && /bin/bash .config/dotfiles/dotfile.sh "$@"); }
printf '# unstaged HOME edit\n' >> "$fixture/.config/fish/config.fish"
printf '# staged HOME edit\n' >> "$fixture/.config/fish/functions/helper.fish"
g add -- .config/fish/functions/helper.fish
cat > "$stage/commands.fish" <<'FISH'
source .config/fish/functions/dotfile.fish
test -f README.md; and test -f .gitignore; and test -f .github/workflows/fixture.yml; or exit 99
git rev-parse --verify refs/remotes/origin/main >/dev/null; or exit 99
printf 'edited from temporary shell\n' >> README.md
printf 'name: added\n' > .github/workflows/added.yml
printf '/.config/fish/ignored-ci\n' >> .gitignore
printf 'set -gx CI_SECRET changed_dummy\n' > .config/fish/conf.d/env.secret.fish
git add README.md .gitignore; or exit 99
dotfile add .github/workflows/added.yml .config/fish/conf.d/env.secret.fish; or exit 99
dotfile diff --staged >/dev/null; or exit 99
dotfile commit 'Temporary shell changes'; or exit 99
exit 0
FISH
run_session
workspace=$(cat "$stage/visited")
[[ "$workspace" == "$fixture/.local/state/dotfiles/shell.pending/"* ]]
[[ ! -e "$workspace" && ! -e "$fixture/.local/state/dotfiles/shell.pending" ]]
g show HEAD:README.md | grep -Fq 'edited from temporary shell'
g cat-file -e HEAD:.github/workflows/added.yml
[[ ! -e "$fixture/README.md" && ! -e "$fixture/.github" && ! -e "$fixture/.gitignore" ]]
grep -Fq 'unstaged HOME edit' "$fixture/.config/fish/config.fish"
g diff --cached --name-only | grep -Fxq .config/fish/functions/helper.fish
grep -Fq changed_dummy "$fixture/.config/fish/conf.d/env.secret.fish"
g check-ignore -q .config/fish/ignored-ci
cli verify > "$stage/verify.out"
echo 'PASS: real fish, native Git and dotfile commit share a full temporary view; encrypted changes import safely, HOME edits survive, and clean exit deletes the workspace.'

cat > "$stage/commands.fish" <<'FISH'
printf 'saved but not staged\n' >> README.md
printf 'name: forgotten\n' > .github/workflows/forgotten.yml
exit 0
FISH
bad_session
workspace=$(cat "$stage/visited")
[[ -f "$workspace/README.md" && -f "$workspace/.github/workflows/forgotten.yml" ]]
cat > "$stage/commands.fish" <<'FISH'
source .config/fish/functions/dotfile.fish
dotfile add README.md .github/workflows/forgotten.yml; or exit 99
dotfile commit 'Resume saved edits'; or exit 99
exit 0
FISH
run_session
[[ $(cat "$stage/visited") == "$workspace" && ! -e "$workspace" ]]
g show HEAD:README.md | grep -Fq 'saved but not staged'
echo 'PASS: uncommitted and ignored new files are retained, and the next session resumes exactly that workspace.'

printf 'exit 7\n' > "$stage/commands.fish"
bad_session
workspace=$(cat "$stage/visited")
[[ -d "$workspace" ]]
printf 'exit 0\n' > "$stage/commands.fish"
run_session
[[ ! -e "$workspace" ]]
echo 'PASS: a failing subshell retains its workspace and a later clean exit completes cleanup.'

cat > "$stage/commands.fish" <<'FISH'
printf 'stashed fixture\n' >> README.md
git stash push -m 'Retained stash fixture'; or exit 99
exit 0
FISH
bad_session
workspace=$(cat "$stage/visited")
[[ -d "$workspace" ]]
cat > "$stage/commands.fish" <<'FISH'
git stash pop; and git add README.md; and git commit -m 'Apply retained stash'; or exit 99
exit 0
FISH
run_session
[[ ! -e "$workspace" ]]
cat > "$stage/commands.fish" <<'FISH'
git switch -c shell-branch-fixture; or exit 99
printf 'extra branch fixture\n' >> README.md
git add README.md; and git commit -m 'Retained branch fixture'; and git switch main; or exit 99
exit 0
FISH
bad_session
workspace=$(cat "$stage/visited")
[[ -d "$workspace" ]]
printf 'git merge --ff-only shell-branch-fixture; or exit 99\nexit 0\n' > "$stage/commands.fish"
run_session
[[ ! -e "$workspace" ]]
echo 'PASS: stashes and additional unmerged branches prevent cleanup; applying or merging them allows a safe retry.'

cat > "$stage/commands.fish" <<'FISH'
git --git-dir="$DOTFILES_TEST_SOURCE/.dotfiles.git" --work-tree="$DOTFILES_TEST_SOURCE" -C "$DOTFILES_TEST_SOURCE" commit -m 'Concurrent HOME commit'; or exit 99
printf 'session diverged\n' >> README.md
git add README.md; and git commit -m 'Diverged session'; or exit 99
exit 0
FISH
bad_session
workspace=$(cat "$stage/visited")
[[ -d "$workspace" && $(g log -1 --format=%s) == 'Concurrent HOME commit' ]]
cat > "$stage/commands.fish" <<'FISH'
git fetch "$DOTFILES_TEST_SOURCE/.dotfiles.git" main; and git rebase FETCH_HEAD; or exit 99
exit 0
FISH
run_session
[[ ! -e "$workspace" && $(g log -1 --format=%s) == 'Diverged session' ]]
echo 'PASS: concurrent commits block fast-forward without rewriting HOME; resolving inside the retained shell allows a safe retry.'

head_before=$(g rev-parse HEAD)
cp "$fixture/.config/fish/config.fish" "$stage/home-before-conflict"
cat > "$stage/commands.fish" <<'FISH'
printf '# conflicting session edit\n' >> .config/fish/config.fish
git add .config/fish/config.fish; and git commit -m 'Overlapping edit fixture'; or exit 99
exit 0
FISH
bad_session
[[ $(g rev-parse HEAD) == "$head_before" ]]
cmp -s "$fixture/.config/fish/config.fish" "$stage/home-before-conflict"
printf 'git reset --hard HEAD^; or exit 99\nexit 0\n' > "$stage/commands.fish"
run_session
[[ -z $(g for-each-ref --format='%(refname)' refs/dotfiles/shell/) ]]
echo 'PASS: overlapping HOME edits prevent import without changing HEAD or local bytes; abandoning the temporary commit cleans up its private import ref.'

head_before=$(g rev-parse HEAD)
cat > "$stage/commands.fish" <<'FISH'
printf 'set -gx CI_SECRET plaintext_fixture\n' > .config/fish/conf.d/env.secret.fish
git -c filter.git-crypt.clean=cat -c filter.git-crypt.required=false add .config/fish/conf.d/env.secret.fish; or exit 99
git -c core.hooksPath=/dev/null commit -m 'Bypassed encryption fixture'; or exit 99
exit 0
FISH
bad_session
[[ $(g rev-parse HEAD) == "$head_before" ]]
grep -Fq '[BLOCKED]' "$stage/session.out"
echo 'PASS: native Git hook bypass cannot import a plaintext private blob; source history is unchanged and the temporary workspace is retained.'
printf 'git reset --hard HEAD^; or exit 99\nexit 0\n' > "$stage/commands.fish"
run_session
head_before=$(g rev-parse HEAD)
cat > "$stage/commands.fish" <<'FISH'
git add -f .config/dotfiles/git-crypt.key; or exit 99
if git commit -m 'Key should be blocked'
    exit 99
end
git -c core.hooksPath=/dev/null commit -m 'Bypassed key fixture'; or exit 99
exit 0
FISH
bad_session
[[ $(g rev-parse HEAD) == "$head_before" ]]
grep -Fq 'local-only paths must not be tracked' "$stage/session.out"
printf 'git reset --hard HEAD^; or exit 99\nexit 0\n' > "$stage/commands.fish"
run_session
echo 'PASS: native Git cannot accidentally commit local key files through the hook, and bypassed commits cannot import them into HOME.'
printf 'private addition fixture\n' > "$fixture/.config/fish/conf.d/added.secret.fish"
cli add --encrypt .config/fish/conf.d/added.secret.fish
[[ ! -e "$fixture/.gitattributes" && ! -e "$fixture/.gitignore" ]]
cli unstage
[[ -f "$fixture/.gitattributes" ]]
grep -Fq added.secret.fish "$fixture/.gitattributes"
cli add
cli add .config/fish/conf.d/added.secret.fish
[[ ! -e "$fixture/.gitattributes" ]]
cli verify > "$stage/added-encryption.out"
cli remove .config/fish/conf.d/added.secret.fish > "$stage/remove.out"
[[ -f "$fixture/.config/fish/conf.d/added.secret.fish" && ! -e "$fixture/.gitignore" ]]
cli unstage
[[ -f "$fixture/.gitignore" ]]
g check-ignore -q .config/fish/conf.d/added.secret.fish
cli add
[[ ! -e "$fixture/.gitignore" ]]
cli commit 'Stage HOME edits before fixture rotation' > "$stage/commit-home.out"
echo 'PASS: add --encrypt, remove, unstage, add without paths and commit preserve policy edits, sparse metadata and real HOME files without invoking macOS setup.'
if [[ $(uname -s) == Darwin ]]; then
    cp "$metadata/setup.sh" "$fixture/.config/dotfiles/setup.sh"
    cli add .config/dotfiles/setup.sh
    cli commit 'Restore macOS setup before fixture rotation' > "$stage/restore-setup.out"
    (
        # shellcheck source=../rotate-key.sh
        source "$fixture/.config/dotfiles/rotate-key.sh"
        rotation_open_terminal() { exec 3>/dev/null; }
        rotation_ask() { rotation_answer=y; }
        rotation_main
    ) > "$stage/rotate.out" 2>&1
    [[ ! -e "$fixture/README.md" && ! -e "$fixture/.github" && ! -e "$fixture/.gitignore" && ! -e "$fixture/.gitattributes" ]]
    cli verify > "$stage/rotated-encryption.out"
    echo 'PASS: macOS key rotation also preserves the sparse HOME layout.'
fi
# Exercise the same policy through native Git, including repaired history.
check_local_only_paths() (
    trap 'printf "Local-only fixture failed at line %s\n" "$LINENO" >&2' ERR
    umask 077
    metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
    stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-local-only.XXXXXX")
    trap 'rm -rf -- "$stage"' EXIT
    fixture="$stage/home workspace"
    remote="$stage/remote.git"
    mkdir -p "$fixture/.config/dotfiles" "$fixture/.config/fish/conf.d"
    cp "$metadata"/*.sh "$fixture/.config/dotfiles/"
    cp -R "$metadata/install" "$metadata/hooks" "$fixture/.config/dotfiles/"
    # shellcheck source=../install/worktree.sh
    source "$metadata/install/worktree.sh"
    dotfiles_read_policy "$metadata/../../.dotfiles.git" "$metadata/../.." .gitignore > "$fixture/.gitignore"
    printf '[attr]private filter=git-crypt diff=git-crypt -text\n.config/fish/conf.d/env.secret.fish private\n' > "$fixture/.gitattributes"
    printf '.config/fish/conf.d/env.secret.fish\n' > "$fixture/.config/dotfiles/private-files"
    printf 'set -gx CI_SECRET dummy\n' > "$fixture/.config/fish/conf.d/env.secret.fish"
    printf 'Disposable local-only fixture\n' > "$fixture/README.md"
    export GIT_CONFIG_GLOBAL=/dev/null
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE DOTFILES_SHELL_ROOT
    g() { command git --git-dir="$fixture/.dotfiles.git" --work-tree="$fixture" -C "$fixture" "$@"; }
    cli() { (cd "$fixture" && /bin/bash .config/dotfiles/dotfile.sh "$@"); }
    reject() {
        local result=0
        # Bash 3.2's command builtin can trigger errexit even in an if condition.
        set +e
        "$@" > "$stage/rejected.out" 2>&1 || result=$?
        set -e
        if ((result == 0)); then
            echo 'A local-only operation unexpectedly succeeded.' >&2; exit 1
        fi
    }
    git init --bare -q --initial-branch=main "$fixture/.dotfiles.git"
    g config user.name 'Local-only Fixture'
    g config user.email local-only@example.invalid
    g config dotfiles.fullWorktree true
    g config core.hooksPath "$fixture/.config/dotfiles/hooks"
    g crypt init > "$stage/keygen.out" 2>&1
    g add --force -- .gitignore .gitattributes README.md .config/dotfiles .config/fish/conf.d/env.secret.fish
    g commit -qm 'Disposable encrypted baseline'
    git init --bare -q --initial-branch=main "$remote"
    g remote add origin "$remote"
    g push origin main > "$stage/baseline-push.out" 2>&1
    baseline=$(g rev-parse HEAD)
    baseline_tree=$(g write-tree)

    # A partially updated working tree must fail closed, even when the old
    # shared library can be sourced successfully but lacks the new function.
    cp "$fixture/.config/dotfiles/install/worktree.sh" "$stage/policy-library"
    printf '# Synthetic incomplete update: no shared policy yet.\n' > "$fixture/.config/dotfiles/install/worktree.sh"
    reject cli status
    grep -Fq 'Local-only path policy is unavailable' "$stage/rejected.out"
    reject g commit --allow-empty -qm 'Must reject an incomplete policy update'
    grep -Fq 'Local-only path policy is unavailable' "$stage/rejected.out"
    candidate=$(printf 'Incomplete working-tree policy fixture\n' | g commit-tree "$baseline_tree" -p "$baseline")
    g update-ref refs/heads/missing-policy-fixture "$candidate"
    reject g push origin refs/heads/missing-policy-fixture:refs/heads/missing-policy-fixture
    grep -Fq 'Local-only path policy is unavailable' "$stage/rejected.out"
    [[ -z $(command git --git-dir="$remote" for-each-ref --format='%(refname)' refs/heads/missing-policy-fixture) ]]
    g update-ref -d refs/heads/missing-policy-fixture
    cp "$stage/policy-library" "$fixture/.config/dotfiles/install/worktree.sh"
    echo 'PASS: an incomplete policy update blocks the CLI, native commits and pushes.'

    # Deliberately force-add ignored files using native Git, as a GUI can do.
    # All contents are canaries, never the generated or personal unlock key.
    reserved_paths=(
        .claude/settings.json
        .local/state/dotfiles/backup/key.txt
        .local/state/dotfiles-migration/backup/key.txt
        .local/share/chezmoi/dot_config/config
        .config/dotfiles/machine
        .config/dotfiles/local.fish
        .config/dotfiles/backup-location
        .config/fish/fish_variables
        .config/dotfiles/git-crypt.key
        .config/dotfiles/nested/fixture.key
        .config/dotfiles/.git-crypt.key.TEST/key
        .config/dotfiles/.machine.TEST
    )
    for path in "${reserved_paths[@]}"; do
        mkdir -p "$(dirname "$fixture/$path")"
        printf 'LOCAL_ONLY_CANARY_NOT_A_REAL_SECRET\n' > "$fixture/$path"
        reject cli add "$path"
        grep -Fq 'This path is reserved for local data:' "$stage/rejected.out"
        g add --force -- "$path"
        reject g commit -qm 'Must reject a forced local-only file'
        grep -Fq "[BLOCKED] $path: local-only paths must not be tracked" "$stage/rejected.out"
        [[ $(g rev-parse HEAD) == "$baseline" ]]

        # Bypass pre-commit with plumbing, then remove the file in the tip.
        # A real push must still reject the sensitive ancestor commit.
        bad_tree=$(g write-tree)
        bad_commit=$(printf 'Bypassed hook with a local-only canary\n' | g commit-tree "$bad_tree" -p "$baseline")
        repaired_commit=$(printf 'Removed canary from tip\n' | g commit-tree "$baseline_tree" -p "$bad_commit")
        g update-ref refs/heads/local-only-fixture "$repaired_commit"
        reject g push origin refs/heads/local-only-fixture:refs/heads/local-only-fixture
        grep -Fq "$path: local-only paths must not be tracked" "$stage/rejected.out"
        grep -Fq 'Push blocked:' "$stage/rejected.out"
        remote_ref=$(command git --git-dir="$remote" for-each-ref --format='%(refname)' refs/heads/local-only-fixture)
        if [[ -n "$remote_ref" ]]; then
            echo 'A blocked branch reached the remote.' >&2; exit 1
        fi
        g update-ref -d refs/heads/local-only-fixture
        g restore --staged -- "$path"
        [[ -f "$fixture/$path" ]]
    done
    printf 'PASS: CLI, native pre-commit and real pre-push reject %d local-only paths, including ancestors removed from the tip.\n' "${#reserved_paths[@]}"

    # Index plumbing can also name the bare repository itself; never modify its
    # actual configuration just to test the guard.
    blob=$(printf 'LOCAL_ONLY_CANARY_NOT_A_REAL_SECRET\n' | g hash-object -w --stdin)
    g update-index --add --cacheinfo "100644,$blob,.dotfiles.git/config"
    reject g commit -qm 'Must reject repository metadata'
    grep -Fq '[BLOCKED] .dotfiles.git/config:' "$stage/rejected.out"
    reject cli add .dotfiles.git/config
    reject cli add .git/config
    g restore --staged -- .dotfiles.git/config

    # Declaring a reserved file encrypted must not make it eligible for tracking.
    path=.config/dotfiles/.git-crypt.key.TEST/key
    cp "$fixture/.gitattributes" "$stage/attributes"
    printf '\n%s private\n' "$path" >> "$fixture/.gitattributes"
    g add --force -- .gitattributes "$path"
    g cat-file blob ":$path" > "$stage/ciphertext"
    header=$(dd if="$stage/ciphertext" bs=1 count=10 2>/dev/null | od -An -tx1 | tr -d ' \r\n')
    [[ "$header" == 00474954435259505400 ]]
    reject g commit -qm 'Must reject an encrypted local-only key'
    grep -Fq "[BLOCKED] $path: local-only paths must not be tracked" "$stage/rejected.out"
    cp "$stage/attributes" "$fixture/.gitattributes"
    g restore --staged -- .gitattributes "$path"
    echo 'PASS: repository metadata and encrypted temporary keys remain forbidden.'

    # Public paths near reserved names and newly declared private files still work.
    mkdir -p "$fixture/.config/dotfiles/machines" "$fixture/.config/example"
    printf '# Public machine helper\n' >> "$fixture/.config/dotfiles/machine.fish"
    printf '# Public machine settings\n' > "$fixture/.config/dotfiles/machines/fixture.fish"
    printf 'public example\n' > "$fixture/.config/example/config.secret.example"
    printf 'private synthetic fixture\n' > "$fixture/.config/example/config.secret"
    cli add .config/dotfiles/machine.fish .config/dotfiles/machines/fixture.fish .config/example/config.secret.example
    cli add --encrypt .config/example/config.secret
    g commit -qm 'Allowed public and encrypted private changes'
    g push origin main > "$stage/allowed-push.out" 2>&1
    [[ $(command git --git-dir="$remote" rev-parse main) == "$(g rev-parse HEAD)" ]]
    g cat-file blob HEAD:.config/example/config.secret > "$stage/ciphertext"
    g crypt smudge < "$stage/ciphertext" | cmp -s - "$fixture/.config/example/config.secret"
    echo 'PASS: public machine files, examples and newly encrypted files commit and push with unchanged plaintext contents.'
)
check_local_only_paths

echo 'ALL SPARSE WORKSPACE AND TEMPORARY SHELL CHECKS PASSED.'
