#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

dotfiles_exec_locked() {
    local lock_file=$1
    shift
    if [[ -x /usr/bin/lockf ]]; then
        exec /usr/bin/lockf -k -t 0 "$lock_file" "$@"
    elif command -v flock >/dev/null 2>&1; then
        exec flock -n "$lock_file" "$@"
    else
        echo 'File locking requires lockf (macOS) or flock (Linux).' >&2
        return 1
    fi
}

configure_dotfiles_repository() (
    local repository_root=$1 repository_metadata current_branch
    repository_metadata="$repository_root/.config/dotfiles"
    export GIT_CONFIG_GLOBAL=/dev/null
    git_dotfiles() { git --git-dir="$repository_root/.dotfiles.git" --work-tree="$repository_root" -C "$repository_root" "$@"; }
    git_dotfiles config --local status.showUntrackedFiles no
    git_dotfiles config --local core.hooksPath "$repository_metadata/hooks"
    git_dotfiles config --local core.logAllRefUpdates true
    git_dotfiles config --local commit.template "$repository_root/.config/git/commit_template"
    git_dotfiles config --local push.autoSetupRemote true
    # shellcheck source=worktree.sh
    source "$repository_metadata/install/worktree.sh"
    dotfiles_configure_worktree "$repository_root/.dotfiles.git" "$repository_root"
    if git_dotfiles rev-parse --verify HEAD >/dev/null 2>&1; then
        dotfiles_reapply_worktree "$repository_root/.dotfiles.git" "$repository_root"
    fi
    configure_crypt_diff
    if git_dotfiles config --local --get remote.origin.url >/dev/null; then
        # Bare clones do not create remote-tracking refs or branch upstreams.
        git_dotfiles config --local remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
        current_branch=$(git_dotfiles symbolic-ref --quiet --short HEAD || true)
        if [[ -n "$current_branch" ]]; then
            git_dotfiles config --local "branch.${current_branch}.remote" origin
            git_dotfiles config --local "branch.${current_branch}.merge" "refs/heads/${current_branch}"
        fi
    fi
    chmod +x "$repository_metadata/hooks/pre-commit" "$repository_metadata/hooks/pre-push"
)

install_brewfile() (
    set -euo pipefail
    local snapshot=$1 brew_prefix
    [[ -r "$snapshot" ]] || { printf 'Cannot read Brewfile: %s\n' "$snapshot" >&2; return 1; }
    brew_prefix=$(brew --prefix)
    # Bundle locates npm using the original PATH, but Homebrew filters the PATH
    # used to execute it. Set both without changing the dump-managed Brewfile.
    export PATH="${brew_prefix}/opt/node@24/bin:${PATH}"
    {
        printf '%s\n' 'ENV["PATH"] = "#{HOMEBREW_PREFIX}/opt/node@24/bin:#{ENV.fetch("PATH")}"'
        cat "$snapshot"
    } | brew bundle install --verbose --no-upgrade --file=-
)

write_machine() {
    local machine=$1 file=$2 temporary
    if [[ -f "$file" && $(cat "$file") == "$machine" ]]; then return 0; fi
    temporary=$(mktemp "$(dirname "$file")/.machine.XXXXXX")
    printf '%s\n' "$machine" > "$temporary"
    mv "$temporary" "$file"
}

configure_crypt_diff() {
    local worktree textconv
    worktree=$(git_dotfiles rev-parse --show-toplevel)
    printf -v textconv '/bin/bash %q' "$worktree/.config/dotfiles/crypt-diff.sh"
    git_dotfiles config --local diff.git-crypt.textconv "$textconv --diff"
    git_dotfiles config --local diff.git-crypt.cachetextconv false
    if [[ $(git_dotfiles config --local --get filter.git-crypt.required || true) == true ]]; then
        git_dotfiles config --local filter.git-crypt.smudge "$textconv --smudge"
    fi
}

private_file_list() {
    local policy_file=$1 policy_path
    while IFS= read -r policy_path; do
        case "$policy_path" in ''|\#*) continue ;; esac
        printf '%s\0' "$policy_path"
    done < "$policy_file"
    git_dotfiles ls-files -z | git_dotfiles check-attr -z --stdin filter | {
        local path attribute value
        while IFS= read -r -d '' path && IFS= read -r -d '' attribute && IFS= read -r -d '' value; do
            if [[ "$attribute" == filter && "$value" == git-crypt ]]; then printf '%s\0' "$path"; fi
        done
    }
}

secure_private_permissions() (
    set -euo pipefail
    local permissions_destination=$1 permissions_stage private_file
    permissions_stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-permissions.XXXXXX")
    trap 'rm -rf -- "$permissions_stage"' EXIT
    private_file_list "$permissions_destination/.config/dotfiles/private-files" > "$permissions_stage/paths"
    while IFS= read -r -d '' private_file; do
        if [[ -f "$permissions_destination/$private_file" ]]; then chmod 600 "$permissions_destination/$private_file"; fi
    done < "$permissions_stage/paths"
)

prepare_git_crypt() (
    set -euo pipefail
    local prepare_destination=$1 prepare_identity=$2 prepare_metadata prepare_secret prepare_pending prepare_header prepare_result prepare_probe='' prepare_path
    prepare_metadata="$prepare_destination/.config/dotfiles"
    prepare_secret="$prepare_destination/.config/git/config.secret"
    prepare_pending="$prepare_destination/.local/state/dotfiles/git-config.pending"
    [[ ! -L "$prepare_secret" && ! -L "$prepare_pending" ]] || { echo 'Refusing a symlink in Git configuration recovery.' >&2; exit 1; }
    [[ ! -e "$prepare_pending" || -f "$prepare_pending" ]] || { echo 'Git configuration recovery requires a regular pending file.' >&2; exit 1; }
    mkdir -p "$(dirname "$prepare_pending")"
    restore_git_config() {
        [[ -f "$prepare_pending" ]] || return 0
        if [[ -e "$prepare_secret" ]]; then
            cmp -s "$prepare_pending" "$prepare_secret" || { echo "Git configuration recovery stopped; both files were preserved: $prepare_pending" >&2; return 1; }
            rm -f "$prepare_pending"
        else
            mv "$prepare_pending" "$prepare_secret"
        fi
    }
    trap 'prepare_result=$?; trap - EXIT; restore_git_config || prepare_result=1; exit "$prepare_result"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    # Recover a previous interrupted installation before suspending the include.
    restore_git_config
    if [[ -f "$prepare_secret" ]]; then
        prepare_header=$(dd if="$prepare_secret" bs=1 count=10 2>/dev/null | od -An -tx1 | tr -d ' \r\n')
        if [[ "$prepare_header" == 00474954435259505400 ]]; then
            # Missing Git include files are harmless; ciphertext is invalid Git config.
            # Restore this tracked file before git-crypt checks worktree cleanliness.
            mv "$prepare_secret" "$prepare_pending"
        fi
    fi
    bash "$prepare_metadata/install/brew.sh"
    if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv bash)"; else eval "$(/usr/local/bin/brew shellenv bash)"; fi
    brew install git-crypt
    restore_git_config
    while IFS= read -r -d '' prepare_path; do
        if git_dotfiles cat-file -e ":$prepare_path" 2>/dev/null; then prepare_probe=$prepare_path; break; fi
    done < <(private_file_list "$prepare_metadata/private-files")
    if [[ -n "$prepare_probe" ]]; then
        git_dotfiles cat-file blob ":$prepare_probe" | bash "$prepare_metadata/key-file.sh" authenticate "$prepare_identity"
    fi
    ensure_unlocked "$prepare_destination" "$prepare_identity"
    secure_private_permissions "$prepare_destination"
)

ensure_unlocked() (
    set -euo pipefail
    local unlock_destination=$1 unlock_identity=$2 private_file unlock_stage=''
    local stored_key="${unlock_destination}/.dotfiles.git/git-crypt/keys/default"
    local key_tool="${unlock_destination}/.config/dotfiles/key-file.sh" header
    bash "$key_tool" normalize "$unlock_identity"
    if [[ ! -f "$stored_key" ]]; then
        bash "$key_tool" unlock "$unlock_identity" --destination "$unlock_destination"
        configure_crypt_diff
        return
    fi
    bash "$key_tool" matches "$stored_key" "$unlock_identity" || {
        echo 'The supplied key differs from the active repository key; leaving both untouched.' >&2
        return 1
    }
    if [[ $(git_dotfiles config --local --get filter.git-crypt.required) != true ]]; then
        bash "$key_tool" unlock "$unlock_identity" --destination "$unlock_destination"
    fi
    configure_crypt_diff
    trap 'if [[ -n "$unlock_stage" ]]; then rm -rf -- "$unlock_stage"; fi' EXIT
    mkdir -p "${unlock_destination}/.local/state/dotfiles"
    unlock_stage=$(mktemp -d "${unlock_destination}/.local/state/dotfiles/unlock.XXXXXX")
    private_file_list "${unlock_destination}/.config/dotfiles/private-files" > "$unlock_stage/paths"
    while IFS= read -r -d '' private_file; do
        [[ -f "${unlock_destination}/${private_file}" ]] || continue
        header=$(dd if="${unlock_destination}/${private_file}" bs=1 count=10 2>/dev/null | od -An -tx1 | tr -d ' \r\n')
        if [[ "$header" == 00474954435259505400 ]]; then
            # Authenticate the entire ciphertext before replacing any working file.
            git_dotfiles crypt smudge < "${unlock_destination}/${private_file}" > "${unlock_stage}/plain"
            chmod 600 "${unlock_stage}/plain"
            mv "${unlock_stage}/plain" "${unlock_destination}/${private_file}"
        fi
    done < "$unlock_stage/paths"
)

install_tmux_config() (
    set -euo pipefail
    local tmux_destination=$1 stage old
    if [[ -s "${tmux_destination}/.tmux.conf" && -s "${tmux_destination}/.tmux.conf.local" ]]; then return 0; fi
    mkdir -p "$(dirname "$tmux_destination")"
    stage=$(mktemp -d "$(dirname "$tmux_destination")/.oh-my-tmux.XXXXXX")
    trap 'rm -rf -- "$stage"' EXIT
    if ! curl -fLsS https://github.com/gpakosz/.tmux/archive/refs/heads/master.tar.gz |
            tar -xz --strip-components=1 -C "$stage"; then
        rm -rf -- "$stage"
        return 1
    fi
    if [[ ! -s "${stage}/.tmux.conf" || ! -s "${stage}/.tmux.conf.local" ]]; then
        rm -rf -- "$stage"
        echo 'Downloaded tmux configuration is incomplete.' >&2
        return 1
    fi
    if [[ -e "$tmux_destination" || -L "$tmux_destination" ]]; then
        old=$(mktemp -d "$(dirname "$tmux_destination")/.oh-my-tmux.backup.XXXXXX")
        mv "$tmux_destination" "${old}/original"
        echo "Preserved incomplete tmux directory at ${old}/original"
    fi
    mv "$stage" "$tmux_destination"
)
