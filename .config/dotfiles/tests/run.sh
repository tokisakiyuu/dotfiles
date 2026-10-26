#!/bin/bash
# shellcheck source-path=SCRIPTDIR
# shellcheck disable=SC2031 # Fixture setup deliberately changes variables only in subshells.
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
trap 'printf "Fixture failed at line %s\n" "$LINENO" >&2' ERR
umask 077
test_metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
live=$(cd "$test_metadata/../.." && pwd -P)
bash "$test_metadata/tests/entrypoints.sh"
bash "$test_metadata/tests/git-config-bootstrap.sh"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bash-test.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT
test_root=$(cd "$test_root" && pwd -P)
fixture="$test_root/source"
mkdir -p "$fixture/.config/dotfiles" "$fixture/.config/brew" "$test_root/fake-bin"
cp "$live"/.config/dotfiles/*.sh "$fixture/.config/dotfiles/"
cp -R "$live/.config/dotfiles/install" "$live/.config/dotfiles/hooks" "$live/.config/dotfiles/machines" "$fixture/.config/dotfiles/"
cp "$live/.config/dotfiles/private-files" "$live/.config/dotfiles/lazygit.yml" "$fixture/.config/dotfiles/"
cp "$live/.gitattributes" "$live/.gitignore" "$live/README.md" "$fixture/"
printf 'brew "fish"\n' > "$fixture/.config/brew/Brewfile.macbook-m4"
export GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE NO_COLOR
for executable in python python3; do
    # shellcheck disable=SC2016 # Expand this variable only inside the stub.
    printf '#!/bin/bash\nprintf called >> "$DOTFILES_PYTHON_CALLED"\nexit 99\n' > "$test_root/fake-bin/$executable"
    chmod 700 "$test_root/fake-bin/$executable"
done
export DOTFILES_PYTHON_CALLED="$test_root/python-called"
export PATH="$test_root/fake-bin:$PATH"
git_for() { local root=$1; shift; command git --literal-pathspecs --git-dir="$root/.dotfiles.git" --work-tree="$root" -C "$root" "$@"; }
g() { git_for "$fixture" "$@"; }
cli() { (cd "$fixture" && /bin/bash "$fixture/.config/dotfiles/dotfile.sh" "$@"); }
codec() { /bin/bash "$fixture/.config/dotfiles/key-file.sh" "$@"; }
check() { GIT_DIR="$fixture/.dotfiles.git" GIT_WORK_TREE="$fixture" /bin/bash "$fixture/.config/dotfiles/check-encryption.sh" "$@"; }
bad() { if "$@" > "$test_root/expected-error.out" 2>&1; then echo 'An operation expected to fail succeeded.' >&2; exit 1; fi; }
fingerprint() { if [[ $(uname -s) == Darwin ]]; then stat -f '%i:%m:%z' "$1"; else stat -c '%i:%Y:%s' "$1"; fi; }
encrypted() {
    local header
    header=$(g cat-file blob ":$1" | { dd bs=1 count=10 2>/dev/null; cat >/dev/null; } | od -An -tx1 | tr -d ' \r\n')
    [[ "$header" == 00474954435259505400 ]]
    g cat-file blob ":$1" | g crypt smudge | cmp -s - "$fixture/$1"
}
number=0
while IFS= read -r filename; do
    case "$filename" in ''|\#*) continue ;; esac
    mkdir -p "$(dirname "$fixture/$filename")"
    printf 'private fixture %d\n' "$number" > "$fixture/$filename"
    number=$((number + 1))
done < "$fixture/.config/dotfiles/private-files"
command git init --bare -q --initial-branch=main "$fixture/.dotfiles.git"
g config user.name 'Disposable test'
g config user.email test@example.invalid
g config core.hooksPath "$fixture/.config/dotfiles/hooks"
g config status.showUntrackedFiles no
g crypt init > "$test_root/init.out" 2>&1
native="$fixture/.dotfiles.git/git-crypt/keys/default"
identity="$fixture/.config/dotfiles/git-crypt.key"
codec normalize "$native" --output "$identity"
codec matches "$native" "$identity"
[[ $(wc -c < "$identity") == 133 ]]
(
    # shellcheck source=../setup.sh
    source "$fixture/.config/dotfiles/setup.sh"
    setup_dotfiles "$fixture" macbook-m4 --configure-only
)
g add -- README.md .gitignore .gitattributes .config/dotfiles .config/brew
while IFS= read -r filename; do
    case "$filename" in ''|\#*) continue ;; esac
    g add -- "$filename"
done < "$fixture/.config/dotfiles/private-files"
cli log > "$test_root/empty-log.out"
grep -Fxq 'No commits yet.' "$test_root/empty-log.out"
cli commit 'disposable initial fixture' > "$test_root/commit.out" 2>&1
if grep -Eq '^\[ENCRYPTED\]|^PASS:' "$test_root/commit.out"; then
    echo 'A successful commit printed automatic encryption reports.' >&2; exit 1
fi
cli verify > "$test_root/verify.out"
grep -Fq '[ENCRYPTED]' "$test_root/verify.out"
grep -Fq 'PASS:' "$test_root/verify.out"
echo 'PASS: Bash-only CLI verifies and commits a disposable encrypted baseline.'

bad cli git status
bad cli add --force README.md
bad cli commit -m 'unsupported Git flag'
cli help > "$test_root/help"
grep -Fq 'add [--encrypt]' "$test_root/help"
bad cli encrypt README.md
bad cli untrack README.md
bad cli add --encrypt
bad cli remove
bad cli add .config/dotfiles/git-crypt.key
bad cli add .dotfiles.git/config
mkdir -p "$fixture/.claude"
printf 'local fixture' > "$fixture/.claude/settings.json"
bad cli add .claude/settings.json
echo 'PASS: Git forwarding/flags are rejected; local key, repository metadata and Claude files remain protected.'

(
    # shellcheck source=../bootstrap.sh
    source "$live/.config/dotfiles/bootstrap.sh"
    exec 3>/dev/null
    # shellcheck disable=SC2329 # read_key invokes this controlled builtin override.
    read() { bootstrap_key_input=''; }
    trap cleanup_key EXIT
    if read_key 2>/dev/null; then echo 'Empty key input was accepted.' >&2; exit 1; fi
    [[ -z "$bootstrap_key_directory" ]]
)
echo 'PASS: empty interactive key input stops before cloning or creating key files.'

/bin/bash "$live/.config/dotfiles/bootstrap.sh" --help > "$test_root/bootstrap-file-help.out"
cat "$live/.config/dotfiles/bootstrap.sh" | /bin/bash -s -- --help > "$test_root/bootstrap-stdin-help.out"
cmp -s "$test_root/bootstrap-file-help.out" "$test_root/bootstrap-stdin-help.out"
grep -Fq 'Usage: bash bootstrap.sh' "$test_root/bootstrap-stdin-help.out"
mkdir "$test_root/bootstrap-bin"
cat > "$test_root/bootstrap-bin/xcode-select" <<'CLT'
#!/bin/bash
case "$1" in
    -p) exit 1 ;;
    --install) touch "$DOTFILES_TEST_CLT_MARKER" ;;
    *) exit 99 ;;
esac
CLT
chmod 700 "$test_root/bootstrap-bin/xcode-select"
export DOTFILES_TEST_CLT_MARKER="$test_root/clt-requested"
if cat "$live/.config/dotfiles/bootstrap.sh" | PATH="$test_root/bootstrap-bin:$PATH" /bin/bash > "$test_root/bootstrap-stdin.out" 2>&1; then
    echo 'Bootstrap should stop until Command Line Tools are installed.' >&2; exit 1
fi
[[ -f "$DOTFILES_TEST_CLT_MARKER" ]]
grep -Fq 'Finish installing Command Line Tools' "$test_root/bootstrap-stdin.out"
echo 'PASS: file and piped bootstrap entry points work; the real no-argument pipeline reaches the mocked CLT check without changing this machine.'

mkdir -p "$fixture/.config/new-app"
public=.config/new-app/public.conf
printf 'public fixture\n' > "$fixture/$public"
ignore_stamp=$(fingerprint "$fixture/.gitignore")
cli add "$public" > "$test_root/add.out" 2>&1
[[ ! -s "$test_root/add.out" ]]
g ls-files --error-unmatch -- "$public" >/dev/null
[[ $(fingerprint "$fixture/.gitignore") == "$ignore_stamp" ]]
private='.config/new-app/credential [1] ü.conf'
printf 'new private fixture\n' > "$fixture/$private"
cli add --encrypt "$private" > "$test_root/encrypt.out"
encrypted "$private"
attr_stamp=$(fingerprint "$fixture/.gitattributes")
policy_stamp=$(fingerprint "$fixture/.config/dotfiles/private-files")
key_stamp=$(fingerprint "$identity")
oid=$(g rev-parse ":$private")
cli add --encrypt "$private" > "$test_root/encrypt-repeat.out"
[[ $(fingerprint "$fixture/.gitattributes") == "$attr_stamp" && $(fingerprint "$fixture/.config/dotfiles/private-files") == "$policy_stamp" ]]
[[ $(g rev-parse ":$private") == "$oid" && $(fingerprint "$identity") == "$key_stamp" ]]
echo 'PASS: ignored files enroll without -f; private declarations handle spaces, Unicode and brackets; repeated encryption preserves declarations, key and ciphertext.'
cli add "$private" > "$test_root/private-without-flag.out"
encrypted "$private"
converted=.config/new-app/converted.conf
printf 'tracked plaintext fixture\n' > "$fixture/$converted"
cli add "$converted" > "$test_root/converted-plain.out"
cli add "$converted" --encrypt > "$test_root/converted-private.out"
encrypted "$converted"
echo 'PASS: add --encrypt converts an already tracked plaintext file; later plain add preserves encryption.'

manual=.config/new-app/manual-token
printf 'manual declaration fixture\n' > "$fixture/$manual"
printf '\n%s private\n' "$manual" >> "$fixture/.gitattributes"
cli add .gitattributes "$manual" > "$test_root/manual.out"
encrypted "$manual"
printf 'tracked edit\n' > "$fixture/README.md"
printf 'unselected file\n' > "$fixture/.config/new-app/not-selected"
cli add > "$test_root/add-tracked.out"
g diff --cached --name-only -- README.md | grep -Fxq README.md
bad g ls-files --error-unmatch -- .config/new-app/not-selected
bad cli add .config/new-app
cli status > "$test_root/status"
grep -Fq '[ENCRYPTED IN INDEX]' "$test_root/status"
cli diff --staged "$private" > "$test_root/diff"
if ! grep -Fq '[ENCRYPTED IN INDEX]' "$test_root/diff"; then
    awk '/^diff --git|^--- |^\+\+\+ / { print }' "$test_root/diff" >&2
    echo 'Fixture diff banner missing.' >&2
    exit 1
fi
GIT_DIR="$fixture/.dotfiles.git" GIT_WORK_TREE="$fixture" DOTFILES_DIFF_COLOR=1 \
    /bin/bash "$fixture/.config/dotfiles/lazygit-diff.sh" < "$test_root/diff" > "$test_root/color-diff"
grep -Fq "$(printf '\033[1;30;43m')" "$test_root/color-diff"
echo 'PASS: manual private macro works; add without files stages tracked changes only; status and staged diff show verified encryption with yellow backgrounds.'

binary=.config/new-app/private.bin
printf '\000binary fixture\377\n' > "$fixture/$binary"
cli add --encrypt "$binary" > "$test_root/binary-encrypt.out"
cli diff --staged "$binary" > "$test_root/binary-diff.out"
grep -Fq '[ENCRYPTED IN INDEX]' "$test_root/binary-diff.out"
encrypted "$binary"
echo 'PASS: binary private files also show the encryption banner and decrypt byte-for-byte.'

printf 'option-like filename fixture\n' > "$fixture/--stat"
cli add --encrypt ./--stat > "$test_root/option-file-add.out"
cli diff --staged ./--stat > "$test_root/option-file-diff.out"
grep -Fq '[ENCRYPTED IN INDEX]' "$test_root/option-file-diff.out"
encrypted --stat
echo 'PASS: option-like filenames remain literal paths and retain their encryption banner.'

cli unstage "$public"
bad g ls-files --error-unmatch -- "$public"
[[ -f "$fixture/$public" ]]
cli add "$public" > "$test_root/restage.out"
cli remove "$public" > "$test_root/untrack.out"
bad g ls-files --error-unmatch -- "$public"
[[ -f "$fixture/$public" ]]
ignore_stamp=$(fingerprint "$fixture/.gitignore")
cli remove "$public" > "$test_root/untrack-repeat.out"
[[ $(fingerprint "$fixture/.gitignore") == "$ignore_stamp" ]]
echo 'PASS: unstage and remove preserve local files; repeated remove is idempotent.'

base64 < "$native" | tr -d '\r\n' > "$test_root/legacy-base64.key"
codec normalize "$test_root/legacy-base64.key"
codec matches "$test_root/legacy-base64.key" "$identity"
codec normalize "$identity"
[[ $(fingerprint "$identity") == "$key_stamp" ]]
printf 'gc1:invalid' > "$test_root/invalid.key"
bad codec normalize "$test_root/invalid.key"
cp "$fixture/.gitattributes" "$test_root/attributes-backup"
grep -vF 'credential' "$test_root/attributes-backup" > "$fixture/.gitattributes"
bad cli add .gitattributes
grep -Fq '[BLOCKED]' "$test_root/expected-error.out"
cp "$test_root/attributes-backup" "$fixture/.gitattributes"
cli add .gitattributes > "$test_root/restore-attributes.out"
echo 'PASS: legacy key imports remain compatible; normalization is idempotent; malformed keys and missing private declarations are refused.'

cp "$fixture/.dotfiles.git/index" "$test_root/bad-index"
blob=$(printf 'plaintext fixture' | g hash-object -w --stdin)
GIT_INDEX_FILE="$test_root/bad-index" g update-index --cacheinfo "100644,$blob,$private"
bad env GIT_INDEX_FILE="$test_root/bad-index" GIT_DIR="$fixture/.dotfiles.git" GIT_WORK_TREE="$fixture" /bin/bash "$fixture/.config/dotfiles/check-encryption.sh" --index
bad env GIT_INDEX_FILE="$test_root/bad-index" GIT_DIR="$fixture/.dotfiles.git" GIT_WORK_TREE="$fixture" /bin/bash "$fixture/.config/dotfiles/hooks/pre-commit"
grep -Fq '[BLOCKED]' "$test_root/expected-error.out"
forged_blob=$(printf '\000GITCRYPT\000this is still a plaintext fixture' | g hash-object -w --stdin)
GIT_INDEX_FILE="$test_root/bad-index" g update-index --cacheinfo "100644,$forged_blob,$private"
bad env GIT_INDEX_FILE="$test_root/bad-index" GIT_DIR="$fixture/.dotfiles.git" GIT_WORK_TREE="$fixture" /bin/bash "$fixture/.config/dotfiles/check-encryption.sh" --index
GIT_INDEX_FILE="$test_root/bad-index" g update-index --cacheinfo "100644,$blob,$private"
bad_tree=$(GIT_INDEX_FILE="$test_root/bad-index" g write-tree)
old_head=$(g rev-parse HEAD)
bad_commit=$(printf 'disposable plaintext history\n' | g commit-tree "$bad_tree" -p "$old_head")
good_tree=$(g write-tree)
good_commit=$(printf 'disposable repaired tree\n' | g commit-tree "$good_tree" -p "$bad_commit")
printf 'refs/heads/test %s refs/heads/test %040d\n' "$good_commit" 0 > "$test_root/push-input"
if check --push < "$test_root/push-input" > "$test_root/push-check" 2>&1; then echo 'Historical plaintext was not rejected.' >&2; exit 1; fi
echo 'PASS: raw plaintext in an alternate index and older history is blocked by the verifier and hooks.'

g cat-file blob ":$private" > "$fixture/$private"
printf 'preserved user edit\n' > "$fixture/.config/git/config.secret"
cli key unlock > "$test_root/unlock.out"
[[ $(cat "$fixture/$private") == 'new private fixture' ]]
[[ $(cat "$fixture/.config/git/config.secret") == 'preserved user edit' ]]
cli add > "$test_root/add-before-clone"
cli commit 'disposable fixture for bootstrap' > "$test_root/commit-before-clone"
echo 'PASS: interrupted unlock resumes new registered private files and preserves other local plaintext edits.'

restored="$test_root/restored"
mkdir -p "$restored"
cat > "$test_root/bootstrap-test.sh" <<'HARNESS'
#!/bin/bash
set -euo pipefail
source "$1"
source_repo=$2
test_key=$3
test_destination=$4
exec 3</dev/null
trap cleanup_key EXIT
git() {
    if [[ $1 == clone ]]; then
        command git clone --bare -- "$source_repo" "$5"
        command git --git-dir="$5" config --local remote.origin.url "$DOTFILES_REPOSITORY_URL"
    elif [[ ${2:-} == fetch ]]; then
        command git "$1" fetch --no-tags "$source_repo" '+refs/heads/main:refs/remotes/origin/main'
    else command git "$@"; fi
}
bash() {
    case "$1" in
        */setup.sh)
            local setup_script=$1 selected_machine=$2
            (source "$setup_script"; setup_dotfiles "$test_destination" "$selected_machine" --configure-only)
            source "$test_destination/.config/dotfiles/install/lib.sh"
            git_dotfiles() { command git --git-dir="$test_destination/.dotfiles.git" --work-tree="$test_destination" -C "$test_destination" "$@"; }
            ensure_unlocked "$test_destination" "$test_destination/.config/dotfiles/git-crypt.key" ;;
        *) command /bin/bash "$@" ;;
    esac
}
restore_dotfiles "$test_key" macmini-m4 "$test_destination"
HARNESS
/bin/bash "$test_root/bootstrap-test.sh" "$fixture/.config/dotfiles/bootstrap.sh" "$fixture/.dotfiles.git" "$native" "$restored" > "$test_root/bootstrap.out" 2>&1
[[ $(cat "$restored/$private") == 'new private fixture' ]]
[[ $(cat "$restored/.config/dotfiles/machine") == macmini-m4 ]]
restored_key="$restored/.config/dotfiles/git-crypt.key"
restored_stamp=$(fingerprint "$restored_key")
printf 'local user modification\n' > "$restored/$private"
/bin/bash "$test_root/bootstrap-test.sh" "$fixture/.config/dotfiles/bootstrap.sh" "$fixture/.dotfiles.git" "$identity" "$restored" > "$test_root/bootstrap-repeat.out" 2>&1
[[ $(cat "$restored/$private") == 'local user modification' && $(fingerprint "$restored_key") == "$restored_stamp" ]]
[[ ! -e "$DOTFILES_PYTHON_CALLED" ]]
echo 'PASS: fresh bare bootstrap imports binary key into gc1 text, decrypts files, records macmini-m4, and preserves edits on retry. Python stubs were never called.'

state="$test_root/os-state"
mkdir -p "$state" "$test_root/archive/top"
printf '0\n' > "$state/finder"
printf '/bin/zsh\n' > "$state/shell"
printf '/bin/zsh\n' > "$state/shells"
touch "$state/fail-download"
printf 'fixture tmux\n' > "$test_root/archive/top/.tmux.conf"
printf 'fixture tmux local\n' > "$test_root/archive/top/.tmux.conf.local"
tar -czf "$state/archive.tgz" -C "$test_root/archive" top
tmux="$restored/.local/share/tmux/oh-my-tmux"
mkdir -p "$tmux"
printf incomplete > "$tmux/.tmux.conf"
printf preserved > "$tmux/keep-me"
cp "$restored/.config/brew/Brewfile.macbook-m4" "$restored/.config/brew/Brewfile.macmini-m4"
chmod 644 "$restored/$manual"
cat > "$test_root/full-setup.sh" <<'SETUP'
#!/bin/bash
set -euo pipefail
fixture=$1
export DOTFILES_TEST_STATE=$2
source "$fixture/.config/dotfiles/setup.sh"
brew() { printf 'brew %s\n' "$*" >> "$DOTFILES_TEST_STATE/log"; if [[ ${1:-} == --prefix ]]; then echo /opt/homebrew; fi; }
bash() { case "$1" in */install/brew.sh) return 0 ;; *) command /bin/bash "$@" ;; esac; }
curl() { echo download >> "$DOTFILES_TEST_STATE/log"; if [[ -f "$DOTFILES_TEST_STATE/fail-download" ]]; then echo broken; return 22; fi; cat "$DOTFILES_TEST_STATE/archive.tgz"; }
defaults() { if [[ $1 == read ]]; then cat "$DOTFILES_TEST_STATE/finder"; else echo 1 > "$DOTFILES_TEST_STATE/finder"; echo defaults-write >> "$DOTFILES_TEST_STATE/log"; fi; }
osascript() { echo osascript >> "$DOTFILES_TEST_STATE/log"; }
grep() { if [[ ${*: -1} == /etc/shells ]]; then command grep -Fxq "$2" "$DOTFILES_TEST_STATE/shells"; else command grep "$@"; fi; }
sudo() { [[ $1 == tee && $2 == -a && $3 == /etc/shells ]]; command tee -a "$DOTFILES_TEST_STATE/shells"; }
dscl() { printf 'UserShell: %s\n' "$(cat "$DOTFILES_TEST_STATE/shell")"; }
chsh() { echo "$2" > "$DOTFILES_TEST_STATE/shell"; echo chsh >> "$DOTFILES_TEST_STATE/log"; }
export -f defaults osascript
setup_dotfiles "$fixture" macmini-m4
SETUP
bad /bin/bash "$test_root/full-setup.sh" "$restored" "$state"
[[ $(cat "$tmux/keep-me") == preserved ]]
rm "$state/fail-download"
/bin/bash "$test_root/full-setup.sh" "$restored" "$state" > "$test_root/full-setup.out"
/bin/bash "$test_root/full-setup.sh" "$restored" "$state" > "$test_root/full-setup-repeat.out"
[[ $(cat "$restored/$private") == 'local user modification' && $(fingerprint "$restored_key") == "$restored_stamp" ]]
[[ $(grep -c '^download$' "$state/log") == 2 && $(grep -c '^defaults-write$' "$state/log") == 1 && $(grep -c '^chsh$' "$state/log") == 1 ]]
if [[ $(uname -s) == Darwin ]]; then [[ $(stat -f '%Lp' "$restored/$manual") == 600 ]]; else [[ $(stat -c '%a' "$restored/$manual") == 600 ]]; fi
[[ ! -e "$DOTFILES_PYTHON_CALLED" ]]
echo 'PASS: full setup retries failed downloads, preserves local edits and keys, secures macro-declared files, and changes OS settings once. OS/package writes mocked; no Python used.'

cat > "$test_root/fake-bin/brew" <<'BREW'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$DOTFILES_TEST_BREW_LOG"
if [[ $1 == install ]]; then
    if [[ $2 == fixture-partial-failure ]]; then exit 42; fi
elif [[ $1 == bundle && $2 == dump ]]; then
    for argument in "$@"; do
        case "$argument" in --file=*) printf 'brew "fish"\n' > "${argument#--file=}" ;; esac
    done
else exit 2
fi
BREW
chmod 700 "$test_root/fake-bin/brew"
# shellcheck disable=SC2016 # Replace the literal fish variable without changing HOME.
sed 's/\$HOME/\$dotfiles_test_root/g' "$live/.config/fish/functions/brew.fish" > "$test_root/brew-test.fish"
cat > "$test_root/brew-harness.fish" <<'FISH'
set -g dotfiles_test_root $argv[1]
source $argv[2]
brew install fixture-good; or exit 1
brew install fixture-good; or exit 1
brew install fixture-partial-failure
set -l operation_status $status
test $operation_status -eq 42; or exit 1
brew install fixture-good --help; or exit 1
FISH
snapshot="$restored/.config/brew/Brewfile.macmini-m4"
snapshot_stamp=$(fingerprint "$snapshot")
export DOTFILES_TEST_BREW_LOG="$test_root/brew.log"
PATH="$test_root/fake-bin:$PATH" fish --no-config "$test_root/brew-harness.fish" "$restored" "$test_root/brew-test.fish"
[[ $(fingerprint "$snapshot") == "$snapshot_stamp" ]]
[[ $(grep -c '^bundle dump ' "$DOTFILES_TEST_BREW_LOG") == 3 ]]
git_for "$restored" ls-files --error-unmatch -- .config/brew/Brewfile.macmini-m4 >/dev/null
[[ ! -e "$DOTFILES_PYTHON_CALLED" ]]
echo 'PASS: fish brew snapshots successful/partly failed installs, preserves exit codes, skips help, and leaves identical snapshots untouched.'

central="$test_root/central.git"
peer="$test_root/peer"
git clone --bare -q "$fixture/.dotfiles.git" "$central"
mkdir -p "$peer"
git clone --bare -q "$central" "$peer/.dotfiles.git"
git_for "$peer" checkout > "$test_root/peer-checkout.out" 2>&1
cp "$identity" "$peer/.config/dotfiles/git-crypt.key"
(
    # shellcheck source=../setup.sh
    source "$peer/.config/dotfiles/setup.sh"
    setup_dotfiles "$peer" macmini-m4 --configure-only
)
peer_cli() { (cd "$peer" && /bin/bash .config/dotfiles/dotfile.sh "$@"); }
restored_cli() { (cd "$restored" && /bin/bash .config/dotfiles/dotfile.sh "$@"); }
peer_cli key unlock > "$test_root/peer-unlock.out" 2>&1
git_for "$peer" config user.name 'Peer Test'
git_for "$peer" config user.email peer@example.invalid
git_for "$restored" config user.name 'Restored Test'
git_for "$restored" config user.email restored@example.invalid
git_for "$restored" remote set-url origin "$central"
[[ $(git_for "$peer" config --local --get remote.origin.fetch) == '+refs/heads/*:refs/remotes/origin/*' ]]
[[ $(git_for "$peer" config --local --get branch.main.remote) == origin ]]
peer_cli push > "$test_root/first-push.out" 2>&1
printf 'peer update\n' >> "$peer/README.md"
peer_cli add README.md > "$test_root/peer-add.out"
peer_cli commit 'disposable peer update' > "$test_root/peer-commit.out" 2>&1
peer_cli push > "$test_root/peer-push.out" 2>&1
restored_cli pull > "$test_root/restored-pull.out" 2>&1
grep -Fxq 'peer update' "$restored/README.md"
[[ $(cat "$restored/$private") == 'local user modification' ]]
printf 'restored update\n' >> "$restored/README.md"
restored_cli add README.md > "$test_root/restored-add.out"
restored_cli commit 'disposable restored update' > "$test_root/restored-commit.out" 2>&1
printf 'second peer update\n' >> "$peer/README.md"
peer_cli add README.md > "$test_root/second-peer-add.out"
peer_cli commit 'disposable second peer update' > "$test_root/second-peer-commit.out" 2>&1
peer_cli push > "$test_root/second-peer-push.out" 2>&1
restored_head=$(git_for "$restored" rev-parse HEAD)
bad restored_cli pull
[[ $(git_for "$restored" rev-parse HEAD) == "$restored_head" ]]
bad restored_cli push
echo 'PASS: a fresh bare clone pushes without manual upstream setup; two workspaces exchange commits; divergent pull/push preserve local work.'
bash "$live/.config/dotfiles/tests/rotate.sh"
echo 'ALL BASH-ONLY CLI AND RECOVERY CHECKS PASSED. Commits and secrets above were disposable fixtures only.'
