#!/bin/bash
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077
[[ $# == 2 ]] || { echo 'Usage: ci-bootstrap.sh FIXTURE KEY_FILE' >&2; exit 2; }
# This test intentionally installs into the disposable runner's real home and
# installs the full machine Brewfile. Refuse to run on a developer's computer.
[[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_OS:-} == macOS && -n ${RUNNER_TEMP:-} ]] || {
    echo 'This full installation test requires a disposable GitHub-hosted macOS runner.' >&2; exit 2;
}
[[ ! -e "$HOME/.dotfiles.git" ]] || { echo 'Refusing to reuse an existing home repository.' >&2; exit 1; }
seed=$1 identity=$2
export GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
# shellcheck source=../bootstrap.sh
source "$seed/.config/dotfiles/bootstrap.sh"
exec 3</dev/null
trap cleanup_key EXIT
git() {
    if [[ ${1:-} == clone ]]; then
        # Keep the production origin fixed; only the clone transport points at
        # the same code encrypted with this run's disposable key.
        [[ $# == 5 && $2 == --bare && $3 == -- && $4 == "$DOTFILES_REPOSITORY_URL" ]] || return 99
        command git clone --bare -- "$seed/.dotfiles.git" "$5"
        command git --git-dir="$5" config --local remote.origin.url "$DOTFILES_REPOSITORY_URL"
    elif [[ ${2:-} == fetch ]]; then
        echo 'Unexpected fetch during disposable bootstrap.' >&2; return 99
    else
        command git "$@"
    fi
}
echo 'Starting headless macmini-m4 bootstrap with real package installation.'
restore_dotfiles "$identity" macmini-m4 "$HOME" --skip-defaults --keep-shell
[[ $(cat "$HOME/.config/dotfiles/machine") == macmini-m4 ]]
cmp -s "$identity" "$HOME/.config/dotfiles/git-crypt.key"
cmp -s "$seed/.config/git/config.secret" "$HOME/.config/git/config.secret"
[[ -s "$HOME/.local/share/tmux/oh-my-tmux/.tmux.conf" ]]
/bin/bash "$HOME/.config/dotfiles/dotfile.sh" verify
# shellcheck disable=SC2016 # The child fish process expands its own fixture variable.
fish -c 'test "$DOTFILES_CI_FIXTURE" = 1; and type -q dotfile; and command node --version; and command starship --version; and command zoxide --version; and command nvim --version'
node_prefix=$(brew --prefix node@24)
export PATH="$node_prefix/bin:$PATH"
"$node_prefix/bin/npm" list --global --depth=0 @loongphy/codex-auth corepack

printf '\n# CI local edit preserved across setup retries.\n' >> "$HOME/.config/fish/conf.d/env.secret.fish"
cp "$HOME/.config/fish/conf.d/env.secret.fish" "$RUNNER_TEMP/dotfiles-expected-env.fish"
stat -f '%i:%m:%z' "$HOME/.config/dotfiles/machine" > "$RUNNER_TEMP/dotfiles-machine-before"
stat -f '%i:%m:%z' "$HOME/.local/share/tmux/oh-my-tmux/.tmux.conf" > "$RUNNER_TEMP/dotfiles-tmux-before"
echo 'Repeating bootstrap and full package installation without a terminal.'
restore_dotfiles "$identity" macmini-m4 "$HOME" --skip-defaults --keep-shell
cmp -s "$identity" "$HOME/.config/dotfiles/git-crypt.key"
cmp -s "$HOME/.config/fish/conf.d/env.secret.fish" "$RUNNER_TEMP/dotfiles-expected-env.fish"
stat -f '%i:%m:%z' "$HOME/.config/dotfiles/machine" > "$RUNNER_TEMP/dotfiles-machine-after"
stat -f '%i:%m:%z' "$HOME/.local/share/tmux/oh-my-tmux/.tmux.conf" > "$RUNNER_TEMP/dotfiles-tmux-after"
cmp -s "$RUNNER_TEMP/dotfiles-machine-before" "$RUNNER_TEMP/dotfiles-machine-after"
cmp -s "$RUNNER_TEMP/dotfiles-tmux-before" "$RUNNER_TEMP/dotfiles-tmux-after"
cmp -s "$seed/.config/brew/Brewfile.macmini-m4" "$HOME/.config/brew/Brewfile.macmini-m4"
[[ $(stat -f '%Lp' "$HOME/.config/dotfiles/git-crypt.key") == 600 ]]
/bin/bash "$HOME/.config/dotfiles/dotfile.sh" verify
echo 'PASS: headless macmini-m4 bootstrap, real Brewfile/npm installation, fish startup, decryption and idempotent retry.'
