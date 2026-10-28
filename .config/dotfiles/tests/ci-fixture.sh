#!/bin/bash
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077
[[ $# == 3 ]] || { echo 'Usage: ci-fixture.sh CHECKOUT DESTINATION KEY_FILE' >&2; exit 2; }
checkout=$1 destination=$2 identity=$3
[[ "$destination" == /* && "$identity" == /* ]] || { echo 'Fixture paths must be absolute.' >&2; exit 2; }
[[ ! -e "$destination" && ! -e "$identity" ]] || { echo 'Fixture destination and key must not already exist.' >&2; exit 1; }
export GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
source_git() { command git -C "$checkout" "$@"; }
mkdir -p "$destination"
source_git archive HEAD | tar -x -C "$destination"
source_git ls-files -z > "$destination.paths"
trap 'rm -f -- "$destination.paths"' EXIT
# Replace every declared private file before any file is staged. Never import a
# personal key or try to decrypt the real repository's encrypted blobs.
while IFS= read -r private; do
    case "$private" in ''|\#*) continue ;; esac
    case "$private" in
        .config/fish/conf.d/env.secret.fish)
            printf 'set -gx DOTFILES_CI_FIXTURE 1\n' > "$destination/$private" ;;
        .config/git/config.secret)
            printf '[user]\n\tname = Dotfiles CI\n\temail = dotfiles-ci@example.invalid\n' > "$destination/$private" ;;
        .config/.jira/.config.yml)
            printf 'server: https://jira.example.invalid\nlogin: dotfiles-ci\n' > "$destination/$private" ;;
        *) echo 'Add a safe CI fixture for the newly declared private file.' >&2; exit 1 ;;
    esac
done < "$destination/.config/dotfiles/private-files"
fixture_git() { command git --git-dir="$destination/.dotfiles.git" --work-tree="$destination" -C "$destination" "$@"; }
git init --bare -q --initial-branch=main "$destination/.dotfiles.git"
fixture_git config user.name 'Dotfiles CI'
fixture_git config user.email dotfiles-ci@example.invalid
fixture_git crypt init
/bin/bash "$destination/.config/dotfiles/key-file.sh" normalize \
    "$destination/.dotfiles.git/git-crypt/keys/default" --output "$identity"
# Stage only paths from the checkout, never the generated bare metadata or key.
fixture_git add --force --pathspec-from-file="$destination.paths" --pathspec-file-nul
fixture_git commit -qm 'Disposable encrypted CI fixture'
GIT_DIR="$destination/.dotfiles.git" GIT_WORK_TREE="$destination" \
    /bin/bash "$destination/.config/dotfiles/check-encryption.sh" --index --quiet
echo 'PASS: prepared a disposable repository with generated keys and synthetic private files.'
