#!/usr/bin/env bash
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077

metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
export GIT_DIR=${GIT_DIR:-"$(cd "$metadata/../.." && pwd -P)/.dotfiles.git"}
export GIT_WORK_TREE=${GIT_WORK_TREE:-"$(cd "$metadata/../.." && pwd -P)"}
cd "$GIT_WORK_TREE"
stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-verify.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT

records=0
quiet=0
mode=index
reference=''
while (($#)); do
    case "$1" in
        --index) mode=index ;;
        --commit) mode=commit; shift; reference=${1:?Missing commit} ;;
        --push) mode=push ;;
        --records) records=1 ;;
        --quiet) quiet=1 ;;
        *) echo 'Usage: check-encryption.sh --index|--commit REF|--push [--records]' >&2; exit 2 ;;
    esac
    shift
done

inspect() {
    local ref=${1:-} entry info name permission object position filter path attribute value
    local index=0 failed=0 count=0 policy_path reason status header active_key
    active_key="$(git rev-parse --absolute-git-dir)/git-crypt/keys/default"
    local names=() objects=() permissions=() positions=() filters=() policies=()
    while IFS= read -r policy_path; do
        case "$policy_path" in ''|\#*) continue ;; esac
        policies[${#policies[@]}]=$policy_path
    done < "$metadata/private-files"
    if [[ -n "$ref" ]]; then git ls-tree -r -z --full-tree "$ref" > "$stage/entries" || return 1
    else git ls-files --stage -z > "$stage/entries" || return 1; fi
    : > "$stage/paths"
    while IFS= read -r -d '' entry; do
        info=${entry%%$'\t'*}; name=${entry#*$'\t'}
        if [[ -n "$ref" ]]; then read -r permission position object <<< "$info"; position=0
        else read -r permission object position <<< "$info"; fi
        names[index]=$name; objects[index]=$object; permissions[index]=$permission; positions[index]=$position
        printf '%s\0' "$name" >> "$stage/paths"
        index=$((index + 1))
    done < "$stage/entries"
    if ((index == 0)); then if ((records == 0 && quiet == 0)); then echo 'No staged files to inspect.'; fi; return 0; fi
    if [[ -n "$ref" ]]; then
        git check-attr --source="$ref" -z --stdin filter < "$stage/paths" > "$stage/attributes" || return 1
    else git check-attr --cached -z --stdin filter < "$stage/paths" > "$stage/attributes" || return 1; fi
    index=0
    while IFS= read -r -d '' path && IFS= read -r -d '' attribute && IFS= read -r -d '' value; do
        [[ "$path" == "${names[index]}" && "$attribute" == filter ]] || { echo 'Encryption attribute inspection failed.' >&2; return 1; }
        filters[index]=$value; index=$((index + 1))
    done < "$stage/attributes"
    [[ $index == "${#names[@]}" ]] || { echo 'Encryption attribute inspection was incomplete.' >&2; return 1; }
    for ((index=0; index<${#names[@]}; index++)); do
        name=${names[index]}; filter=${filters[index]}; object=${objects[index]}
        status=''; reason=''
        if [[ "$filter" == git-crypt ]]; then status=protected
        else
            for policy_path in ${policies[@]+"${policies[@]}"}; do if [[ "$name" == "$policy_path" ]]; then status=protected; break; fi; done
        fi
        [[ -n "$status" ]] || continue
        count=$((count + 1)); status=encrypted
        if [[ "$filter" != git-crypt ]]; then reason='encryption attribute is missing'
        elif [[ ${permissions[index]} != 100644 && ${permissions[index]} != 100755 ]] || [[ ${positions[index]} != 0 ]]; then reason='not a regular, resolved file'
        else
            header=$(git cat-file blob "$object" | { dd bs=1 count=10 2>/dev/null; cat >/dev/null; } | od -An -tx1 | tr -d ' \r\n') || return 1
            if [[ "$header" != 00474954435259505400 ]]; then reason='raw Git object is NOT encrypted'; fi
            if [[ -z "$reason" && -z "$ref" && -f "$active_key" ]]; then
                if ! git cat-file blob "$object" | command git-crypt smudge --key-file="$active_key" > /dev/null 2>/dev/null; then
                    reason='ciphertext does not authenticate with the active key'
                fi
            fi
        fi
        if [[ -n "$reason" ]]; then failed=1; status=blocked; fi
        if ((records)); then printf '%s\t%s\t%s\t%s\n' "$name" "$status" "$object" "$reason"
        elif [[ "$status" == blocked ]]; then printf '[BLOCKED] %s%s: %s\n' "${ref:+$ref }" "$name" "$reason"
        elif ((quiet == 0)); then printf '[ENCRYPTED] %s\n  blob %.12s | raw header 00 47 49 54 43 52 59 50 54 00\n' "$name" "$object"; fi
    done
    if ((failed == 0 && records == 0 && quiet == 0)); then printf '\nPASS: %d private file(s) stored as git-crypt ciphertext.\n' "$count"; fi
    return "$failed"
}

if [[ "$mode" == push ]]; then
    tips=()
    while read -r local_ref local_oid remote_ref remote_oid extra; do
        [[ -n "$local_ref" && -n "$local_oid" && -n "$remote_ref" && -n "$remote_oid" && -z "$extra" ]] || { echo 'Invalid pre-push input.' >&2; exit 1; }
        if [[ -n ${local_oid//0/} ]]; then tips[${#tips[@]}]=$local_oid; fi
    done
    if ((${#tips[@]} == 0)); then exit 0; fi
    git rev-list "${tips[@]}" > "$stage/commits"
    quiet=1; commits=0
    while IFS= read -r reference; do
        if ! inspect "$reference"; then echo 'Push blocked: private history contains unprotected content.' >&2; exit 1; fi
        commits=$((commits + 1))
    done < "$stage/commits"
    printf 'PASS: encrypted private files verified across %d reachable commit(s).\n' "$commits"
else inspect "$reference"; fi
