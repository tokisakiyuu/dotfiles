#!/usr/bin/env bash
set +x
set -euo pipefail
umask 077
mode=${1:-}
case "$mode" in
    --diff) [[ $# == 2 ]] || exit 2; input=$2 ;;
    --smudge) [[ $# == 1 ]] || exit 2 ;;
    *) echo 'Expected --diff FILE or --smudge.' >&2; exit 2 ;;
esac
repository=$(command git rev-parse --absolute-git-dir)
worktree=$(command git rev-parse --show-toplevel)
active_key="$repository/git-crypt/keys/default"
[[ -f "$active_key" ]] || { echo 'Unlock the repository with dotfile key unlock before viewing private diffs.' >&2; exit 1; }
stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-textconv.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
if [[ "$mode" == --smudge ]]; then input="$stage/input"; cat > "$input"; fi
state="$worktree/.local/state/dotfiles"
for candidate in "$active_key" \
    "$state/key-rotation.pending/original.git/git-crypt/keys/default" \
    "$state/key-rotation.pending/previous-native-state/keys/default" \
    "$state"/key-rotation.*/backup/original.git/git-crypt/keys/default; do
    [[ -f "$candidate" ]] || continue
    # Authenticate before emitting plaintext; failed key attempts stay private.
    if [[ "$mode" == --smudge ]]; then
        result=0
        command git-crypt smudge --key-file="$candidate" < "$input" > "$stage/plain" 2> "$stage/error" || result=$?
    else
        result=0
        command git-crypt diff --key-file="$candidate" -- "$input" > "$stage/plain" 2> "$stage/error" || result=$?
    fi
    if ((result == 0)); then
        cat "$stage/plain"
        exit 0
    fi
done
echo 'Could not decrypt this diff with the active or archived keys. Preserve the rotation backups when keeping old history.' >&2
exit 1
