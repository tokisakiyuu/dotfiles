#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# shellcheck disable=SC2031 # install_brewfile intentionally confines PATH changes to its subshell.
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077
metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../install/lib.sh
source "$metadata/install/lib.sh"
stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-brew-node.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
stage=$(cd "$stage" && pwd -P)
brew_bin=$(command -v brew)
brew_prefix=$("$brew_bin" --prefix)
node_bin="$brew_prefix/opt/node@24/bin"
[[ -x "$node_bin/node" ]] || { echo 'The real Bundle regression requires installed node@24.' >&2; exit 1; }
fixture_bin="$stage/prefix/opt/node@24/bin"
mkdir -p "$fixture_bin"
ln -s "$node_bin/node" "$fixture_bin/node"
cat > "$fixture_bin/npm" <<'NPM'
#!/bin/bash
set -euo pipefail
# Match the real npm launcher's dependency on /usr/bin/env finding node.
/usr/bin/env node --version >/dev/null
case "$1" in
    list) printf '{"dependencies":{}}\n' ;;
    install)
        [[ ! -e "${0%/*}/fail-install" ]] || exit 42
        printf 'installed\n' >> "${0%/*}/installed" ;;
    *) echo 'Unexpected npm command in fixture.' >&2; exit 99 ;;
esac
NPM
chmod 700 "$fixture_bin/npm"
printf 'npm "dotfiles-node-path-fixture"\n' > "$stage/Brewfile"
cp "$stage/Brewfile" "$stage/original"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ASK=1
# Keep actual Node out of the regular prefix and avoid all shell startup files.
export PATH="$fixture_bin:/usr/bin:/bin:/usr/sbin:/sbin"
unset HOMEBREW_BREW_FILE HOMEBREW_PATH
result=0
"$brew_bin" bundle install --no-upgrade --file="$stage/Brewfile" > "$stage/before.out" 2>&1 || result=$?
[[ "$result" != 0 && ! -e "$fixture_bin/installed" ]]
grep -Fq 'node: No such file or directory' "$stage/before.out"
echo 'PASS: real Homebrew Bundle reproduces missing node despite node@24 being in the caller PATH; npm writes are stubbed.'
brew() {
    if [[ "$1" == --prefix ]]; then printf '%s\n' "$stage/prefix";
    else "$brew_bin" "$@"; fi
}
original_path=$PATH
if ! install_brewfile "$stage/Brewfile" > "$stage/after.out" 2>&1; then cat "$stage/after.out" >&2; exit 1; fi
[[ $(wc -l < "$fixture_bin/installed") -eq 1 && "$PATH" == "$original_path" ]]
cmp -s "$stage/Brewfile" "$stage/original"
echo 'PASS: the setup helper runs real Bundle with real Node, executes the npm fixture, preserves PATH and leaves the snapshot unchanged.'
rm "$fixture_bin/installed"
# A second invocation must also work without editing the saved Brewfile.
install_brewfile "$stage/Brewfile" > "$stage/repeat.out" 2>&1
[[ $(wc -l < "$fixture_bin/installed") -eq 1 ]]
cmp -s "$stage/Brewfile" "$stage/original"
echo 'PASS: the Node PATH fix works on repeated initialization without writing global configuration or installing real npm packages.'
rm "$fixture_bin/installed"
touch "$fixture_bin/fail-install"
if install_brewfile "$stage/Brewfile" > "$stage/failure.out" 2>&1; then
    echo 'An npm installation failure was reported as success.' >&2; exit 1
fi
[[ ! -e "$fixture_bin/installed" ]]
cmp -s "$stage/Brewfile" "$stage/original"
echo 'PASS: a real Bundle failure propagates out of the setup helper and preserves the saved Brewfile.'
