#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# shellcheck disable=SC2031 # Fixture setup deliberately runs in an isolated subshell.
set -euo pipefail
trap 'printf "Rotation fixture failed at line %s (callers: %s)\n" "$LINENO" "${BASH_LINENO[*]}" >&2' ERR
umask 077
metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-rotation-test.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT
test_root=$(cd "$test_root" && pwd -P)
export GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
mkdir "$test_root/bin"
cat > "$test_root/bin/pbcopy" <<'CLIPBOARD'
#!/bin/bash
touch "$DOTFILES_TEST_CLIPBOARD_CALLED"
echo 'Unexpected clipboard access during key rotation.' >&2
exit 1
CLIPBOARD
chmod 700 "$test_root/bin/pbcopy"
export PATH="$test_root/bin:$PATH"
export DOTFILES_TEST_CLIPBOARD_CALLED="$test_root/clipboard-called"

cat > "$test_root/driver.sh" <<'DRIVER'
#!/bin/bash
set -euo pipefail
source "$1/.config/dotfiles/rotate-key.sh"
mkdir -p "$rotation_state"
exec 4< "$2"
rotation_open_terminal() { exec 3>/dev/null; }
rotation_ask() { IFS= read -r rotation_answer <&4; }
if [[ ${3:-} == interrupt-before-switch ]]; then
    # Simulate termination after publishing the key, before switching metadata.
    activate_rotation() { exit 75; }
elif [[ ${3:-} == fail-switch ]]; then
    rotation_codec() {
        if [[ "$1" == matches && "$2" == "$rotation_identity" && $(rotation_phase) == switching ]]; then return 1; fi
        bash "$rotation_metadata/key-file.sh" "$@"
    }
fi
rotation_main
DRIVER

g() { command git --literal-pathspecs --git-dir="$fixture/.dotfiles.git" --work-tree="$fixture" -C "$fixture" "$@"; }
cli() { (cd "$fixture" && /bin/bash .config/dotfiles/dotfile.sh "$@"); }
rotate() { /bin/bash "$test_root/driver.sh" "$fixture" "$test_root/answers" "${1:-}"; }
prepare() {
    local result=0
    rotate interrupt-before-switch > "$test_root/$1" || result=$?
    [[ "$result" == 75 ]]
}
bad() { if "$@" > "$test_root/expected-error.log" 2>&1; then echo 'An expected rejection did not happen.' >&2; exit 1; fi; }
archive_path() {
    local item
    for item in "$fixture/.local/state/dotfiles"/key-rotation.*/backup; do
        if [[ -f "$item/phase" ]] && grep -Fxq complete "$item/phase"; then printf '%s\n' "$item"; return; fi
    done
    return 1
}

for variant in unborn committed; do
    fixture="$test_root/$variant workspace"
    mkdir -p "$fixture/.config/dotfiles" "$fixture/.config/fish/conf.d"
    cp "$metadata"/*.sh "$fixture/.config/dotfiles/"
    cp -R "$metadata/install" "$metadata/hooks" "$fixture/.config/dotfiles/"
    cp "$metadata/../../.gitignore" "$metadata/../../.gitattributes" "$fixture/"
    printf '.config/fish/conf.d/env.secret.fish\n' > "$fixture/.config/dotfiles/private-files"
    printf 'set -gx ROTATION_FIXTURE dummy\n' > "$fixture/.config/fish/conf.d/env.secret.fish"
    printf 'public fixture\n' > "$fixture/README.md"
    git init --bare -q --initial-branch=main "$fixture/.dotfiles.git"
    g config user.name 'Rotation Test'
    g config user.email rotation@example.invalid
    g crypt init > "$test_root/init.log" 2>&1
    identity="$fixture/.config/dotfiles/git-crypt.key"
    bash "$fixture/.config/dotfiles/key-file.sh" normalize "$fixture/.dotfiles.git/git-crypt/keys/default" --output "$identity"
    (
        # shellcheck source=../setup.sh
        source "$fixture/.config/dotfiles/setup.sh"
        setup_dotfiles "$fixture" macbook-m4 --configure-only
    )
    g add -- .gitignore .gitattributes .config/dotfiles .config/fish README.md
    if [[ "$variant" == committed ]]; then cli commit 'disposable rotation fixture' > "$test_root/commit.log" 2>&1; fi
    original_head=$(g rev-parse --verify --quiet HEAD || printf 'UNBORN\n')
    original_tree=$(g write-tree)
    original_oid=$(g rev-parse :.config/fish/conf.d/env.secret.fish)
    cp "$identity" "$test_root/original.key"
    pending="$fixture/.local/state/dotfiles/key-rotation.pending"

    printf '\n' > "$test_root/answers"
    rotate > "$test_root/decline.log"
    [[ ! -d "$pending" && $(g write-tree) == "$original_tree" ]]
    cmp -s "$identity" "$test_root/original.key"
    printf 'yes\n' > "$test_root/answers"
    prepare prepare.log
    [[ $(cat "$pending/phase") == prepared ]]
    cmp -s "$identity" "$pending/new.key"
    bash "$metadata/key-file.sh" matches "$fixture/.dotfiles.git/git-crypt/keys/default" "$test_root/original.key"
    [[ $(g write-tree) == "$original_tree" ]]
    [[ $(wc -c < "$identity") -eq 133 ]]
    [[ $(stat -f '%Lp' "$identity") == 600 ]]
    [[ ! -e "$DOTFILES_TEST_CLIPBOARD_CALLED" ]]
    command git --git-dir="$fixture/.dotfiles.git" --work-tree="$fixture" -C "$fixture" check-ignore -q -- "$identity"
    cp "$pending/new.key" "$test_root/expected-new.key"
    text_key_before=$(stat -f '%i:%m:%z' "$identity")
    : > "$test_root/answers"
    prepare interrupt-again.log
    cmp -s "$identity" "$test_root/expected-new.key"
    [[ $(stat -f '%i:%m:%z' "$identity") == "$text_key_before" ]]
    bad cli add README.md
    bad cli remove README.md
    bad cli commit 'must not commit during rotation'
    bad cli key rotate --cancel unexpected
    [[ $(cat "$pending/phase") == prepared ]]
    rotate > "$test_root/resume.log"
    [[ ! -d "$pending" ]]
    grep -Fq "New key file: $identity" "$test_root/resume.log"
    cmp -s "$identity" "$test_root/expected-new.key"
    [[ $(g rev-parse :.config/fish/conf.d/env.secret.fish) != "$original_oid" ]]
    [[ $(g rev-parse --verify --quiet HEAD || printf 'UNBORN\n') == "$original_head" ]]
    g cat-file blob :.config/fish/conf.d/env.secret.fish | g crypt smudge | cmp -s - "$fixture/.config/fish/conf.d/env.secret.fish"
    archive=$(archive_path)
    cmp -s "$archive/old.key" "$test_root/original.key"
    if g cat-file blob :.config/fish/conf.d/env.secret.fish |
        git-crypt smudge --key-file="$archive/original.git/git-crypt/keys/default" > /dev/null 2>&1; then
        echo 'The old key unexpectedly decrypted new ciphertext.' >&2; exit 1
    fi
    if [[ "$variant" == committed ]]; then
        printf 'set -gx ROTATION_FIXTURE updated\n' > "$fixture/.config/fish/conf.d/env.secret.fish"
        cli add .config/fish/conf.d/env.secret.fish > "$test_root/history-add.log"
        cli diff --staged .config/fish/conf.d/env.secret.fish > "$test_root/history-diff.log"
        grep -Fq '[ENCRYPTED IN INDEX]' "$test_root/history-diff.log"
        grep -Fq 'updated' "$test_root/history-diff.log"
    fi
    echo "PASS: $variant interrupted rotation resumes with the same key and no input, preserves plaintext/history, and archives the old key; no commit/push occurs."

    cp "$identity" "$test_root/current.key"
    current_tree=$(g write-tree)
    printf 'yes\n' > "$test_root/answers"
    prepare prepare-cancel.log
    if cmp -s "$identity" "$test_root/current.key"; then echo 'The new text key was not published.' >&2; exit 1; fi
    cli key rotate --cancel > "$test_root/cancel.log"
    [[ ! -d "$pending" && $(g write-tree) == "$current_tree" ]]
    cmp -s "$identity" "$test_root/current.key"
    echo "PASS: $variant cancel clears pending state and preserves the active key/index."

    printf 'yes\n' > "$test_root/answers"
    bad rotate fail-switch
    [[ $(cat "$pending/phase") == prepared && $(g write-tree) == "$current_tree" ]]
    cmp -s "$identity" "$test_root/current.key"
    : > "$test_root/answers"
    rotate > "$test_root/rollback-resume.log"
    [[ ! -d "$pending" ]]
    echo "PASS: $variant injected activation failure rolls back metadata and key, then resumes successfully."

    cp "$identity" "$test_root/current.key"
    current_tree=$(g write-tree)
    printf 'yes\n' > "$test_root/answers"
    prepare prepare-interrupt.log
    printf 'switching\n' > "$pending/phase"
    mv "$fixture/.dotfiles.git" "$pending/original.git"
    cli key rotate --cancel > "$test_root/recover-missing.log"
    [[ -d "$fixture/.dotfiles.git" && ! -d "$pending" && $(g write-tree) == "$current_tree" ]]
    cmp -s "$identity" "$test_root/current.key"
    echo "PASS: $variant recovery works even when interruption left the active bare repository temporarily absent."

    for point in before-repository repository key; do
        printf 'yes\n' > "$test_root/answers"
        prepare "prepare-interrupt-$point.log"
        printf 'switching\n' > "$pending/phase"
        if [[ "$point" != before-repository ]]; then
            mv "$fixture/.dotfiles.git" "$pending/original.git"
            mv "$pending/prepared.git" "$fixture/.dotfiles.git"
        fi
        if [[ "$point" == key ]]; then cp "$pending/new.key" "$identity"; fi
        cli key rotate --cancel > "$test_root/recover-$point.log"
        [[ ! -d "$pending" && $(g write-tree) == "$current_tree" ]]
        cmp -s "$identity" "$test_root/current.key"
    done
    echo "PASS: $variant recovery also handles interruption before or after repository replacement."

    printf 'yes\n' > "$test_root/answers"
    prepare prepare-edited.log
    printf 'user edit during preparation\n' >> "$fixture/README.md"
    printf 'yes\n' > "$test_root/answers"
    bad rotate
    [[ $(cat "$pending/phase") == prepared ]]
    cli key rotate --cancel > "$test_root/cancel-edited.log"
    cmp -s "$identity" "$test_root/current.key"
    grep -Fxq 'user edit during preparation' "$fixture/README.md"
    cli add README.md > "$test_root/add-edited.log"
    echo "PASS: $variant edits during preparation prevent switching, survive cancellation, and remain stageable."
done
[[ ! -e "$DOTFILES_TEST_CLIPBOARD_CALLED" ]]
echo 'ALL ROTATION CHECKS PASSED. Only disposable fixture keys were rotated; no clipboard access occurred.'
