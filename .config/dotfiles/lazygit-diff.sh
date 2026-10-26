#!/usr/bin/env bash
set -euo pipefail
umask 077

metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
export GIT_DIR=${GIT_DIR:-"$(cd "$metadata/../.." && pwd -P)/.dotfiles.git"}
export GIT_WORK_TREE=${GIT_WORK_TREE:-"$(cd "$metadata/../.." && pwd -P)"}
stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-diff.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
cat > "$stage/input"
[[ -s "$stage/input" ]] || exit 0
colored=${DOTFILES_DIFF_COLOR:-1}
if [[ -n ${NO_COLOR+x} ]]; then colored=0; fi
verified=1
if ! bash "$metadata/check-encryption.sh" --records > "$stage/records"; then
    if ! awk -F '\t' '$2 == "blocked" { found=1 } END { exit !found }' "$stage/records"; then verified=0; fi
fi
LC_ALL=C awk -F '\t' -v colored="$colored" -v verified="$verified" '
function unquote(value,    output,i,c,digits,j,n) {
    if (substr(value,1,1)!="\"") { sub(/\t.*/,"",value);return value }
    output=""
    for (i=2;i<=length(value);i++) {
        c=substr(value,i,1)
        if (c=="\"") return output
        if (c=="\\") {
            c=substr(value,++i,1)
            if (c~/[0-7]/) {
                n=c+0
                for (j=0;j<2 && substr(value,i+1,1)~/[0-7]/;j++) n=n*8+substr(value,++i,1)
                c=sprintf("%c",n)
            } else if (c=="t") c="\t"
            else if (c=="n") c="\n"
            else if (c=="r") c="\r"
        }
        output=output c
    }
    return output
}
function path(value) { value=unquote(value);if (value~/^[ab]\//) value=substr(value,3);return value }
function header_paths(line,    value,i,cut,quoted) {
    value=substr(line,12)
    if (substr(value,1,1)=="\"") {
        for (i=2;i<=length(value);i++) {
            if (substr(value,i,1)=="\\") { i++;continue }
            if (substr(value,i,1)=="\"") {
                oldpath=path(substr(value,1,i));newpath=path(substr(value,i+2));return
            }
        }
    } else {
        cut=0
        for (i=1;i<=length(value)-2;i++) if (substr(value,i,3)==" b/") cut=i
        if (cut) { oldpath=path(substr(value,1,cut-1));newpath=path(substr(value,cut+1)) }
    }
}
function flush(    name,banner,style,i) {
    if (!count) return
    name=(newpath!="" && newpath!="/dev/null")?newpath:oldpath
    banner="";style="1;33"
    if (!verified) banner="[UNVERIFIED] Could not inspect the Git index"
    else if (state[name]=="encrypted") { banner="[ENCRYPTED IN INDEX] " name " | blob " substr(object[name],1,12) " verified";style="1;30;43" }
    else if (state[name]=="blocked") { banner="[BLOCKED] " name ": " reason[name];style="1;31" }
    else if (protected[name]) banner="[NOT IN INDEX] " name (newpath=="/dev/null"?" (deleted)":" (not staged)")
    if (banner!="") {
        if (colored) banner=esc "[" style "m" banner esc "[0m"
        print banner;print ""
    }
    for (i=1;i<=count;i++) print chunk[i]
    count=0;oldpath="";newpath="";hunk=0
}
BEGIN { esc=sprintf("%c",27);count=0 }
FILENAME==ARGV[1] { state[$1]=$2;object[$1]=$3;reason[$1]=$4;next }
FILENAME==ARGV[2] { if ($0!="" && $0!~/^#/) protected[$0]=1;next }
{
    raw=$0;line=raw;gsub(esc "\\[[0-9;]*m","",line)
    if (line~/^diff --git /) { flush();header_paths(line);active=1 }
    if (!active) { print raw;next }
    chunk[++count]=raw
    if (line~/^@@/) hunk=1
    if (!hunk && line~/^--- /) oldpath=path(substr(line,5))
    if (!hunk && line~/^\+\+\+ /) newpath=path(substr(line,5))
}
END { flush() }
' "$stage/records" "$metadata/private-files" "$stage/input"
