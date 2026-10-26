#!/usr/bin/env bash
# Native startup test: scripts/flags that print config do not parse custom YAML.
set -euo pipefail
umask 077
metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
[[ -t 0 ]] || { echo 'Run this interactive UI check in a terminal.' >&2; exit 2; }
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-ui-test.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT
test_root=$(cd "$test_root" && pwd -P)
export GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE NO_COLOR
export DOTFILES_TEST_LAZYGIT_BIN
DOTFILES_TEST_LAZYGIT_BIN=$(command -v lazygit)
mkdir -p "$test_root/bin"
cat > "$test_root/bin/lazygit" <<'WRAPPER'
#!/bin/bash
exec "$DOTFILES_TEST_LAZYGIT_BIN" --use-config-dir="$DOTFILES_TEST_LAZYGIT_DIR" "$@"
WRAPPER
chmod 700 "$test_root/bin/lazygit"
export PATH="$test_root/bin:$PATH"

run_ui() {
    local kind=$1 fixture result=0 ui_log
    fixture="$test_root/$kind"
    mkdir -p "$fixture/.config/dotfiles" "$fixture/.config/fish/conf.d" "$fixture/app-config"
    cp "$metadata/dotfile.sh" "$metadata/lazygit.yml" "$fixture/.config/dotfiles/"
    printf 'disableStartupPopups: true\n' > "$fixture/app-config/config.yml"
    if [[ "$kind" == invalid ]]; then
        sed 's/^      pager:/        pager:/' "$metadata/lazygit.yml" > "$fixture/.config/dotfiles/lazygit.yml"
    fi
    git init --bare -q --initial-branch=main "$fixture/.dotfiles.git"
    g() { git --git-dir="$fixture/.dotfiles.git" --work-tree="$fixture" -C "$fixture" "$@"; }
    g config user.name 'UI Test'
    g config user.email test@example.invalid
    g config status.showUntrackedFiles no
    printf 'public fixture\n' > "$fixture/README.md"
    g add -- README.md
    if [[ "$kind" == invalid ]]; then g commit -qm 'disposable UI fixture'; fi
    g crypt init > "$fixture/init.log" 2>&1
    printf '.config/fish/conf.d/env.secret.fish filter=git-crypt diff=git-crypt -text\n' > "$fixture/.gitattributes"
    printf 'set -gx TEST_FIXTURE dummy_value\n' > "$fixture/.config/fish/conf.d/env.secret.fish"
    g add -- .gitattributes .config/fish/conf.d/env.secret.fish
    export DOTFILES_TEST_LAZYGIT_DIR="$fixture/app-config"
    ui_log="$fixture/terminal.log"
    if [[ "$kind" == valid ]]; then
        echo 'In the test UI, press E to verify ciphertext, Enter to close the popup, then q to quit.'
    fi
    TERM=xterm-256color script -q -e "$ui_log" /bin/bash "$fixture/.config/dotfiles/dotfile.sh" lazygit || result=$?
    if [[ "$kind" == valid ]]; then
        [[ "$result" == 0 ]] || { echo 'Native UI returned an error.' >&2; return 1; }
        grep -Fq 'ENCRYPTED' "$ui_log"
        grep -Fq 'PASS:' "$ui_log"
    else
        [[ "$result" != 0 ]] || { echo 'Malformed YAML was accepted.' >&2; return 1; }
        grep -Fq 'failed to parse YAML' "$ui_log"
    fi
}

run_ui invalid
echo 'PASS: native lazygit rejects the previous pager indentation error.'
run_ui valid
echo 'PASS: native lazygit opens an unborn branch, its staged diff and E verification popup.'
