#!/bin/bash
# shellcheck disable=SC2016 # Child shells expand positional parameters.
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077
metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
root=$(cd "$metadata/../.." && pwd -P)
stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-entrypoints.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
bash_files=()
fish_files=()
while IFS= read -r -d '' path; do
    case "$path" in
        *.sh|.config/dotfiles/hooks/*) bash_files[${#bash_files[@]}]=$path ;;
        *.fish) fish_files[${#fish_files[@]}]=$path ;;
    esac
done < <(git --git-dir="$root/.dotfiles.git" --work-tree="$root" ls-files -z -- '*.sh' '*.fish' '.config/dotfiles/hooks/*')
for path in "${bash_files[@]}"; do
    /bin/bash -n "$root/$path"
done
for path in "${fish_files[@]}"; do
    if ! fish --no-config -n "$root/$path" > "$stage/fish-syntax.out" 2>&1; then
        printf 'Fish syntax check failed: %s (source diagnostics withheld).\n' "$path" >&2
        exit 1
    fi
done
printf 'PASS: syntax checked %d tracked Bash entry points/libraries and %d tracked fish files.\n' "${#bash_files[@]}" "${#fish_files[@]}"

guarded=0
for path in "${bash_files[@]}"; do
    if ! grep -Fq 'This script requires a file path' "$root/$path"; then continue; fi
    result=0
    cat "$root/$path" | /bin/bash -u > "$stage/piped.out" 2>&1 || result=$?
    [[ "$result" == 2 ]]
    grep -Fq 'This script requires a file path' "$stage/piped.out"
    guarded=$((guarded + 1))
done
printf 'PASS: %d file-dependent scripts reject piped source before executing their bodies.\n' "$guarded"

for path in bootstrap.sh setup.sh rotate-key.sh; do
    /bin/bash "$metadata/$path" --help > "$stage/help.out"
    grep -Fq 'Usage:' "$stage/help.out"
done
/bin/bash "$metadata/dotfile.sh" help > "$stage/help.out"
grep -Fq 'Usage:' "$stage/help.out"
/bin/bash "$root/.config/tmux/scripts/agent-status.sh" --help > "$stage/help.out"
grep -Fq 'Usage:' "$stage/help.out"
cat "$metadata/bootstrap.sh" | /bin/bash -s -- --help > "$stage/bootstrap-pipe.out"
grep -Fq 'Usage:' "$stage/bootstrap-pipe.out"

for path in bootstrap.sh setup.sh rotate-key.sh key-file.sh install/brew.sh install/lib.sh; do
    /bin/bash -u -c 'source "$1"' source-check "$metadata/$path"
done
for path in agent-status.sh agent-status-worker.sh; do
    (cd "$root/.config/tmux/scripts" && /bin/bash -u -c 'source "$1"; [[ ${worker_dir:-$PWD} == "$PWD" ]]' source-check "$path")
done
echo 'PASS: public help/file entry points and supported source imports work, including basename-only tmux imports.'

# Stub state-changing commands; the actual installer bodies still run.
cat > "$stage/install-env.sh" <<'ENVIRONMENT'
brew() {
    [[ "$*" == 'analytics off' ]] || return 99
    printf 'analytics-off\n' >> "$DOTFILES_ENTRYPOINT_LOG"
}
curl() { echo 'Unexpected installer download in entry-point test.' >&2; return 99; }
defaults() { [[ "$*" == 'read com.apple.finder ShowPathbar' ]] || return 99; printf '1\n'; }
osascript() { echo 'Unexpected system preference write in entry-point test.' >&2; exit 99; }
ENVIRONMENT
export DOTFILES_ENTRYPOINT_LOG="$stage/installer.log"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1
BASH_ENV="$stage/install-env.sh" /bin/bash "$metadata/install/brew.sh"
cat "$metadata/install/brew.sh" | BASH_ENV="$stage/install-env.sh" /bin/bash
[[ $(grep -c '^analytics-off$' "$DOTFILES_ENTRYPOINT_LOG") == 2 ]]
BASH_ENV="$stage/install-env.sh" /bin/bash "$metadata/install/defaults.sh" > "$stage/defaults-file.out"
cat "$metadata/install/defaults.sh" | BASH_ENV="$stage/install-env.sh" /bin/bash > "$stage/defaults-pipe.out"
cmp -s "$stage/defaults-file.out" "$stage/defaults-pipe.out"
echo 'PASS: standalone installers support file and pipe execution with system writes/downloads stubbed.'

# Piped input data remains supported when Bash executes the script from a file.
printf '' | /bin/bash "$metadata/lazygit-diff.sh" > "$stage/empty-diff.out"
[[ ! -s "$stage/empty-diff.out" ]]
printf '' | /bin/bash "$metadata/hooks/pre-push" > "$stage/empty-push.out"
[[ ! -s "$stage/empty-push.out" ]]
echo 'PASS: stdin data remains usable by the diff renderer and Git pre-push hook.'
