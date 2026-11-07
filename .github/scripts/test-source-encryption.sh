#!/usr/bin/env bash
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077
script_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
checker="$script_root/.github/scripts/check-source-encryption.sh"
stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-source-test.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
fixture="$stage/checkout with spaces"
private=.config/fish/conf.d/env.secret.fish
mkdir -p "$fixture/.config/dotfiles" "$fixture/.config/fish/conf.d"
g() { git --literal-pathspecs -C "$fixture" "$@"; }
check() { (cd "$fixture" && bash "$checker" "$@"); }
blocked() {
    local reason=$1 result=0
    shift
    # Capture expected failures without Bash 3.2's command/errexit pitfall.
    set +e
    "$@" > "$stage/rejected.out" 2>&1 || result=$?
    set -e
    if ((result == 0)); then echo 'A source check unexpectedly accepted a bad fixture.' >&2; exit 1; fi
    grep -Fq "$reason" "$stage/rejected.out"
    if grep -Fq 'PLAINTEXT_CANARY_NOT_A_SECRET' "$stage/rejected.out"; then
        echo 'The source verifier printed file contents.' >&2; exit 1
    fi
}
commit() { g add --force -- .; g commit -qm "$1"; }

git init -q --initial-branch=main "$fixture"
g config user.name 'Source CI Fixture'
g config user.email source-ci@example.invalid
printf '[attr]private filter=git-crypt diff=git-crypt -text\n%s private\n' "$private" > "$fixture/.gitattributes"
printf '%s\n' "$private" > "$fixture/.config/dotfiles/private-files"
# This verifier only checks committed format, not cryptographic authenticity.
# Synthetic envelopes are deliberately not actual encrypted credentials.
printf '\000GITCRYPT\000synthetic-nonce-and-payload\n' > "$fixture/$private"
commit 'Synthetic ciphertext baseline'
baseline=$(g rev-parse HEAD)
check HEAD > "$stage/baseline.out"
grep -Fq 'original committed private blobs' "$stage/baseline.out"
[[ ! -d "$fixture/.git/git-crypt" ]]
echo 'PASS: original committed ciphertext format is accepted without any key or filter installation.'

# The verifier must inspect Git objects, not index/worktree replacements.
printf 'PLAINTEXT_CANARY_NOT_A_SECRET\n' > "$fixture/$private"
g add --force -- "$private"
check HEAD > "$stage/dirty-index.out"
g commit -qm 'Accidental plaintext source commit'
printf '\000GITCRYPT\000replacement-test-payload\n' > "$fixture/$private"
g add --force -- "$private"
blocked 'raw Git object is NOT encrypted' check HEAD
g commit -qm 'Repair the latest version'
blocked 'raw Git object is NOT encrypted' check HEAD
g reset --hard -q "$baseline"
echo 'PASS: worktree/index replacement cannot mask a plaintext commit, including an ancestor repaired at the tip.'

printf '\000GITCRYPT\000' > "$fixture/$private"
commit 'Truncated ciphertext header'
blocked 'git-crypt envelope is incomplete' check HEAD
g reset --hard -q "$baseline"
echo 'PASS: a truncated git-crypt header is rejected without a decryption key.'

# Forgetting both declarations cannot declassify an existing private path.
printf '# declaration accidentally removed\n' > "$fixture/.gitattributes"
: > "$fixture/.config/dotfiles/private-files"
printf 'PLAINTEXT_CANARY_NOT_A_SECRET\n' > "$fixture/$private"
commit 'Accidentally remove encryption policy'
blocked 'encryption attribute is missing' check HEAD
g reset --hard -q "$baseline"
echo 'PASS: removing attributes and the current manifest does not bypass the historical private-path policy.'

# Manual attribute-only declarations must also protect older plaintext.
manual=.config/manual/credential.conf
mkdir -p "$fixture/.config/manual"
printf 'PLAINTEXT_CANARY_NOT_A_SECRET\n' > "$fixture/$manual"
commit 'New file before a manual encryption declaration'
printf '\n%s private\n' "$manual" >> "$fixture/.gitattributes"
printf '\000GITCRYPT\000manually-declared-test-payload\n' > "$fixture/$manual"
commit 'Manually declare encryption and repair the tip'
blocked 'encryption attribute is missing' check HEAD
g reset --hard -q "$baseline"
rm -rf -- "$fixture/.config/manual"
echo 'PASS: attribute-only declarations are remembered across history too.'

printf 'synthetic-key-copy\n' > "$fixture/.config/dotfiles/.git-crypt.key.TEST"
commit 'Accidentally commit a temporary key copy'
blocked 'local-only paths must not be tracked' check HEAD
g reset --hard -q "$baseline"

g rm -q -- "$private"
g commit -qm 'Remove a private file completely'
check HEAD > "$stage/removed-file.out"
g reset --hard -q "$baseline"
echo 'PASS: local-only files are rejected, while fully deleting a private file remains allowed.'

printf 'public config\n' > "$fixture/.config/public.conf"
commit 'Normal public configuration change'
check HEAD > "$stage/public.out"
g tag source-ci-fixture
check source-ci-fixture > "$stage/tag.out"

before=$(g rev-parse HEAD)
check HEAD > "$stage/read-only.out"
[[ $(g rev-parse HEAD) == "$before" && -z $(g status --porcelain --untracked-files=no) ]]
blocked 'Expected a valid commit reference' check --not-a-valid-ref

shallow="$stage/shallow checkout"
git clone -q --depth=1 "file://$fixture" "$shallow"
# shellcheck disable=SC2016 # The child shell expands its own positional arguments.
blocked 'Complete history is required' bash -c 'cd "$1" && bash "$2" HEAD' shallow-check "$shallow" "$checker"
echo 'PASS: public changes and tags pass; the source remains untouched; shallow history is rejected.'
