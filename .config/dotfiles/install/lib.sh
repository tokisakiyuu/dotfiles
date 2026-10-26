#!/usr/bin/env bash

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
