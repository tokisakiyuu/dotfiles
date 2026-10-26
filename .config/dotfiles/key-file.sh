#!/usr/bin/env bash
set +x
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077

key_metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
key_destination=$(cd "$key_metadata/../.." && pwd -P)
key_temporary=''
trap 'if [[ -n "$key_temporary" ]]; then rm -f -- "$key_temporary"; fi' EXIT

key_error() { echo "Key operation failed: $*" >&2; exit 1; }
base64_decode() { if [[ $(uname -s) == Darwin ]]; then base64 -D; else base64 -d; fi; }
base64_line() { base64 | tr -d '\r\n'; }

key_kind() {
    local file=$1 size header text
    [[ -r "$file" ]] || key_error 'Key file is not readable.'
    size=$(wc -c < "$file"); size=${size//[[:space:]]/}
    ((size > 0 && size <= 4096)) || key_error 'Invalid key file size.'
    header=$(dd if="$file" bs=1 count=12 2>/dev/null | base64_line)
    if [[ "$header" == AEdJVENSWVBUS0VZ ]]; then
        echo native
    else
        text=$(cat "$file")
        if [[ "$text" == gc1:* ]]; then
            text=${text#gc1:}
            [[ ${#text} == 128 && "$text" =~ ^[A-Za-z0-9_-]+$ ]] || key_error 'Invalid gc1 text key.'
            echo compact
        else
            [[ ${#text} == 200 && "$text" =~ ^[A-Za-z0-9+/]+==$ ]] || key_error 'Invalid legacy Base64 key.'
            echo base64
        fi
    fi
}

material_stream() { printf '%s' "$1" | tr '_-' '/+' | base64_decode; }

native_from_material() {
    # Native v2/default/version-0 format; only the 96 random bytes vary.
    printf '\000GITCRYPTKEY\000\000\000\002\000\000\000\000\000\000\000\001\000\000\000\004\000\000\000\000\000\000\000\003\000\000\000\040'
    material_stream "$1" | { dd bs=1 count=32 2>/dev/null; cat >/dev/null; }
    printf '\000\000\000\005\000\000\000\100'
    material_stream "$1" | { dd bs=1 skip=32 count=64 2>/dev/null; cat >/dev/null; }
    printf '\000\000\000\000'
}

native_stream() {
    local kind text
    kind=$(key_kind "$1")
    case "$kind" in
        native) cat "$1" ;;
        base64) text=$(cat "$1"); printf '%s' "$text" | base64_decode ;;
        compact) text=$(cat "$1"); native_from_material "${text#gc1:}" ;;
    esac
}

compact_key() {
    local complete material reconstructed
    complete=$(native_stream "$1" | base64_line)
    [[ ${#complete} == 200 ]] || key_error 'Unsupported native key length.'
    material=$({
        native_stream "$1" | { dd bs=1 skip=40 count=32 2>/dev/null; cat >/dev/null; }
        native_stream "$1" | { dd bs=1 skip=80 count=64 2>/dev/null; cat >/dev/null; }
    } | base64_line | tr '/+' '_-')
    [[ ${#material} == 128 && "$material" =~ ^[A-Za-z0-9_-]+$ ]] || key_error 'Invalid key material.'
    reconstructed=$(native_from_material "$material" | base64_line)
    [[ "$complete" == "$reconstructed" ]] || key_error 'Expected a single default v2 key; unknown formats are refused.'
    printf 'gc1:%s\n' "$material"
}

key_main() {
    local action=${1:-} source_file target compact first second replace=1 kind
    (($#)) || key_error 'Usage: key-file.sh status|normalize|matches|unlock [FILE]'
    shift
    if [[ "$action" == matches ]]; then
        [[ $# == 2 ]] || key_error 'matches requires two key-file paths.'
        first=$(compact_key "$1"); second=$(compact_key "$2")
        [[ "$first" == "$second" ]]
        return
    fi
    source_file=${1:-"$key_metadata/git-crypt.key"}
    if (($#)); then shift; fi
    compact=$(compact_key "$source_file")
    case "$action" in
        normalize)
            target=$source_file
            if (($#)); then
                [[ $# == 2 && $1 == --output ]] || key_error 'normalize accepts only --output FILE.'
                target=$2; replace=0
            fi
            [[ ! -L "$target" ]] || key_error 'Refusing a symlink at the key destination.'
            key_temporary=$(mktemp "$(dirname "$target")/.git-crypt.key.XXXXXX")
            printf '%s\n' "$compact" > "$key_temporary"
            chmod 600 "$key_temporary"
            if [[ -f "$target" ]] && cmp -s "$key_temporary" "$target"; then
                chmod 600 "$target"
            elif ((replace)); then
                mv -f "$key_temporary" "$target"
            else
                [[ ! -e "$target" ]] || key_error 'The output already exists with different contents.'
                ln "$key_temporary" "$target"
            fi
            rm -f -- "$key_temporary"; key_temporary='' ;;
        status)
            (($# == 0)) || key_error 'status accepts only a key-file path.'
            kind=$(key_kind "$source_file")
            if [[ "$kind" == compact ]]; then echo 'Key valid: gc1 text (132 characters); contents hidden.'
            else echo 'Key valid: legacy encoding; run normalize; contents hidden.'; fi ;;
        unlock)
            if (($#)); then [[ $# == 2 && $1 == --destination ]] || key_error 'unlock accepts only --destination DIRECTORY.'; key_destination=$2; fi
            GIT_CONFIG_GLOBAL=/dev/null native_from_material "${compact#gc1:}" |
                GIT_CONFIG_GLOBAL=/dev/null git --git-dir="$key_destination/.dotfiles.git" --work-tree="$key_destination" -C "$key_destination" crypt unlock - ;;
        *) key_error 'Usage: key-file.sh status|normalize|matches|unlock [FILE]' ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then key_main "$@"; fi
