#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
set +x
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077
shell_metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
shell_root=$(cd "$shell_metadata/../.." && pwd -P)
shell_repository="$shell_root/.dotfiles.git"
shell_pending="$shell_root/.local/state/dotfiles/shell.pending"
shell_workspace=''
# shellcheck source=install/worktree.sh
source "$shell_metadata/install/worktree.sh"

shell_source_git() { command git --git-dir="$shell_repository" --work-tree="$shell_root" -C "$shell_root" "$@"; }
shell_temporary_git() { command git --git-dir="$shell_workspace/.dotfiles.git" --work-tree="$shell_workspace" -C "$shell_workspace" "$@"; }
shell_error() { printf 'dotfile: %s\n' "$*" >&2; return 1; }

shell_open() {
    [[ -t 0 && -t 1 ]] || { shell_error 'Run dotfile shell from an interactive terminal.'; return 1; }
    command fish --interactive
}

shell_prepare() {
    local branch origin setting value object reference
    branch=$(shell_source_git symbolic-ref --quiet HEAD) || { shell_error 'Check out a branch before opening a temporary shell.'; return 1; }
    shell_source_git rev-parse --verify HEAD >/dev/null || { shell_error 'Commit the initial repository before opening a temporary shell.'; return 1; }
    mkdir "$shell_pending"
    printf '%s\n' "$branch" > "$shell_pending/branch"
    shell_source_git rev-parse HEAD > "$shell_pending/base"
    shell_workspace=$(mktemp -d "$shell_pending/dotfiles-shell.XXXXXX")
    shell_workspace=$(cd "$shell_workspace" && pwd -P)
    printf '%s\n' "$shell_workspace" > "$shell_pending/workspace"
    # Independent objects and index prevent commands in the shell from changing
    # the HOME repository until the clean, fast-forward import on exit.
    command git clone --bare --no-hardlinks -- "$shell_repository" "$shell_workspace/.dotfiles.git"
    shell_temporary_git for-each-ref --format='%(objectname) %(refname)' refs/heads/ > "$shell_pending/initial-heads"
    shell_temporary_git config --local core.bare false
    shell_temporary_git config --local core.worktree "$shell_workspace"
    shell_temporary_git config --local dotfiles.fullWorktree true
    shell_temporary_git config --local dotfiles.sessionSource "$shell_repository"
    printf 'gitdir: .dotfiles.git\n' > "$shell_workspace/.git"
    if origin=$(shell_source_git config --local --get remote.origin.url); then
        shell_temporary_git config --local remote.origin.url "$origin"
        shell_source_git for-each-ref --format='%(objectname) %(refname)' refs/remotes/origin/ > "$shell_pending/remote-refs"
        while read -r object reference; do
            shell_temporary_git update-ref "$reference" "$object"
        done < "$shell_pending/remote-refs"
    else
        # A session must never push directly into the live HOME bare repository.
        shell_temporary_git remote remove origin
    fi
    for setting in user.name user.email; do
        if value=$(shell_source_git config --get "$setting"); then shell_temporary_git config --local "$setting" "$value"; fi
    done
    shell_temporary_git checkout
    /bin/bash "$shell_metadata/key-file.sh" normalize "$shell_metadata/git-crypt.key" \
        --output "$shell_workspace/.config/dotfiles/git-crypt.key"
    /bin/bash "$shell_metadata/key-file.sh" unlock "$shell_metadata/git-crypt.key" --destination "$shell_workspace"
    (
        # shellcheck source=setup.sh
        source "$shell_metadata/setup.sh"
        setup_dotfiles "$shell_workspace" "$(cat "$shell_metadata/machine")" --configure-only
    )
    printf 'ready\n' > "$shell_pending/phase"
}

shell_import() {
    local base tip branch reference object
    branch=$(cat "$shell_pending/branch")
    base=$(cat "$shell_pending/base")
    [[ $(shell_source_git symbolic-ref --quiet HEAD) == "$branch" ]] || { shell_error 'The HOME branch changed; the temporary workspace was retained.'; return 1; }
    [[ $(shell_temporary_git symbolic-ref --quiet HEAD) == "$branch" ]] || {
        shell_error 'Return to the original branch before exiting. Workspace retained.'; return 1;
    }
    if shell_temporary_git rev-parse --verify --quiet refs/stash >/dev/null; then
        shell_error 'Stashes remain. Apply or drop them before exiting; workspace retained.'; return 1
    fi
    /bin/bash "$shell_metadata/key-file.sh" matches "$shell_metadata/git-crypt.key" \
        "$shell_workspace/.dotfiles.git/git-crypt/keys/default" || return 1
    tip=$(shell_temporary_git rev-parse HEAD)
    shell_temporary_git for-each-ref --format='%(objectname) %(refname)' refs/heads/ > "$shell_pending/current-heads" || return 1
    while read -r object reference; do
        if grep -Fxq "$object $reference" "$shell_pending/initial-heads"; then continue; fi
        shell_temporary_git merge-base --is-ancestor "$object" "$tip" || {
            shell_error 'An additional branch contains unmerged commits. Workspace retained.'; return 1;
        }
    done < "$shell_pending/current-heads"
    reference="refs/dotfiles/shell/$(basename "$shell_workspace")"
    shell_temporary_git merge-base --is-ancestor "$base" "$tip" || { shell_error 'The session rewrote its base history; the workspace was retained.'; return 1; }
    GIT_DIR="$shell_workspace/.dotfiles.git" GIT_WORK_TREE="$shell_workspace" \
        /bin/bash "$shell_metadata/check-encryption.sh" --index --quiet || return 1
    [[ -z $(shell_temporary_git status --porcelain --untracked-files=all) ]] || {
        shell_error 'Uncommitted files remain. Workspace retained; run dotfile shell to resume.'; return 1;
    }
    # HOME's broad ignore rules also hide newly created project files. Check
    # these too, allowing only the session's own generated local metadata.
    [[ -z $(shell_temporary_git ls-files --others \
        --exclude=.git --exclude=.dotfiles.git/ \
        --exclude=.config/dotfiles/git-crypt.key --exclude=.config/dotfiles/machine) ]] || {
        shell_error 'Untracked files remain, including ignored paths. Workspace retained; run dotfile shell to resume.'; return 1;
    }
    if [[ "$tip" != "$base" ]]; then
        # Scan every incoming commit, even when native git bypassed the hooks.
        printf 'HEAD %s refs/heads/session %040d\n' "$tip" 0 |
            GIT_DIR="$shell_workspace/.dotfiles.git" GIT_WORK_TREE="$shell_workspace" \
            /bin/bash "$shell_metadata/check-encryption.sh" --push >/dev/null || return 1
        shell_source_git fetch --no-tags --no-write-fetch-head "$shell_workspace/.dotfiles.git" "+HEAD:$reference" || return 1
        shell_source_git merge --ff-only --no-edit "$reference" || {
            shell_error 'Could not fast-forward HOME. Workspace retained; resolve local changes, then run dotfile shell again.'; return 1;
        }
        dotfiles_reapply_worktree "$shell_repository" "$shell_root" || return 1
    fi
    shell_source_git update-ref -d "$reference" || return 1
}

shell_main() {
    local result=0 backup
    [[ -z ${DOTFILES_SHELL_ROOT:-} ]] || { shell_error 'Already inside a temporary dotfiles shell.'; return 1; }
    [[ ! -L "$shell_pending" ]] || { shell_error 'Refusing a symlink at the session state path.'; return 1; }
    if [[ -d "$shell_pending" && ( ! -f "$shell_pending/phase" || $(cat "$shell_pending/phase") != ready ) ]]; then
        backup=$(mktemp -d "${shell_pending}.interrupted.XXXXXX")
        mv "$shell_pending" "$backup/state"
        printf 'Preserved interrupted preparation at %s; starting a new session.\n' "$backup"
    fi
    if [[ -d "$shell_pending" ]]; then
        shell_workspace=$(cat "$shell_pending/workspace")
        [[ ! -L "$shell_workspace" && -d "$shell_workspace/.dotfiles.git" && -f "$shell_workspace/.git" && $(basename "$shell_workspace") == dotfiles-shell.* ]] || {
            shell_error "Temporary workspace is unavailable; state retained at $shell_pending."; return 1;
        }
        [[ $(shell_temporary_git config --local --get dotfiles.sessionSource) == "$shell_repository" ]] || {
            shell_error 'The retained workspace belongs to another repository.'; return 1;
        }
        if [[ ! -f "$shell_pending/initial-heads" ]]; then
            shell_source_git for-each-ref --format='%(objectname) %(refname)' refs/heads/ > "$shell_pending/initial-heads"
        fi
        echo 'Resuming the retained temporary workspace.'
    else
        shell_prepare
    fi
    printf 'Temporary repository: %s\n' "$shell_workspace"
    echo 'Edit freely and finish add/commit here. Exit the shell to import commits and remove this workspace.'
    (
        unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
        export DOTFILES_SHELL_ROOT="$shell_workspace"
        cd "$shell_workspace"
        shell_open
    ) || result=$?
    if ((result)); then
        printf 'Shell exited with status %s. Workspace retained at %s; run dotfile shell to resume.\n' "$result" "$shell_workspace" >&2
        return "$result"
    fi
    shell_import || return 1
    rm -rf -- "$shell_workspace" "$shell_pending" || return 1
    echo 'Temporary workspace removed. Committed changes are available in the normal dotfiles repository.'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    case "${1:-}" in
        -h|--help) echo 'Usage: dotfile shell'; exit 0 ;;
        --internal-locked) shift ;;
        *)
            [[ $# == 0 ]] || { echo 'Usage: dotfile shell' >&2; exit 2; }
            [[ -t 0 && -t 1 ]] || { echo 'Run dotfile shell from an interactive terminal.' >&2; exit 2; }
            mkdir -p "$(dirname "$shell_pending")"
            exec /usr/bin/lockf -k -t 0 "${shell_pending}.lock" /bin/bash "$0" --internal-locked ;;
    esac
    shell_main
fi
