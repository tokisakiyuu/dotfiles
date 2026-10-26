#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
set +x
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077

rotation_metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
rotation_root=$(cd "$rotation_metadata/../.." && pwd -P)
rotation_repo="$rotation_root/.dotfiles.git"
rotation_identity="$rotation_metadata/git-crypt.key"
rotation_state="$rotation_root/.local/state/dotfiles"
rotation_pending="$rotation_state/key-rotation.pending"
export GIT_DIR="$rotation_repo" GIT_WORK_TREE="$rotation_root" GIT_CONFIG_GLOBAL=/dev/null
export GIT_OPTIONAL_LOCKS=0

rotation_error() { printf 'dotfile: %s\n' "$*" >&2; exit 1; }
git_dotfiles() { command git --literal-pathspecs --git-dir="$rotation_repo" --work-tree="$rotation_root" -C "$rotation_root" "$@"; }
prepared_git() { command git --literal-pathspecs --git-dir="$rotation_pending/prepared.git" --work-tree="$rotation_root" -C "$rotation_root" "$@"; }
rotation_codec() { bash "$rotation_metadata/key-file.sh" "$@"; }
# shellcheck source=install/lib.sh
source "$rotation_metadata/install/lib.sh"

rotation_phase() { if [[ -f "$rotation_pending/phase" ]]; then cat "$rotation_pending/phase"; else echo preparing; fi; }
set_rotation_phase() {
    printf '%s\n' "$1" > "$rotation_pending/.phase.next"
    mv -f "$rotation_pending/.phase.next" "$rotation_pending/phase"
}
rotation_head() { git_dotfiles rev-parse --verify --quiet HEAD || printf 'UNBORN\n'; }
rotation_open_terminal() { exec 3<>/dev/tty; }
rotation_ask() {
    printf '%s' "$1" >&3
    IFS= read -r rotation_answer <&3
}
rotation_yes() { case "$rotation_answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac; }

archive_rotation() {
    local archive
    archive=$(mktemp -d "$rotation_state/key-rotation.XXXXXX")
    mv "$rotation_pending" "$archive/backup"
    printf 'Backup saved to: %s\n' "$archive/backup"
}

restore_rotation_identity() {
    rotation_codec normalize "$rotation_pending/old.key" --output "$rotation_pending/restore.key" || return 1
    mv -f "$rotation_pending/restore.key" "$rotation_identity" || return 1
}

publish_rotation_identity() {
    if rotation_codec matches "$rotation_identity" "$rotation_pending/new.key"; then
        chmod 600 "$rotation_identity"
        return
    fi
    rotation_codec normalize "$rotation_pending/new.key" --output "$rotation_pending/next.key"
    mv -f "$rotation_pending/next.key" "$rotation_identity"
}

rollback_rotation() {
    # Move Git metadata only. Never checkout, restore or overwrite working files.
    if [[ -d "$rotation_pending/original.git" ]]; then
        if [[ -e "$rotation_repo" ]]; then
            [[ ! -e "$rotation_pending/prepared.git" ]] || return 1
            rotation_codec matches "$rotation_repo/git-crypt/keys/default" "$rotation_pending/new.key" || return 1
            mv "$rotation_repo" "$rotation_pending/prepared.git" || return 1
        fi
        mv "$rotation_pending/original.git" "$rotation_repo" || return 1
    else
        [[ -d "$rotation_repo" ]] || return 1
        rotation_codec matches "$rotation_repo/git-crypt/keys/default" "$rotation_pending/old.key" || return 1
    fi
    restore_rotation_identity || return 1
    set_rotation_phase prepared
}

rotation_cleanup() {
    local result=$?
    trap - EXIT INT TERM
    if [[ -d "$rotation_pending" && $(rotation_phase) == switching ]]; then
        if rollback_rotation; then
            echo 'Switch interrupted. The previous repository and key were restored; working files were preserved. Run dotfile key rotate to resume.' >&2
        else
            printf 'Automatic recovery could not finish. Backup retained at %s. Do not commit; run dotfile key rotate again to recover.\n' "$rotation_pending" >&2
        fi
        if ((result == 0)); then result=1; fi
    fi
    exit "$result"
}

validate_source() {
    [[ ! -L "$rotation_identity" && -f "$rotation_identity" ]] || rotation_error 'Restore the local text key at git-crypt.key before rotating.'
    [[ ! -e "$rotation_repo/index.lock" && ! -e "$rotation_repo/config.lock" ]] || rotation_error 'Another Git operation holds a repository lock. Retry when it finishes.'
    [[ $(git_dotfiles config --local --get core.bare) == true ]] || rotation_error 'The target is not the dotfiles bare repository.'
    [[ -z $(git_dotfiles ls-files --unmerged) ]] || rotation_error 'Resolve merge conflicts before rotating.'
    ensure_unlocked "$rotation_root" "$rotation_identity"
    git_dotfiles diff --quiet -- || rotation_error 'Stage current changes with dotfile add before rotating; no commit is required.'
    local key_file current_records
    for key_file in "$rotation_repo"/git-crypt/keys/*; do
        [[ $(basename "$key_file") == default ]] || rotation_error 'Rotation supports only the default symmetric key.'
    done
    [[ -z $(git_dotfiles ls-files -- .git-crypt) ]] || rotation_error 'Rotation does not support repositories with GPG access grants.'
    current_records=$(bash "$rotation_metadata/check-encryption.sh" --records) || rotation_error 'Current encryption checks failed. Run dotfile verify first.'
    [[ -n "$current_records" ]] || rotation_error 'No encrypted files need key rotation.'
}

validate_unchanged() {
    [[ ! -e "$rotation_repo/index.lock" && ! -e "$rotation_repo/config.lock" ]] || return 1
    [[ ! -L "$rotation_identity" && -f "$rotation_identity" ]] || return 1
    [[ $(rotation_head) == "$(cat "$rotation_pending/source-head")" ]] || return 1
    [[ $(git_dotfiles write-tree) == "$(cat "$rotation_pending/source-tree")" ]] || return 1
    if ! rotation_codec matches "$rotation_identity" "$rotation_pending/old.key"; then
        rotation_codec matches "$rotation_identity" "$rotation_pending/new.key" || return 1
    fi
    rotation_codec matches "$rotation_repo/git-crypt/keys/default" "$rotation_pending/old.key" || return 1
    git_dotfiles diff --quiet -- || return 1
    prepared_git diff --quiet -- || return 1
    [[ $(prepared_git write-tree) == "$(cat "$rotation_pending/prepared-tree")" ]] || return 1
    local prepared_head
    prepared_head=$(prepared_git rev-parse --verify --quiet HEAD || printf 'UNBORN\n')
    [[ "$prepared_head" == "$(cat "$rotation_pending/source-head")" ]]
}

verify_candidate() {
    local name status object _reason
    GIT_DIR="$rotation_pending/prepared.git" GIT_WORK_TREE="$rotation_root" \
        bash "$rotation_metadata/check-encryption.sh" --records > "$rotation_pending/private-records"
    [[ -s "$rotation_pending/private-records" ]] || rotation_error 'No encrypted files need key rotation.'
    while IFS=$'\t' read -r name status object _reason; do
        [[ "$status" == encrypted && -f "$rotation_root/$name" ]] || return 1
        prepared_git cat-file blob "$object" | prepared_git crypt smudge | cmp -s - "$rotation_root/$name" || return 1
    done < "$rotation_pending/private-records"
    rotation_codec matches "$rotation_pending/new.key" "$rotation_pending/prepared.git/git-crypt/keys/default"
}

prepare_rotation() {
    mkdir "$rotation_pending"
    set_rotation_phase preparing
    rotation_codec normalize "$rotation_identity" --output "$rotation_pending/old.key"
    rotation_head > "$rotation_pending/source-head"
    git_dotfiles write-tree > "$rotation_pending/source-tree"
    cp -R "$rotation_repo" "$rotation_pending/prepared.git"
    mv "$rotation_pending/prepared.git/git-crypt" "$rotation_pending/previous-native-state"
    prepared_git crypt init > "$rotation_pending/keygen.log" 2>&1
    rotation_codec normalize "$rotation_pending/prepared.git/git-crypt/keys/default" --output "$rotation_pending/new.key"
    prepared_git add --renormalize -- .
    prepared_git write-tree > "$rotation_pending/prepared-tree"
    verify_candidate
    validate_unchanged || rotation_error 'The repository changed during preparation. Run dotfile key rotate --cancel, then start again.'
    set_rotation_phase prepared
}

activate_rotation() {
    validate_unchanged || rotation_error 'Files or repository state changed after preparation. Run dotfile key rotate --cancel, stage changes, then retry.'
    verify_candidate
    rotation_codec matches "$rotation_identity" "$rotation_pending/new.key"
    set_rotation_phase switching
    mv "$rotation_repo" "$rotation_pending/original.git"
    mv "$rotation_pending/prepared.git" "$rotation_repo"
    (
        # The outer process already holds setup.lock.
        # shellcheck source=setup.sh
        source "$rotation_metadata/setup.sh"
        setup_dotfiles "$rotation_root" --configure-only
    )
    rotation_codec matches "$rotation_identity" "$rotation_repo/git-crypt/keys/default"
    git_dotfiles diff --quiet --
    bash "$rotation_metadata/check-encryption.sh" --index --quiet
    set_rotation_phase complete
    archive_rotation
    echo 'Key rotation complete. Working files remain plaintext; new ciphertext is staged. Nothing was committed or pushed.'
}

rotation_main() {
    local phase action=${1:-}
    [[ $# -le 1 && ( -z "$action" || "$action" == --cancel ) ]] || rotation_error 'Usage: dotfile key rotate [--cancel]'
    [[ ! -L "$rotation_pending" ]] || rotation_error 'The rotation state directory must not be a symlink.'
    trap rotation_cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    if [[ -d "$rotation_pending" ]]; then
        phase=$(rotation_phase)
        case "$phase" in
            switching)
                rollback_rotation || rotation_error 'Recovery failed. Backups were retained; stop repository operations until recovery succeeds.'
                echo 'Recovered the interrupted switch. Resuming with the same prepared key.' ;;
            complete) archive_rotation; echo 'The previous rotation already completed. The active key is unchanged.'; return ;;
            preparing) archive_rotation; echo 'Archived the incomplete preparation. The active key was not changed.' ;;
            prepared) ;;
            *) rotation_error 'Unrecognized rotation state. Backups were retained.' ;;
        esac
    fi
    if [[ "$action" == --cancel ]]; then
        if [[ -d "$rotation_pending" ]]; then
            rotation_codec matches "$rotation_repo/git-crypt/keys/default" "$rotation_pending/old.key" || rotation_error 'The repository key changed. Backups were retained.'
            restore_rotation_identity || rotation_error 'Could not restore the previous text key. Backups were retained.'
            archive_rotation
            echo 'Pending rotation canceled. The previous text key was restored.'
        else
            echo 'No pending rotation. The active key is unchanged.'
        fi
        return
    fi
    if [[ ! -d "$rotation_pending" ]]; then
        rotation_open_terminal || rotation_error 'Run dotfile key rotate from an interactive terminal.'
        validate_source
        echo 'This will rotate the key and re-encrypt staged files. Nothing will be committed or pushed automatically.'
        if [[ $(rotation_head) != UNBORN ]]; then echo 'Existing history still requires the old key, which will be retained in the backup.'; fi
        rotation_ask 'Start rotation? [y/N] '
        if ! rotation_yes; then echo 'Canceled. The key was not rotated.'; return; fi
        echo 'Preparing and verifying new ciphertext...'
        prepare_rotation
    else
        echo 'Resuming the prepared rotation with the same key.'
        validate_unchanged || rotation_error 'Files or repository state changed. Run dotfile key rotate --cancel first.'
        verify_candidate
    fi
    publish_rotation_identity
    activate_rotation
    printf 'New key file: %s\n' "$rotation_identity"
    echo 'Back up the single-line key from this file to secure storage.'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    case "${1:-}" in
        -h|--help) echo 'Usage: dotfile key rotate [--cancel]'; exit 0 ;;
        --internal-locked) shift ;;
        *)
            mkdir -p "$rotation_state"
            if [[ -x /usr/bin/lockf ]]; then
                exec /usr/bin/lockf -k -t 0 "$rotation_state/setup.lock" /bin/bash "$0" --internal-locked "$@"
            elif command -v flock >/dev/null 2>&1; then
                exec flock -n "$rotation_state/setup.lock" /bin/bash "$0" --internal-locked "$@"
            else rotation_error 'No system file-locking tool is available. Rotation stopped.'; fi ;;
    esac
    rotation_main "$@"
fi
