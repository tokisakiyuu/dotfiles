#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
set +x
set -euo pipefail

metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
destination=$(cd "$metadata/../.." && pwd -P)
export GIT_DIR="$destination/.dotfiles.git" GIT_WORK_TREE="$destination"

git_dotfiles() { git --literal-pathspecs --git-dir="$GIT_DIR" --work-tree="$destination" -C "$destination" "$@"; }
fail() { printf 'dotfile: %s\n' "$*" >&2; exit 1; }

help_text() {
    cat <<'HELP'
Usage: dotfile COMMAND

  status [--all]          Show changes and encryption labels (default command)
  diff [--staged] [FILE]  Review changes
  add [--encrypt] [FILE ...]  Stage files; --encrypt also declares them private
  remove PATH ...        Stop tracking and ignore paths; preserve local files
  unstage [PATH ...]     Undo selected staging, or all staging; preserve files
  commit 'MESSAGE'       Verify and commit staged changes
  log [--limit N]        Show recent commits (default: 10)
  pull                   Fast-forward from the configured remote
  push                   Push using the encryption guard
  verify                 Verify private ciphertext in the staging area
  lazygit                Open the encryption-aware dotfiles interface
  key status             Inspect the text key without showing its contents
  key normalize          Losslessly normalize the local key to text
  key unlock             Unlock or resume an interrupted unlock
  key rotate [--cancel]  Rotate interactively, or cancel a prepared rotation
  help                   Show this help

Paths are relative to the current directory, or absolute. Explicit files do not
need -f or an ignore-rule change. Repository metadata and local keys stay local.
Git subcommands and arbitrary Git options are not forwarded.
HELP
}

local_only() {
    case "$1" in
        .dotfiles.git|.dotfiles.git/*|.git|.git/*|.claude|.claude/*|\
        .local/state/dotfiles|.local/state/dotfiles/*|\
        .local/state/dotfiles-migration|.local/state/dotfiles-migration/*|\
        .local/share/chezmoi|.local/share/chezmoi/*|\
        .config/dotfiles/machine|.config/dotfiles/local.fish|\
        .config/dotfiles/backup-location|.config/fish/fish_variables|\
        .config/dotfiles/*.key|.config/dotfiles/.git-crypt.key.*|.config/dotfiles/.machine.*) return 0 ;;
        *) return 1 ;;
    esac
}

select_paths() {
    local purpose=$1 argument absolute parent part name index
    shift
    selected=()
    for argument in "$@"; do
        [[ "$argument" != -* ]] || fail 'Use a file path such as ./-filename; Git flags are not accepted.'
        case "$argument" in
            \~/*) absolute="$HOME/${argument:2}" ;;
            /*) absolute=$argument ;;
            *) absolute="$PWD/$argument" ;;
        esac
        # Normalize dot components without requiring deleted paths to exist.
        local components=() pieces=()
        IFS=/ read -r -a pieces <<< "$absolute"
        for part in ${pieces[@]+"${pieces[@]}"}; do
            case "$part" in
                ''|.) ;;
                ..) if ((${#components[@]})); then index=$((${#components[@]} - 1)); unset "components[$index]"; fi ;;
                *) components[${#components[@]}]=$part ;;
            esac
        done
        absolute=''
        for part in ${components[@]+"${components[@]}"}; do absolute="$absolute/$part"; done
        parent=$(dirname "$absolute")
        if [[ -d "$parent" ]]; then absolute="$(cd "$parent" && pwd -P)/$(basename "$absolute")"; fi
        case "$absolute" in "$destination"/*) name=${absolute#"$destination"/} ;; *) fail 'Paths must be inside your home directory.' ;; esac
        [[ ! "$name" =~ [[:cntrl:]] && "$name" != [[:space:]]* && "$name" != *[[:space:]] ]] || fail 'Use paths without control characters or surrounding whitespace.'
        if [[ "$purpose" == write ]]; then
            if local_only "$name"; then fail "This path is reserved for local data: $name"; fi
            [[ ! -d "$absolute" ]] || fail 'Name individual files; dotfile add without paths stages tracked changes.'
        fi
        selected[${#selected[@]}]=$name
    done
}

require_unlocked() {
    [[ $(git_dotfiles config --local --get filter.git-crypt.required) == true && -f "$GIT_DIR/git-crypt/keys/default" ]] || fail 'Unlock first with: dotfile key unlock'
}

rewrite() {
    local file=$1 temporary mode
    [[ ! -L "$file" ]] || fail 'Refusing to rewrite a policy symlink.'
    temporary=$(mktemp "$(dirname "$file")/.dotfile.XXXXXX")
    cat > "$temporary"
    if [[ -f "$file" ]] && cmp -s "$file" "$temporary"; then rm -f "$temporary"; return; fi
    mode=600
    if [[ -f "$file" ]]; then
        if [[ $(uname -s) == Darwin ]]; then mode=$(stat -f '%Lp' "$file"); else mode=$(stat -c '%a' "$file"); fi
    fi
    chmod "$mode" "$temporary"
    mv -f "$temporary" "$file"
}

append_rule() {
    local file=$1 line=$2
    if [[ -f "$file" ]] && grep -Fxq -- "$line" "$file"; then return; fi
    { if [[ -f "$file" ]]; then cat "$file"; fi; printf '\n%s\n' "$line"; } | rewrite "$file"
}

literal_pattern() {
    local pattern="/$1"
    pattern=${pattern//\\/\\\\}
    pattern=${pattern//\*/\\*}
    pattern=${pattern//\?/\\?}
    pattern=${pattern//\[/\\[}
    printf '%s' "$pattern"
}

private_filter() {
    git_dotfiles check-attr -z filter -- "$1" | {
        local path attribute value
        IFS= read -r -d '' path
        IFS= read -r -d '' attribute
        IFS= read -r -d '' value
        [[ "$path" == "$1" && "$attribute" == filter && "$value" == git-crypt ]]
    }
}

stage_files() {
    local name
    local existing=()
    require_unlocked
    for name in "$@"; do
        if [[ -f "$destination/$name" || -L "$destination/$name" ]]; then
            existing[${#existing[@]}]=$name
        else
            git_dotfiles ls-files --error-unmatch -- "$name" >/dev/null 2>&1 || fail "File does not exist and is not tracked: $name"
        fi
    done
    if (($#)); then
        git_dotfiles add --force -- "$@"
        if ((${#existing[@]})); then git_dotfiles add --renormalize -- "${existing[@]}"; fi
    else
        git_dotfiles add --renormalize -- .
    fi
    bash "$metadata/check-encryption.sh" --index
}

encrypt_files() {
    local name pattern macro existing_macro
    require_unlocked
    for name in "$@"; do
        [[ -f "$destination/$name" && ! -L "$destination/$name" && "$name" != \#* ]] || fail 'Encryption requires existing regular files with ordinary path names.'
        case "$name" in .gitignore|.gitattributes|.config/dotfiles/private-files) fail 'Repository policy files must remain readable.' ;; esac
    done
    macro='[attr]private filter=git-crypt diff=git-crypt -text'
    existing_macro=$(grep -E '^\[attr\]private([[:space:]]|$)' "$destination/.gitattributes" || true)
    [[ -z "$existing_macro" || "$existing_macro" == "$macro" ]] || fail 'The private attribute macro has a conflicting definition.'
    if [[ -z "$existing_macro" ]]; then
        { printf '%s\n\n' "$macro"; cat "$destination/.gitattributes"; } | rewrite "$destination/.gitattributes"
    fi
    for name in "$@"; do
        if ! private_filter "$name"; then
            pattern=$(literal_pattern "$name")
            pattern=${pattern//\\/\\\\}
            pattern=${pattern//\"/\\\"}
            append_rule "$destination/.gitattributes" "\"$pattern\" private"
        fi
        append_rule "$metadata/private-files" "$name"
    done
    for name in "$@"; do private_filter "$name" || fail "Encryption declaration was overridden: $name"; done
    stage_files .gitattributes .config/dotfiles/private-files "$@"
}

command_name=${1:-status}
if (($#)); then shift; fi
case "$command_name" in help|-h|--help) help_text; exit 0 ;; esac
if [[ $# == 1 && ( $1 == --help || $1 == -h ) ]]; then help_text; exit 0; fi
if [[ ! -d "$GIT_DIR" && ! ( "$command_name" == key && ${1:-} == rotate ) ]]; then
    fail 'Missing ~/.dotfiles.git; see ~/README.md.'
fi
if [[ -d "$destination/.local/state/dotfiles/key-rotation.pending" ]]; then
    case "$command_name" in
        add|remove|unstage|commit|pull|push|lazygit) fail 'A key rotation is pending; run dotfile key rotate to finish, or add --cancel to cancel.' ;;
    esac
fi
case "$command_name" in
    status)
        if (($# == 0)); then bash "$metadata/git-display.sh" status
        elif [[ $# == 1 && $1 == --all ]]; then bash "$metadata/git-display.sh" status --untracked-files=all
        else fail 'Usage: dotfile status [--all]'; fi ;;
    diff)
        staged=0
        if [[ ${1:-} == --staged ]]; then staged=1; shift; fi
        select_paths read "$@"
        if ((staged)); then set -- --cached; else set --; fi
        GIT_LITERAL_PATHSPECS=1 bash "$metadata/git-display.sh" diff "$@" -- ${selected[@]+"${selected[@]}"} ;;
    add)
        encrypt_requested=0
        add_arguments=()
        for argument in "$@"; do
            if [[ "$argument" == --encrypt ]]; then encrypt_requested=1
            else add_arguments[${#add_arguments[@]}]=$argument; fi
        done
        if ((encrypt_requested && ${#add_arguments[@]} == 0)); then fail 'Usage: dotfile add --encrypt FILE ...'; fi
        select_paths write ${add_arguments[@]+"${add_arguments[@]}"}
        if ((encrypt_requested)); then encrypt_files "${selected[@]}"
        else stage_files ${selected[@]+"${selected[@]}"}; fi ;;
    remove)
        (($#)) || fail 'Usage: dotfile remove PATH ...'
        select_paths read "$@"
        for name in "${selected[@]}"; do
            rule=$(literal_pattern "$name")
            if [[ -d "$destination/$name" ]]; then rule="$rule/"; fi
            append_rule "$destination/.gitignore" "$rule"
        done
        git_dotfiles rm -r --cached --force --ignore-unmatch -- "${selected[@]}"
        git_dotfiles add -- .gitignore
        echo 'Stopped tracking the selected paths; local files were preserved.' ;;
    unstage)
        select_paths read "$@"
        if ((${#selected[@]} == 0)); then selected=(.); fi
        if git_dotfiles rev-parse --verify HEAD >/dev/null 2>&1; then
            git_dotfiles restore --staged -- "${selected[@]}"
        else git_dotfiles rm -r --cached --force --ignore-unmatch -- "${selected[@]}"; fi ;;
    commit)
        [[ $# == 1 && -n ${1//[[:space:]]/} ]] || fail "Usage: dotfile commit 'MESSAGE'"
        require_unlocked
        bash "$metadata/check-encryption.sh" --index
        git_dotfiles commit -m "$1" ;;
    log)
        limit=10
        if (($#)); then [[ $# == 2 && $1 == --limit ]] || fail 'Usage: dotfile log [--limit N]'; limit=$2; fi
        [[ "$limit" =~ ^([1-9][0-9]{0,2}|1000)$ ]] || fail 'Choose a history limit between 1 and 1000.'
        if ! git_dotfiles rev-parse --verify HEAD >/dev/null 2>&1; then echo 'No commits yet.'; exit 0; fi
        git_dotfiles log --oneline --decorate -n "$limit" ;;
    pull|push)
        (($# == 0)) || fail "Usage: dotfile $command_name"
        [[ -n $(git_dotfiles remote) ]] || fail 'No remote configured. Publish this repository before using pull or push.'
        if [[ "$command_name" == pull ]]; then git_dotfiles pull --ff-only; else git_dotfiles push; fi ;;
    verify)
        (($# == 0)) || fail 'Usage: dotfile verify'
        bash "$metadata/check-encryption.sh" --index ;;
    lazygit)
        (($# == 0)) || fail 'Usage: dotfile lazygit'
        config_dir=$(lazygit --print-config-dir)
        config="$metadata/lazygit.yml"
        if [[ -f "$config_dir/config.yml" ]]; then config="$config_dir/config.yml,$config"; fi
        lazygit --git-dir="$GIT_DIR" --work-tree="$destination" --use-config-file="$config" ;;
    key)
        (($#)) || fail 'Usage: dotfile key status|normalize|unlock|rotate'
        key_action=$1; shift
        if [[ "$key_action" == rotate ]]; then
            [[ $# == 0 || ( $# == 1 && ( $1 == --cancel || $1 == --help || $1 == -h ) ) ]] || fail 'Usage: dotfile key rotate [--cancel]'
            exec /bin/bash "$metadata/rotate-key.sh" "$@"
        fi
        (($# == 0)) || fail 'Usage: dotfile key status|normalize|unlock|rotate'
        if [[ "$key_action" != status && -d "$destination/.local/state/dotfiles/key-rotation.pending" ]]; then
            fail 'Finish or cancel the pending rotation before changing key state.'
        fi
        case "$key_action" in
            status|normalize) bash "$metadata/key-file.sh" "$key_action" "$metadata/git-crypt.key" ;;
            unlock)
                export GIT_CONFIG_GLOBAL=/dev/null
                # shellcheck source=install/lib.sh
                source "$metadata/install/lib.sh"
                ensure_unlocked "$destination" "$metadata/git-crypt.key" ;;
            *) fail 'Usage: dotfile key status|normalize|unlock|rotate' ;;
        esac ;;
    *) fail "Unknown command: $command_name. Run dotfile help." ;;
esac
