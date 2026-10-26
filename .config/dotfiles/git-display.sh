#!/usr/bin/env bash
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077

metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
export GIT_DIR=${GIT_DIR:-"$(cd "$metadata/../.." && pwd -P)/.dotfiles.git"}
export GIT_WORK_TREE=${GIT_WORK_TREE:-"$(cd "$metadata/../.." && pwd -P)"}
cd "$GIT_WORK_TREE"
command_name=${1:?Expected status or diff}; shift
case "$command_name" in status|diff) ;; *) exit 2 ;; esac
for argument in "$@"; do
    [[ "$argument" != -- ]] || break
    case "$argument" in --short|-s|--porcelain*|-z|--raw|--numstat|--name-only|--name-status|--stat|--check|--exit-code|--binary|--no-textconv)
        exec git "$command_name" "$@" ;;
    esac
done
stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-display.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
colored=0
if [[ -t 1 && -z ${NO_COLOR+x} ]]; then colored=1; fi
if ((colored)) && [[ $(git config --get-colorbool "color.$command_name" true || true) != true ]]; then colored=0; fi
arguments=()
if ((colored)); then arguments=(-c "color.$command_name=always"); fi
result=0
git ${arguments[@]+"${arguments[@]}"} "$command_name" "$@" > "$stage/output" || result=$?
if ((result)); then cat "$stage/output"; exit "$result"; fi
if [[ "$command_name" == diff ]]; then
    DOTFILES_DIFF_COLOR=$colored bash "$metadata/lazygit-diff.sh" < "$stage/output"
    exit
fi
verified=0
bash "$metadata/check-encryption.sh" --records > "$stage/records" || verified=$?
if ((verified)) && ! awk -F '\t' '$2 == "blocked" { found=1 } END { exit !found }' "$stage/records"; then
    cat "$stage/output"
    echo '[UNVERIFIED] Could not inspect encryption in the Git index.' >&2
    exit 1
fi
LC_ALL=C awk -F '\t' -v colored="$colored" '
function quote_path(value, nonascii,    output,i,c,n) {
    output="\""
    for (i=1;i<=length(value);i++) {
        c=substr(value,i,1);n=ordinal[c]
        if (c=="\\" || c=="\"") output=output "\\" c
        else if (n<32 || n==127 || (nonascii && n>=128)) output=output sprintf("\\%03o",n)
        else output=output c
    }
    return output "\""
}
BEGIN { esc=sprintf("%c",27); for (i=1;i<256;i++) ordinal[sprintf("%c",i)]=i }
FILENAME==ARGV[1] { names[$1]=1;state[$1]=$2;reason[$1]=$4;next }
FILENAME==ARGV[2] { if ($0!="" && $0!~/^#/) names[$0]=1;next }
{
    raw=$0;line=raw;gsub(esc "\\[[0-9;]*m","",line);best="";longest=0
    if (line~/^\t/ || line~/^[ MADRCU?!T][ MADRCU?!T] /) {
        for (name in names) {
            spelling[1]=name;spelling[2]=quote_path(name,1);spelling[3]=quote_path(name,0)
            for (j=1;j<=3;j++) {
                size=length(spelling[j]);start=length(line)-size+1
                if (size>longest && start>0 && substr(line,start)==spelling[j] &&
                    (start==1 || substr(line,start-1,1)~/[ \t]/)) { best=name;longest=size }
            }
        }
    }
    if (best!="") {
        if (state[best]=="encrypted") { badge="[ENCRYPTED IN INDEX]";style="1;30;43" }
        else if (state[best]=="blocked") { badge="[BLOCKED: " reason[best] "]";style="1;31" }
        else { badge="[NOT IN INDEX]";style="1;33" }
        if (colored) badge=esc "[" style "m" badge esc "[0m"
        raw=raw " " badge
    }
    print raw
}' "$stage/records" "$metadata/private-files" "$stage/output"
exit "$verified"
