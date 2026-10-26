#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077
# The included private Git config is ciphertext until the repository is unlocked.
export GIT_CONFIG_GLOBAL=/dev/null


setup_dotfiles() {
    local -x HOMEBREW_NO_ASK=1
    [[ $(uname -s) == Darwin ]] || { echo 'This repository supports macOS only.' >&2; exit 1; }
    local destination=$1
    shift
    root="${destination}/.config/dotfiles"
    # shellcheck source=install/lib.sh
    source "${root}/install/lib.sh"
    cd "$destination"
    machine=""
    configure_only=0
    install_packages=1
    apply_defaults=1
    change_shell=1
    for argument in "$@"; do
        case "$argument" in
            -h|--help)
                echo 'Usage: setup.sh [MACHINE] [--configure-only] [--skip-packages] [--skip-defaults] [--keep-shell]'
                exit 0 ;;
            --configure-only) configure_only=1 ;;
            --skip-packages) install_packages=0 ;;
            --skip-defaults) apply_defaults=0 ;;
            --keep-shell) change_shell=0 ;;
            -*) echo "Unknown option: $argument" >&2; exit 2 ;;
            *) [[ -z "$machine" ]] || { echo 'Only one machine name is allowed.' >&2; exit 2; }; machine="$argument" ;;
        esac
    done
    if [[ -z "$machine" && -r "${root}/machine" ]]; then machine=$(cat "${root}/machine"); fi
    if [[ -z "$machine" ]]; then machine=$(/usr/sbin/scutil --get LocalHostName); fi
    [[ "$machine" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
        echo 'Usage: bash ~/.config/dotfiles/setup.sh [MACHINE] [--configure-only]' >&2
        exit 2
    }
    [[ -d "${destination}/.dotfiles.git" ]] || { echo 'Clone the bare repository first; see README.md.' >&2; exit 1; }
    write_machine "$machine" "${root}/machine"
    git_dotfiles() { git --git-dir="${destination}/.dotfiles.git" --work-tree="$destination" "$@"; }
    git_dotfiles config --local status.showUntrackedFiles no
    git_dotfiles config --local core.hooksPath "${root}/hooks"
    git_dotfiles config --local core.logAllRefUpdates true
    git_dotfiles config --local commit.template "${destination}/.config/git/commit_template"
    git_dotfiles config --local push.autoSetupRemote true
    configure_crypt_diff
    if git_dotfiles config --local --get remote.origin.url >/dev/null; then
        # Bare clones do not create remote-tracking refs or branch upstreams.
        git_dotfiles config --local remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
        local current_branch
        current_branch=$(git_dotfiles symbolic-ref --quiet --short HEAD || true)
        if [[ -n "$current_branch" ]]; then
            git_dotfiles config --local "branch.${current_branch}.remote" origin
            git_dotfiles config --local "branch.${current_branch}.merge" "refs/heads/${current_branch}"
        fi
    fi
    chmod +x "${root}/hooks/pre-commit" "${root}/hooks/pre-push"
    if ((configure_only)); then exit 0; fi

    identity="${root}/git-crypt.key"
    if [[ ! -r "$identity" ]]; then
        echo "Restore the git-crypt key to ${identity} and rerun setup." >&2
        exit 1
    fi
    chmod 600 "$identity"
    prepare_git_crypt "$destination" "$identity"
    if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv bash)"; else eval "$(/usr/local/bin/brew shellenv bash)"; fi
    if ((change_shell)); then
        echo 'Installing fish and the tools required by its shared configuration.'
        brew install fish starship zoxide neovim
    fi
    if ((install_packages)); then
        snapshot="${destination}/.config/brew/Brewfile.${machine}"
        if [[ ! -f "$snapshot" ]]; then
            shopt -s nullglob
            templates=("${destination}"/.config/brew/Brewfile.*)
            shopt -u nullglob
            [[ ${#templates[@]} -gt 0 && -t 0 ]] || {
                echo "Create ${snapshot}, then rerun setup from a terminal." >&2; exit 1;
            }
            template="${templates[0]}"
            if [[ ${#templates[@]} -gt 1 ]]; then
                echo "Select a package-list template for ${machine}:"
                template=''
                select template in "${templates[@]}"; do [[ -n "$template" ]] && break; done
                [[ -n "$template" ]] || exit 1
            fi
            echo "No list for ${machine}. Review the copy of ${template} in vi before installation."
            draft=$(mktemp "${destination}/.config/brew/.Brewfile.${machine}.XXXXXX")
            cp "$template" "$draft"
            if ! /usr/bin/vi "$draft"; then rm -f "$draft"; exit 1; fi
            mv "$draft" "$snapshot"
            git_dotfiles add --intent-to-add -- "$snapshot"
        fi
        install_brewfile "$snapshot"
    fi

    tmux_dir="${destination}/.local/share/tmux/oh-my-tmux"
    install_tmux_config "$tmux_dir"
    if ((apply_defaults)); then bash "${root}/install/defaults.sh"; fi

    if ((change_shell)); then
        fish_bin=$(command -v fish)
        if ! grep -Fxq "$fish_bin" /etc/shells; then printf '%s\n' "$fish_bin" | sudo tee -a /etc/shells >/dev/null; fi
        if [[ $(dscl . -read "/Users/$(id -un)" UserShell | awk '{print $2}') != "$fish_bin" ]]; then chsh -s "$fish_bin"; fi
    fi
    GIT_DIR="${destination}/.dotfiles.git" GIT_WORK_TREE="$destination" bash "${root}/check-encryption.sh" --index
    printf 'Setup complete for %s.\n' "$machine"
    if ((change_shell)); then echo 'Open a new fish shell.'; fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "${1:-}" != --internal-locked ]]; then
        case "${1:-}" in -h|--help) setup_dotfiles "$HOME" "$@"; exit ;; esac
        mkdir -p "${HOME}/.local/state/dotfiles"
        exec /usr/bin/lockf -k -t 0 "${HOME}/.local/state/dotfiles/setup.lock" \
            /bin/bash "$0" --internal-locked "$@"
    fi
    shift
    setup_dotfiles "$HOME" "$@"
fi
