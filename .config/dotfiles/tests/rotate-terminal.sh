#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# shellcheck disable=SC2031 # Fixture setup deliberately runs in an isolated subshell.
set -euo pipefail
umask 077
[[ -t 0 ]] || { echo 'Run this interactive rotation check in a terminal.' >&2; exit 2; }
metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-rotation-ui.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT
test_root=$(cd "$test_root" && pwd -P)
fixture="$test_root/work"
mkdir -p "$fixture/.config/dotfiles" "$fixture/.config/fish/conf.d" "$test_root/bin"
cp "$metadata"/*.sh "$fixture/.config/dotfiles/"
cp -R "$metadata/install" "$metadata/hooks" "$fixture/.config/dotfiles/"
cp "$metadata/../../.gitattributes" "$metadata/../../.gitignore" "$fixture/"
printf '.config/fish/conf.d/env.secret.fish\n' > "$fixture/.config/dotfiles/private-files"
printf 'set -gx ROTATION_FIXTURE dummy\n' > "$fixture/.config/fish/conf.d/env.secret.fish"
printf 'public fixture\n' > "$fixture/README.md"
export GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
git init --bare -q --initial-branch=main "$fixture/.dotfiles.git"
g() { command git --git-dir="$fixture/.dotfiles.git" --work-tree="$fixture" -C "$fixture" "$@"; }
g crypt init > "$test_root/init.log" 2>&1
fixture_key="$fixture/.config/dotfiles/git-crypt.key"
bash "$metadata/key-file.sh" normalize "$fixture/.dotfiles.git/git-crypt/keys/default" --output "$fixture_key"
cp "$fixture_key" "$test_root/old.key"
(
    # shellcheck source=../setup.sh
    source "$fixture/.config/dotfiles/setup.sh"
    setup_dotfiles "$fixture" macbook-m4 --configure-only
)
g add -- README.md .gitignore .gitattributes .config/dotfiles .config/fish
cat > "$test_root/bin/pbcopy" <<'CLIPBOARD'
#!/bin/bash
touch "$DOTFILES_TEST_CLIPBOARD_CALLED"
echo 'Unexpected clipboard access during key rotation.' >&2
exit 1
CLIPBOARD
chmod 700 "$test_root/bin/pbcopy"
export PATH="$test_root/bin:$PATH" DOTFILES_TEST_CLIPBOARD_CALLED="$test_root/clipboard-called"
echo 'Disposable repository only. Type yes once to start; the command will finish without further input. Your real key and clipboard will not change.'
(cd "$fixture" && /bin/bash .config/dotfiles/dotfile.sh key rotate)
if cmp -s "$fixture_key" "$test_root/old.key"; then echo 'The fixture key did not rotate.' >&2; exit 1; fi
backup_keys=("$fixture/.local/state/dotfiles"/key-rotation.*/backup/new.key)
[[ ${#backup_keys[@]} == 1 && -f "${backup_keys[0]}" ]]
cmp -s "$fixture_key" "${backup_keys[0]}"
[[ ! -e "$DOTFILES_TEST_CLIPBOARD_CALLED" ]]
g cat-file blob :.config/fish/conf.d/env.secret.fish | g crypt smudge | cmp -s - "$fixture/.config/fish/conf.d/env.secret.fish"
if g rev-parse --verify HEAD >/dev/null 2>&1; then echo 'Unexpected commit.' >&2; exit 1; fi
[[ -z $(g remote) && ! -d "$fixture/.local/state/dotfiles/key-rotation.pending" ]]
echo 'PASS: public dotfile key rotate completes in a real terminal with a key file, no commit/push, no real key changes, and no clipboard access.'
