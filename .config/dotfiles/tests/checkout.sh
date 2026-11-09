#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# shellcheck disable=SC2031 # Repository helpers deliberately isolate their variables in subshells.
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
trap 'printf "Checkout fixture failed at line %s\n" "$LINENO" >&2' ERR
umask 077
metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../install/worktree.sh
source "$metadata/install/worktree.sh"
stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-checkout-test.XXXXXX")
trap 'result=$?; if ((result)) && [[ -f "$stage/checkout.out" ]]; then cat "$stage/checkout.out" >&2; fi; rm -rf -- "$stage"; exit "$result"' EXIT
stage=$(cd "$stage" && pwd -P)
fixture="$stage/home workspace"
mkdir -p "$fixture/.config/dotfiles" "$fixture/.config/fish/conf.d" "$fixture/.config/fish/functions" "$fixture/.github/workflows"
cp "$metadata"/*.sh "$fixture/.config/dotfiles/"
cp -R "$metadata/bin" "$metadata/install" "$metadata/hooks" "$fixture/.config/dotfiles/"
# Prove full checkout does not need the platform-specific setup entry point.
printf '#!/bin/bash\necho "Unexpected setup invocation." >&2\nexit 91\n' > "$fixture/.config/dotfiles/setup.sh"
dotfiles_read_policy "$metadata/../../.dotfiles.git" "$metadata/../.." .gitignore > "$fixture/.gitignore"
printf '[attr]private filter=git-crypt diff=git-crypt -text\n.config/fish/conf.d/env.secret.fish private\n' > "$fixture/.gitattributes"
printf '.config/fish/conf.d/env.secret.fish\n' > "$fixture/.config/dotfiles/private-files"
printf 'set -gx CI_SECRET dummy\n' > "$fixture/.config/fish/conf.d/env.secret.fish"
printf '# shared fixture\n' > "$fixture/.config/fish/config.fish"
printf '# helper fixture\n' > "$fixture/.config/fish/functions/helper.fish"
printf 'README fixture\n' > "$fixture/README.md"
printf 'name: fixture\n' > "$fixture/.github/workflows/fixture.yml"
export GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
g() { command git --git-dir="$fixture/.dotfiles.git" --work-tree="$fixture" -C "$fixture" "$@"; }
git init --bare -q --initial-branch=main "$fixture/.dotfiles.git"
g config user.name 'Checkout Fixture'
g config user.email checkout@example.invalid
g crypt init > "$stage/keygen.log" 2>&1
/bin/bash "$metadata/key-file.sh" normalize "$fixture/.dotfiles.git/git-crypt/keys/default" --output "$fixture/.config/dotfiles/git-crypt.key"
g add -- .gitignore .gitattributes README.md .config
g add -f -- .github/workflows/fixture.yml
g commit -qm 'Disposable full checkout baseline'
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

remote="$stage/remote.git"
git init --bare -q --initial-branch=main "$remote"
g config remote.origin.url "$remote"
g push origin main > "$stage/baseline-push.out" 2>&1
cli() { (cd "$fixture" && /bin/bash .config/dotfiles/dotfile.sh "$@"); }
reject() {
    local result=0
    set +e
    "$@" > "$stage/rejected.out" 2>&1 || result=$?
    set -e
    ((result != 0)) || { echo 'An operation expected to fail succeeded.' >&2; exit 1; }
}
export TMPDIR="$stage/temporary directories"
mkdir -p "$TMPDIR" "$fixture/.local/state/dotfiles/shell.pending"
printf 'Legacy session data remains untouched\n' > "$fixture/.local/state/dotfiles/shell.pending/workspace"
printf '# unstaged HOME edit\n' >> "$fixture/.config/fish/config.fish"
printf '# staged HOME edit\n' >> "$fixture/.config/fish/functions/helper.fish"
g add -- .config/fish/functions/helper.fish
source_head=$(g rev-parse HEAD)
source_index=$(g hash-object "$fixture/.dotfiles.git/index")
workspace=$(cli checkout 2> "$stage/checkout.out")
w() { git -C "$workspace" "$@"; }
[[ "$workspace" == "$TMPDIR/dotfiles-checkout."* && -d "$workspace" ]]
[[ -f "$workspace/README.md" && -f "$workspace/.gitignore" && -f "$workspace/.gitattributes" && -f "$workspace/.github/workflows/fixture.yml" ]]
[[ $(w rev-parse --show-toplevel) == "$workspace" && $(w rev-parse HEAD) == "$source_head" ]]
[[ $(w config --get remote.origin.url) == "$remote" && $(w config --get branch.main.remote) == origin ]]
[[ $(w config --get core.hooksPath) == "$workspace/.config/dotfiles/hooks" ]]
[[ ! -f "$workspace/.config/dotfiles/setup-was-called" ]]
[[ -z $(w status --porcelain --untracked-files=all) ]]
/bin/bash "$metadata/key-file.sh" matches "$fixture/.config/dotfiles/git-crypt.key" "$workspace/.config/dotfiles/git-crypt.key"
[[ $(cat "$workspace/.config/fish/conf.d/env.secret.fish") == 'set -gx CI_SECRET dummy' ]]
if w config --get core.sparseCheckout > "$stage/sparse.out"; then [[ $(cat "$stage/sparse.out") != true ]]; fi
object=${source_head:0:2}/${source_head:2}
[[ ! "$fixture/.dotfiles.git/objects/$object" -ef "$workspace/.dotfiles.git/objects/$object" ]]
echo 'PASS: checkout returns a complete unlocked independent repository with native Git, remote tracking and encryption hooks; no terminal or shell initialization is needed.'

printf 'edited using ordinary Git\n' >> "$workspace/README.md"
printf 'name: added\n' > "$workspace/.github/workflows/added.yml"
printf '/.config/fish/ignored-ci\n' >> "$workspace/.gitignore"
printf 'set -gx CI_SECRET changed_dummy\n' > "$workspace/.config/fish/conf.d/env.secret.fish"
w add README.md .gitignore .config/fish/conf.d/env.secret.fish
w add --force .github/workflows/added.yml
w commit -qm 'Ordinary Git changes'
w cat-file blob HEAD:.config/fish/conf.d/env.secret.fish > "$stage/ciphertext"
header=$(dd if="$stage/ciphertext" bs=1 count=10 2>/dev/null | od -An -tx1 | tr -d ' \r\n')
[[ "$header" == 00474954435259505400 ]]
w push > "$stage/native-push.out" 2>&1
[[ $(command git --git-dir="$remote" rev-parse main) == "$(w rev-parse HEAD)" ]]
[[ $(g rev-parse HEAD) == "$source_head" && $(g hash-object "$fixture/.dotfiles.git/index") == "$source_index" ]]
grep -Fq 'unstaged HOME edit' "$fixture/.config/fish/config.fish"
g diff --cached --name-only | grep -Fxq .config/fish/functions/helper.fish
[[ $(cat "$fixture/.config/fish/conf.d/env.secret.fish") == 'set -gx CI_SECRET dummy' ]]
[[ $(cat "$fixture/.local/state/dotfiles/shell.pending/workspace") == 'Legacy session data remains untouched' ]]
echo 'PASS: ordinary git add/commit/push encrypts private files and publishes to the configured remote while HOME commits, staging, local edits and legacy session data remain unchanged.'

cli pull > "$stage/pull.out" 2>&1
[[ $(g rev-parse HEAD) == "$(w rev-parse HEAD)" ]]
[[ ! -e "$fixture/README.md" && ! -e "$fixture/.github" && ! -e "$fixture/.gitignore" && ! -e "$fixture/.gitattributes" ]]
grep -Fq changed_dummy "$fixture/.config/fish/conf.d/env.secret.fish"
grep -Fq 'unstaged HOME edit' "$fixture/.config/fish/config.fish"
g diff --cached --name-only | grep -Fxq .config/fish/functions/helper.fish
g check-ignore -q .config/fish/ignored-ci
cli verify > "$stage/verify.out"
echo 'PASS: dotfile pull applies the published maintenance changes, preserves local edits and keeps project metadata out of sparse HOME.'

safe_tip=$(w rev-parse HEAD)
blob=$(printf 'PLAINTEXT_PRIVATE_CANARY\n' | w hash-object -w --stdin)
w update-index --cacheinfo "100644,$blob,.config/fish/conf.d/env.secret.fish"
reject w commit -qm 'Must reject plaintext'
grep -Fq '[BLOCKED]' "$stage/rejected.out"
w -c core.hooksPath=/dev/null commit -qm 'Bypassed plaintext fixture'
reject w push
grep -Fq 'Push blocked:' "$stage/rejected.out"
[[ $(command git --git-dir="$remote" rev-parse main) == "$safe_tip" && $(g rev-parse HEAD) == "$safe_tip" ]]
w reset --hard "$safe_tip" > "$stage/reset.out" 2>&1
reject /bin/bash "$workspace/.config/dotfiles/dotfile.sh" key rotate
grep -Fq 'Rotate the key from the normal dotfiles workspace.' "$stage/rejected.out"
printf 'uncommitted maintenance edit\n' >> "$workspace/README.md"
[[ -f "$workspace/README.md" ]]
second_workspace=$("$BASH" "$fixture/.config/dotfiles/checkout.sh" 2> "$stage/second-checkout.out")
[[ "$second_workspace" != "$workspace" && -f "$workspace/README.md" ]]
grep -Fq 'uncommitted maintenance edit' "$workspace/README.md"
reject cli checkout extra
reject cli shell
mkdir -p "$fixture/.local/state/dotfiles/key-rotation.pending"
reject cli checkout
grep -Fq 'key rotation is pending' "$stage/rejected.out"
rmdir "$fixture/.local/state/dotfiles/key-rotation.pending"
g remote remove origin
reject cli checkout
grep -Fq 'Configure origin' "$stage/rejected.out"
g remote add origin "$remote"
before_failure=$(printf '%s\n' "$TMPDIR"/dotfiles-checkout.*)
mv "$fixture/.config/dotfiles/git-crypt.key" "$stage/saved.key"
reject "$BASH" "$fixture/.config/dotfiles/checkout.sh"
mv "$stage/saved.key" "$fixture/.config/dotfiles/git-crypt.key"
[[ $(printf '%s\n' "$TMPDIR"/dotfiles-checkout.*) == "$before_failure" ]]
echo 'PASS: native pre-commit and pre-push reject plaintext even after a hook bypass; independent checkouts retain unfinished edits, and invalid/unsafe requests are refused.'
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
    cp -R "$metadata/bin" "$metadata/install" "$metadata/hooks" "$fixture/.config/dotfiles/"
    # shellcheck source=../install/worktree.sh
    source "$metadata/install/worktree.sh"
    dotfiles_read_policy "$metadata/../../.dotfiles.git" "$metadata/../.." .gitignore > "$fixture/.gitignore"
    printf '[attr]private filter=git-crypt diff=git-crypt -text\n.config/fish/conf.d/env.secret.fish private\n' > "$fixture/.gitattributes"
    printf '.config/fish/conf.d/env.secret.fish\n' > "$fixture/.config/dotfiles/private-files"
    printf 'set -gx CI_SECRET dummy\n' > "$fixture/.config/fish/conf.d/env.secret.fish"
    printf 'Disposable local-only fixture\n' > "$fixture/README.md"
    export GIT_CONFIG_GLOBAL=/dev/null
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
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
    mkdir -p "$fixture/.config/example"
    printf 'public machine identity example\n' > "$fixture/.config/dotfiles/machine.example"
    printf 'public example\n' > "$fixture/.config/example/config.secret.example"
    printf 'private synthetic fixture\n' > "$fixture/.config/example/config.secret"
    cli add .config/dotfiles/machine.example .config/example/config.secret.example
    cli add --encrypt .config/example/config.secret
    g commit -qm 'Allowed public and encrypted private changes'
    g push origin main > "$stage/allowed-push.out" 2>&1
    [[ $(command git --git-dir="$remote" rev-parse main) == "$(g rev-parse HEAD)" ]]
    g cat-file blob HEAD:.config/example/config.secret > "$stage/ciphertext"
    g crypt smudge < "$stage/ciphertext" | cmp -s - "$fixture/.config/example/config.secret"
    echo 'PASS: public examples and newly encrypted files commit and push with unchanged plaintext contents.'
)
check_local_only_paths

echo 'ALL SPARSE WORKSPACE, FULL CHECKOUT AND GIT POLICY CHECKS PASSED.'
