#!/bin/bash
# shellcheck source-path=SCRIPTDIR
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
    # shellcheck source=../setup.sh
    source "$fixture/.config/dotfiles/setup.sh"
    setup_dotfiles "$fixture" macmini-m4 --configure-only
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
(
    # shellcheck source=../rotate-key.sh
    source "$fixture/.config/dotfiles/rotate-key.sh"
    rotation_open_terminal() { exec 3>/dev/null; }
    rotation_ask() { rotation_answer=y; }
    rotation_main
) > "$stage/rotate.out" 2>&1
[[ ! -e "$fixture/README.md" && ! -e "$fixture/.github" && ! -e "$fixture/.gitignore" && ! -e "$fixture/.gitattributes" ]]
cli verify > "$stage/rotated-encryption.out"
echo 'PASS: add --encrypt, remove, unstage, add without paths, commit and key rotation all preserve policy edits, sparse metadata and real HOME files.'
echo 'ALL SPARSE WORKSPACE AND TEMPORARY SHELL CHECKS PASSED.'
