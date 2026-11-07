#!/usr/bin/env bash
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077
[[ $# -le 1 ]] || { echo 'Usage: check-source-encryption.sh [COMMIT]' >&2; exit 2; }
export GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
script_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
repository=$(git rev-parse --show-toplevel)
source_git() { git --literal-pathspecs -C "$repository" "$@"; }
fail() { printf 'Source encryption check: %s\n' "$*" >&2; exit 1; }
[[ $(source_git rev-parse --is-shallow-repository) == false ]] || fail 'Complete history is required; use checkout fetch-depth: 0.'
if ! tip=$(source_git rev-parse --verify --end-of-options "${1:-HEAD}^{commit}" 2>/dev/null); then
    fail 'Expected a valid commit reference.'
fi
stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-source-check.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/verifier/install"
cp "$script_root/.config/dotfiles/check-encryption.sh" "$stage/verifier/"
cp "$script_root/.config/dotfiles/install/worktree.sh" "$stage/verifier/install/"
source_git rev-list "$tip" > "$stage/commits"
: > "$stage/private-paths"

append_private_path() {
    local path=$1 LC_ALL=C
    case "$path" in
        ''|\#*|/*|.|..|./*|../*|*/./*|*/../*|*/.|*/..) fail 'Private paths must be ordinary repository-relative file names.' ;;
    esac
    [[ ! "$path" =~ [[:cntrl:]] && "$path" != [[:space:]]* && "$path" != *[[:space:]] ]] || fail 'Private paths cannot contain control characters or surrounding whitespace.'
    printf '%s\n' "$path" >> "$stage/private-paths"
}

# Remember declarations from every reachable version. Removing a declaration,
# or fixing the tip after committing plaintext, must not hide the older blob.
while IFS= read -r commit; do
    entry=$(source_git ls-tree "$commit" -- .config/dotfiles/private-files)
    if [[ -n "$entry" ]]; then
        read -r permission kind object <<< "${entry%%$'\t'*}"
        [[ "$kind" == blob && ( "$permission" == 100644 || "$permission" == 100755 ) ]] || fail 'The private-file manifest must be a regular file.'
        source_git cat-file blob "$object" > "$stage/manifest"
        header=$(dd if="$stage/manifest" bs=1 count=10 2>/dev/null | od -An -tx1 | tr -d ' \r\n')
        [[ "$header" != 00474954435259505400 ]] || fail 'The private-file manifest must remain readable.'
        while IFS= read -r path || [[ -n "$path" ]]; do
            case "$path" in ''|\#*) continue ;; esac
            append_private_path "$path"
        done < "$stage/manifest"
    fi
    # Manual .gitattributes declarations are supported too, including files
    # whose encryption attribute was only added in a later commit.
    source_git ls-tree -r -z --name-only "$commit" > "$stage/paths"
    source_git check-attr --source="$commit" -z --stdin filter < "$stage/paths" > "$stage/attributes"
    while IFS= read -r -d '' path && IFS= read -r -d '' attribute && IFS= read -r -d '' value; do
        [[ "$attribute" == filter ]] || fail 'Unexpected attribute inspection result.'
        if [[ "$value" == git-crypt ]]; then
            append_private_path "$path"
            object_size=$(source_git cat-file -s "$commit:$path")
            ((object_size >= 22)) || fail "git-crypt envelope is incomplete at $commit:$path."
        fi
    done < "$stage/attributes"
done < "$stage/commits"
[[ -s "$stage/private-paths" ]] || fail 'No private-file declarations were found; refusing to report a pass.'
LC_ALL=C sort -u "$stage/private-paths" > "$stage/verifier/private-files"

# Use the existing verifier against the ORIGINAL object database. Only the
# helper code and the historical path list are copied, never the source files.
# Commit mode reads ciphertext directly and never requires an unlock key.
repository_git_dir=$(source_git rev-parse --absolute-git-dir)
printf 'HEAD %s refs/heads/source-check %040d\n' "$tip" 0 |
    GIT_DIR="$repository_git_dir" GIT_WORK_TREE="$repository" \
        bash "$stage/verifier/check-encryption.sh" --push
echo 'PASS: original committed private blobs and their reachable history passed ciphertext-format checks; no decryption key was used.'
