#!/usr/bin/env bash
#
# State auditor — config-driven runtime.
#
# Reads checks from tests/audit.yaml, runs each `cmd:` in a bash subshell,
# reports pass/fail. Helpers from tests/checks.sh are exported so cmd
# snippets can call them.
#
# Usage:
#   bash tests/audit.sh                  # run every section
#   bash tests/audit.sh brew defaults    # run listed sections only
#   bash tests/audit.sh --list           # show available sections
#   AUDIT_CONFIG=path/to.yaml bash tests/audit.sh

set -Eeuo pipefail

SELF_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
CONFIG="${AUDIT_CONFIG:-${SELF_DIR}/audit.yaml}"
CHECKS_LIB="${SELF_DIR}/checks.sh"

[[ -f "$CONFIG" ]] || { echo "audit: config not found: $CONFIG" >&2; exit 2; }
command -v ruby >/dev/null 2>&1 || { echo "audit: ruby (for YAML) is required" >&2; exit 2; }

# Load helpers and export every check_* function so cmd: subshells see them.
# shellcheck source=tests/checks.sh
source "$CHECKS_LIB"
while IFS= read -r fn; do
  export -f "$fn"
done < <(declare -F | awk '{print $3}' | grep -E '^check_')

# parse_checks emits one TSV row per check:
#   section <TAB> name <TAB> cmd   (literal newlines in cmd encoded as \n)
parse_checks() {
  ruby -ryaml -e '
    cfg = YAML.load_file(ARGV[0])
    cfg.fetch("sections").each do |section, checks|
      checks.each do |c|
        cmd = c.fetch("cmd").gsub("\n", "\\n")
        puts [section, c.fetch("name"), cmd].join("\t")
      end
    end
  ' "$CONFIG"
}

parse_sections() {
  ruby -ryaml -e 'YAML.load_file(ARGV[0]).fetch("sections").each_key { |s| puts s }' "$CONFIG"
}

usage() {
  cat <<EOF
Usage: bash tests/audit.sh [section...]
  (no args)  run every section in audit.yaml
  --list     print available sections
  --help     this help

Config:  ${CONFIG}  (override with AUDIT_CONFIG=...)
Helpers: ${CHECKS_LIB}  (define new check_* functions there)
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --list)    parse_sections; exit 0 ;;
esac

WANTED=()
if [[ $# -gt 0 ]]; then
  WANTED=("$@")
else
  while IFS= read -r s; do WANTED+=("$s"); done < <(parse_sections)
fi

in_array() { local n=$1; shift; for x in "$@"; do [[ "$x" == "$n" ]] && return 0; done; return 1; }

fail=0
current_section=""

while IFS=$'\t' read -r section name cmd; do
  in_array "$section" "${WANTED[@]}" || continue
  if [[ "$section" != "$current_section" ]]; then
    printf '\n── %s ──\n' "$section"
    current_section=$section
  fi
  cmd=${cmd//\\n/$'\n'}
  if output=$(bash -c "$cmd" 2>&1); then
    printf '  ok: %s\n' "$name"
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n' "$name" >&2
    [[ -n "$output" ]] && printf '      %s\n' "$output" >&2
  fi
done < <(parse_checks)

echo
if (( fail > 0 )); then
  echo "✗ $fail check(s) failed"
  exit 1
fi
echo "✓ all checks passed"
