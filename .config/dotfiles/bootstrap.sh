#!/usr/bin/env bash
set +x
set -euo pipefail
umask 077
export GIT_CONFIG_GLOBAL=/dev/null

readonly DOTFILES_REPOSITORY_URL="https://github.com/tokisakiyuu/dotfiles.git"
bootstrap_key_directory=""
bootstrap_install_temp=""

cleanup_key() {
    unset bootstrap_key_input
    if [[ -n "$bootstrap_install_temp" ]]; then rm -rf -- "$bootstrap_install_temp"; fi
    if [[ -n "$bootstrap_key_directory" ]]; then rm -rf -- "$bootstrap_key_directory"; fi
}

ask() {
    printf '%s' "$1" >&3
    IFS= read -r bootstrap_answer <&3
}

ask_yes() {
    while true; do
        ask "$1 [Y/n] "
        case "$bootstrap_answer" in
            ''|y|Y|yes|YES) return 0 ;;
            n|N|no|NO) return 1 ;;
            *) printf 'Please enter y or n.\n' >&3 ;;
        esac
    done
}

read_key() {
    printf 'git-crypt gc1 text key or key-file path: ' >&3
    IFS= read -r -s bootstrap_key_input <&3
    printf '\n' >&3
    if [[ -z "$bootstrap_key_input" ]]; then
        unset bootstrap_key_input
        echo 'The key is empty.' >&2
        return 1
    fi
    case "$bootstrap_key_input" in \~/*) bootstrap_key_input="${HOME}/${bootstrap_key_input:2}" ;; esac
    if [[ -s "$bootstrap_key_input" ]]; then
        identity_source="$bootstrap_key_input"
    else
        bootstrap_key_directory=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-key.XXXXXX")
        identity_source="${bootstrap_key_directory}/key"
        printf '%s\n' "$bootstrap_key_input" > "$identity_source"
        [[ -s "$identity_source" ]] || { echo 'The key is empty.' >&2; return 1; }
        chmod 600 "$identity_source"
    fi
    unset bootstrap_key_input
}

restore_dotfiles() {
    local repo_url="$DOTFILES_REPOSITORY_URL" identity_source=$1 machine=$2 destination=$3
    local repo="${destination}/.dotfiles.git"
    local metadata="${destination}/.config/dotfiles"
    local identity="${metadata}/git-crypt.key"
    local reused=0 git_config_header=''
    shift 3
    [[ -f "$identity_source" ]] || { echo "Key file not found: $identity_source" >&2; return 1; }
    [[ "$machine" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo 'Invalid machine name.' >&2; return 2; }
    if [[ "$identity_source" != /* ]]; then identity_source="${PWD}/${identity_source}"; fi
    mkdir -p "$destination"

    if [[ -e "$repo" ]]; then
        reused=1
        [[ $(git --git-dir="$repo" rev-parse --is-bare-repository) == true ]] || {
            echo "Not a bare repository: $repo" >&2; return 1;
        }
        [[ $(git --git-dir="$repo" config --local --get remote.origin.url) == "$repo_url" ]] || {
            echo 'Existing dotfiles repository has a different origin; leaving it untouched.' >&2; return 1;
        }
    else
        git clone --bare -- "$repo_url" "$repo"
    fi
    git --git-dir="$repo" cat-file -e HEAD:.config/dotfiles/setup.sh || {
        echo 'The remote has no bare-dotfiles setup script. Publish the new layout first.' >&2; return 1;
    }
    if git --git-dir="$repo" cat-file -e HEAD:.config/dotfiles/git-crypt.key 2>/dev/null; then
        echo 'The remote contains an unlock key; refusing to use it.' >&2; return 1
    fi

    # Let Git refuse collisions; never force a checkout over an existing home.
    git --git-dir="$repo" --work-tree="$destination" -C "$destination" checkout
    if [[ -f "$destination/.config/git/config.secret" ]]; then
        git_config_header=$(dd if="$destination/.config/git/config.secret" bs=1 count=10 2>/dev/null | od -An -tx1 | tr -d ' \r\n')
    fi
    if ((reused)) && { [[ ! -f "$repo/git-crypt/keys/default" ]] || [[ "$git_config_header" == 00474954435259505400 ]] || [[ -f "$destination/.local/state/dotfiles/git-config.pending" ]]; }; then
        echo 'Resuming incomplete setup; checking for updated bootstrap files.'
        git --git-dir="$repo" fetch --no-tags origin '+refs/heads/main:refs/remotes/origin/main'
        git --git-dir="$repo" --work-tree="$destination" -C "$destination" merge --ff-only refs/remotes/origin/main
    fi
    [[ ! -L "$identity" ]] || { echo 'Refusing to replace a symlink at the key path.' >&2; return 1; }
    local key_tool="${metadata}/key-file.sh" active_key="$repo/git-crypt/keys/default" key_backup
    bash "$key_tool" status "$identity_source" >/dev/null || {
        echo 'The supplied key is invalid. Enter the complete gc1 text key or a readable key-file path; existing files were preserved.' >&2
        return 1
    }
    if [[ -f "$active_key" ]]; then
        bash "$key_tool" status "$active_key" >/dev/null || { echo 'The active repository key is invalid; existing files were preserved.' >&2; return 1; }
        bash "$key_tool" matches "$identity_source" "$active_key" || {
            echo 'The supplied key differs from the active repository key; existing files were preserved.' >&2; return 1;
        }
    fi
    bootstrap_install_temp=$(mktemp -d "${metadata}/.git-crypt.key.XXXXXX")
    bash "$key_tool" normalize "$identity_source" --output "${bootstrap_install_temp}/key"
    if ! cmp -s "${bootstrap_install_temp}/key" "$identity"; then
        if [[ -e "$identity" ]]; then
            [[ -f "$identity" ]] || { echo 'The local key path is not a regular file.' >&2; return 1; }
            mkdir -p "$destination/.local/state/dotfiles"
            key_backup=$(mktemp "$destination/.local/state/dotfiles/key-input-backup.XXXXXX")
            cp "$identity" "$key_backup"
            chmod 600 "$key_backup"
            printf 'Previous local key copy preserved at: %s\n' "$key_backup"
        fi
        mv -f "${bootstrap_install_temp}/key" "$identity"
    fi
    rm -rf -- "$bootstrap_install_temp"
    bootstrap_install_temp=''
    chmod 600 "$identity"
    # Reconnect child installers/editors to the terminal when invoked via curl | bash.
    bash "${metadata}/setup.sh" "$machine" "$@" <&3
}

main() {
    case "${1:-}" in
        -h|--help)
            echo 'Usage: bash bootstrap.sh'
            echo "Repository (fixed): $DOTFILES_REPOSITORY_URL"
            echo 'Interactive setup; machine defaults to macOS LocalHostName; key input is hidden.'
            return 0
            ;;
    esac
    [[ $# -eq 0 ]] || { echo 'This script takes no arguments; the repository is fixed.' >&2; return 2; }
    [[ $(uname -s) == Darwin ]] || { echo 'This repository supports macOS only.' >&2; return 1; }
    if ! xcode-select -p >/dev/null 2>&1; then
        xcode-select --install
        echo 'Finish installing Command Line Tools, then rerun this command.' >&2
        return 1
    fi
    exec 3<>/dev/tty || { echo 'Run this script from an interactive terminal.' >&2; return 1; }
    trap cleanup_key EXIT
    local machine identity_source
    machine=$(/usr/sbin/scutil --get LocalHostName)
    ask "Machine name [${machine}]: "
    machine="${bootstrap_answer:-$machine}"
    [[ "$machine" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo 'Invalid machine name.' >&2; return 2; }
    read_key
    set --
    if ! ask_yes 'Install software from the machine Brewfile?'; then set -- "$@" --skip-packages; fi
    if ! ask_yes 'Apply macOS preferences?'; then set -- "$@" --skip-defaults; fi
    if ! ask_yes 'Set fish as the default login shell?'; then set -- "$@" --keep-shell; fi
    restore_dotfiles "$identity_source" "$machine" "$HOME" "$@"
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then main "$@"; fi
