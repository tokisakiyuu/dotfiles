#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
set +x
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077
checkout_metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
checkout_root=$(cd "$checkout_metadata/../.." && pwd -P)
# shellcheck source=install/lib.sh
source "$checkout_metadata/install/lib.sh"

checkout_source_git() { git --git-dir="$checkout_root/.dotfiles.git" --work-tree="$checkout_root" -C "$checkout_root" "$@"; }
checkout_temporary_git() { git --git-dir="$checkout_workspace/.dotfiles.git" --work-tree="$checkout_workspace" -C "$checkout_workspace" "$@"; }

checkout_main() (
    [[ $# == 0 ]] || { echo 'Usage: dotfile checkout' >&2; return 2; }
    local checkout_workspace='' origin push_url setting value object reference
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
    if ! origin=$(checkout_source_git config --local --get remote.origin.url) || [[ -z "$origin" ]]; then
        echo 'Configure origin before creating a checkout that can push.' >&2; return 1;
    fi
    checkout_source_git symbolic-ref --quiet HEAD >/dev/null || { echo 'Check out a branch before creating a full checkout.' >&2; return 1; }
    checkout_source_git rev-parse --verify HEAD >/dev/null || { echo 'Commit the initial repository before creating a full checkout.' >&2; return 1; }
    checkout_workspace=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-checkout.XXXXXX")
    checkout_workspace=$(cd "$checkout_workspace" && pwd -P)
    trap 'rm -rf -- "$checkout_workspace"' EXIT
    {
        # Independent objects, index and configuration keep normal Git commands
        # in this checkout separate from the sparse HOME repository.
        command git clone --bare --no-hardlinks -- "$checkout_root/.dotfiles.git" "$checkout_workspace/.dotfiles.git"
        checkout_temporary_git config --local core.bare false
        checkout_temporary_git config --local core.worktree "$checkout_workspace"
        checkout_temporary_git config --local dotfiles.fullWorktree true
        checkout_temporary_git config --local dotfiles.checkoutSource "$checkout_root/.dotfiles.git"
        printf 'gitdir: .dotfiles.git\n' > "$checkout_workspace/.git"
        checkout_temporary_git config --local remote.origin.url "$origin"
        if push_url=$(checkout_source_git config --local --get remote.origin.pushurl); then
            checkout_temporary_git config --local remote.origin.pushurl "$push_url"
        fi
        checkout_source_git for-each-ref --format='%(objectname) %(refname)' refs/remotes/origin/ > "$checkout_workspace/.dotfiles.git/dotfiles-remote-refs"
        while read -r object reference; do
            checkout_temporary_git update-ref "$reference" "$object"
        done < "$checkout_workspace/.dotfiles.git/dotfiles-remote-refs"
        rm -f -- "$checkout_workspace/.dotfiles.git/dotfiles-remote-refs"
        for setting in user.name user.email; do
            if value=$(checkout_source_git config --get "$setting"); then checkout_temporary_git config --local "$setting" "$value"; fi
        done
        checkout_temporary_git checkout
        /bin/bash "$checkout_metadata/key-file.sh" normalize "$checkout_metadata/git-crypt.key" \
            --output "$checkout_workspace/.config/dotfiles/git-crypt.key"
        /bin/bash "$checkout_metadata/key-file.sh" unlock "$checkout_workspace/.config/dotfiles/git-crypt.key" --destination "$checkout_workspace"
        configure_dotfiles_repository "$checkout_workspace"
        checkout_temporary_git config --local status.showUntrackedFiles normal
        GIT_DIR="$checkout_workspace/.dotfiles.git" GIT_WORK_TREE="$checkout_workspace" \
            /bin/bash "$checkout_workspace/.config/dotfiles/check-encryption.sh" --index --quiet
    } >&2
    trap - EXIT
    printf '%s\n' "$checkout_workspace"
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    case "${1:-}" in -h|--help) echo 'Usage: dotfile checkout'; exit 0 ;; esac
    checkout_main "$@"
fi
