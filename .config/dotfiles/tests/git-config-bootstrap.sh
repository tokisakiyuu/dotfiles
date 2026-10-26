#!/bin/bash
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077
metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
live=$(cd "$metadata/../.." && pwd -P)
stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-config-bootstrap.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
stage=$(cd "$stage" && pwd -P)
source_root="$stage/source"
mkdir -p "$source_root/.config/dotfiles" "$source_root/.config/git"
cp "$metadata"/*.sh "$source_root/.config/dotfiles/"
cp -R "$metadata/install" "$metadata/hooks" "$source_root/.config/dotfiles/"
cp "$live/.gitignore" "$live/.gitattributes" "$source_root/"
printf '.config/git/config.secret\n' > "$source_root/.config/dotfiles/private-files"
printf '[include]\n\tpath = ./config.secret\n' > "$source_root/.config/git/config"
printf '[user]\n\tname = Bootstrap Fixture\n\temail = bootstrap@example.invalid\n' > "$source_root/.config/git/config.secret"
cp "$source_root/.config/git/config.secret" "$stage/plain-config"
export GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
g() { command git --git-dir="$source_root/.dotfiles.git" --work-tree="$source_root" -C "$source_root" "$@"; }
git init --bare -q --initial-branch=main "$source_root/.dotfiles.git"
g config user.name 'Bootstrap Fixture'
g config user.email bootstrap@example.invalid
g crypt init > "$stage/init.log" 2>&1
bash "$metadata/key-file.sh" normalize "$source_root/.dotfiles.git/git-crypt/keys/default" --output "$stage/key"
printf '#!/bin/bash\necho "Stale setup was not updated." >&2\nexit 91\n' > "$source_root/.config/dotfiles/setup.sh"
g add -- .gitignore .gitattributes .config/dotfiles .config/git
g commit -qm 'disposable incomplete setup version'
make_locked_target() {
    local target=$1
    mkdir -p "$target/.local/share/tmux/oh-my-tmux"
    git clone --bare -q "$source_root/.dotfiles.git" "$target/.dotfiles.git"
    git --git-dir="$target/.dotfiles.git" config --local remote.origin.url https://github.com/tokisakiyuu/dotfiles.git
    git --git-dir="$target/.dotfiles.git" --work-tree="$target" -C "$target" checkout > "$stage/checkout.log" 2>&1
    printf 'fixture\n' > "$target/.local/share/tmux/oh-my-tmux/.tmux.conf"
    printf 'fixture\n' > "$target/.local/share/tmux/oh-my-tmux/.tmux.conf.local"
}
stale_target="$stage/stale target"
make_locked_target "$stale_target"
result=0
env -u GIT_CONFIG_GLOBAL XDG_CONFIG_HOME="$stale_target/.config" /usr/bin/git config --global --list > "$stage/unisolated.log" 2>&1 || result=$?
[[ "$result" == 128 ]]
grep -Fq 'bad config line 1' "$stage/unisolated.log"
echo 'PASS: reproduced the native Git failure by loading the real ciphertext include, without touching HOME or real keys.'
cp "$metadata/setup.sh" "$source_root/.config/dotfiles/setup.sh"
g add -- .config/dotfiles/setup.sh
g commit -qm 'disposable corrected setup version'

cat > "$stage/driver.sh" <<'DRIVER'
#!/bin/bash
# shellcheck disable=SC1090 # Source the caller-provided fixture bootstrap/setup.
set -euo pipefail
script=$1 source_repo=$2 fixture_key=$3 destination=$4 log=$5
export XDG_CONFIG_HOME="$destination/.config"
source "$script"
exec 3</dev/null
trap cleanup_key EXIT
git() {
    if [[ $1 == clone ]]; then
        command git clone --bare -- "$source_repo" "$5"
        command git --git-dir="$5" config --local remote.origin.url "$DOTFILES_REPOSITORY_URL"
        mkdir -p "$destination/.local/share/tmux/oh-my-tmux"
        printf 'fixture\n' > "$destination/.local/share/tmux/oh-my-tmux/.tmux.conf"
        printf 'fixture\n' > "$destination/.local/share/tmux/oh-my-tmux/.tmux.conf.local"
    elif [[ ${2:-} == fetch ]]; then
        command git "$1" fetch --no-tags "$source_repo" '+refs/heads/main:refs/remotes/origin/main'
    else command git "$@"; fi
}
unisolated_git_read() {
    env -u GIT_CONFIG_GLOBAL /usr/bin/git config --global --list > /dev/null
}
brew() {
    unisolated_git_read
    printf 'brew %s\n' "$*" >> "$log"
    if [[ ${DOTFILES_TEST_FAIL_BREW:-} == 1 ]]; then return 39; fi
}
bash() {
    case "$1" in
        */setup.sh)
            local setup_script=$1 machine=$2
            shift 2
            (source "$setup_script"; setup_dotfiles "$destination" "$machine" "$@") ;;
        */install/brew.sh)
            unisolated_git_read
            printf 'bootstrap-brew\n' >> "$log" ;;
        *) command /bin/bash "$@" ;;
    esac
}
restore_dotfiles "$fixture_key" macmini-m4 "$destination" --skip-packages --skip-defaults --keep-shell
unisolated_git_read
DRIVER
run_restore() { /bin/bash "$stage/driver.sh" "$metadata/bootstrap.sh" "$source_root/.dotfiles.git" "${2:-$stage/key}" "$1" "$stage/package.log"; }
run_restore "$stale_target" > "$stage/resume.log" 2>&1
[[ $(git --git-dir="$stale_target/.dotfiles.git" rev-parse HEAD) == "$(g rev-parse HEAD)" ]]
cmp -s "$stale_target/.config/git/config.secret" "$stage/plain-config"
[[ ! -e "$stale_target/.local/state/dotfiles/git-config.pending" ]]
echo 'PASS: an existing locked clone fast-forwards to corrected scripts, installs prerequisites with unisolated Git subprocesses, and decrypts its Git config.'
fresh_target="$stage/fresh target"
run_restore "$fresh_target" > "$stage/fresh.log" 2>&1
cmp -s "$fresh_target/.config/git/config.secret" "$stage/plain-config"
printf '\n# preserved local edit\n' >> "$fresh_target/.config/git/config.secret"
cp "$fresh_target/.config/git/config.secret" "$stage/edited-config"
run_restore "$fresh_target" > "$stage/repeat.log" 2>&1
cmp -s "$fresh_target/.config/git/config.secret" "$stage/edited-config"
echo 'PASS: fresh bootstrap and rerun both work; already decrypted local Git config edits are preserved.'

for variant in invalid different; do
    retry_target="$stage/$variant key-copy target"
    make_locked_target "$retry_target"
    if [[ "$variant" == invalid ]]; then printf 'gc1:invalid\n' > "$stage/previous-key";
    else printf 'gc1:%0128d\n' 1 > "$stage/previous-key"; fi
    cp "$stage/previous-key" "$retry_target/.config/dotfiles/git-crypt.key"
    run_restore "$retry_target" > "$stage/$variant-copy.log" 2>&1
    cmp -s "$retry_target/.config/dotfiles/git-crypt.key" "$stage/key"
    cmp -s "$retry_target/.config/git/config.secret" "$stage/plain-config"
    backups=("$retry_target/.local/state/dotfiles"/key-input-backup.*)
    [[ ${#backups[@]} == 1 ]]
    cmp -s "${backups[0]}" "$stage/previous-key"
done
echo 'PASS: a retry accepts the newly supplied key and backs up invalid or different key copies left by incomplete initialization.'
cp "$fresh_target/.config/dotfiles/git-crypt.key" "$stage/active-key-before"
for variant in invalid different; do
    if [[ "$variant" == invalid ]]; then printf 'gc1:invalid\n' > "$stage/supplied-key";
    else printf 'gc1:%0128d\n' 1 > "$stage/supplied-key"; fi
    result=0
    run_restore "$fresh_target" "$stage/supplied-key" > "$stage/$variant-input.log" 2>&1 || result=$?
    [[ "$result" != 0 ]]
    cmp -s "$fresh_target/.config/dotfiles/git-crypt.key" "$stage/active-key-before"
done
grep -Fq 'The supplied key is invalid.' "$stage/invalid-input.log"
if grep -Fq 'differs from the active' "$stage/invalid-input.log"; then echo 'Malformed input was reported as a key mismatch.' >&2; exit 1; fi
grep -Fq 'differs from the active repository key' "$stage/different-input.log"
echo 'PASS: malformed input and actual active-key conflicts are distinguished, and a working key is preserved.'

wrong_target="$stage/wrong key target"
make_locked_target "$wrong_target"
printf 'gc1:%0128d\n' 1 > "$stage/wrong-key"
result=0
run_restore "$wrong_target" "$stage/wrong-key" > "$stage/wrong-key.log" 2>&1 || result=$?
[[ "$result" != 0 && ! -f "$wrong_target/.dotfiles.git/git-crypt/keys/default" ]]
grep -Fq 'The supplied key cannot decrypt this repository.' "$stage/wrong-key.log"
run_restore "$wrong_target" > "$stage/wrong-key-retry.log" 2>&1
cmp -s "$wrong_target/.config/git/config.secret" "$stage/plain-config"
echo 'PASS: a well-formed wrong key is rejected before activation; retrying with the correct key replaces its leftover input copy and succeeds.'

failed_target="$stage/failed target"
make_locked_target "$failed_target"
cp "$failed_target/.config/git/config.secret" "$stage/cipher-config"
result=0
DOTFILES_TEST_FAIL_BREW=1 run_restore "$failed_target" > "$stage/failure.log" 2>&1 || result=$?
[[ "$result" == 39 ]]
cmp -s "$failed_target/.config/git/config.secret" "$stage/cipher-config"
[[ ! -e "$failed_target/.local/state/dotfiles/git-config.pending" ]]
mkdir -p "$failed_target/.local/state/dotfiles"
mv "$failed_target/.config/git/config.secret" "$failed_target/.local/state/dotfiles/git-config.pending"
run_restore "$failed_target" > "$stage/recovery.log" 2>&1
cmp -s "$failed_target/.config/git/config.secret" "$stage/plain-config"
[[ ! -e "$failed_target/.local/state/dotfiles/git-config.pending" ]]
echo 'PASS: failed prerequisite installation restores ciphertext; an interrupted suspension is recovered on retry.'
