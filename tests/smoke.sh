#!/usr/bin/env bash
#
# Post-apply verification: did the run_once_* scripts and chezmoi state
# actually land in ~? Runs in CI and locally.
#
# Usage:
#   bash tests/smoke.sh                    # all sections
#   bash tests/smoke.sh brew packages      # only these
#   bash tests/smoke.sh --list             # show sections
#
# Each check prints "  ok: ..." or "FAIL: ..." and the script exits non-zero
# if anything failed.

set -Eeuo pipefail

fail=0
ok()      { printf '  ok: %s\n' "$1"; }
bad()     { printf 'FAIL: %s\n' "$1" >&2; fail=$((fail + 1)); }
section() { printf '\n── %s ──\n' "$1"; }

# ── brew: install/macos/brew.sh ──────────────────────────────────────────────
check_brew() {
  section "brew (brew.sh)"
  if command -v brew >/dev/null 2>&1; then ok "brew on PATH"; else bad "brew not on PATH"; fi
  if [[ "$(brew analytics state 2>/dev/null)" == *disabled* ]]; then
    ok "brew analytics off"
  else
    bad "brew analytics not disabled"
  fi
}

# ── packages: install/macos/packages.sh (full Brewfile) ──────────────────────
check_packages() {
  section "packages (packages.sh)"
  local bf="$HOME/.config/brew/Brewfile"
  if [[ ! -f "$bf" ]]; then bad "Brewfile missing: $bf"; return; fi

  local formulae casks
  formulae=$(brew list --formula -1 2>/dev/null | sort -u)
  casks=$(brew list --cask -1 2>/dev/null | sort -u)

  while IFS= read -r line; do
    case "$line" in
      'brew "'*)
        local name="${line#brew \"}"; name="${name%%\"*}"; name="${name##*/}"
        if grep -qFx "$name" <<<"$formulae"; then ok "formula $name"; else bad "missing formula $name"; fi
        ;;
      'cask "'*)
        local cname="${line#cask \"}"; cname="${cname%%\"*}"
        if grep -qFx "$cname" <<<"$casks"; then ok "cask $cname"; else bad "missing cask $cname"; fi
        ;;
    esac
  done <"$bf"
}

# ── defaults: install/macos/defaults.sh ──────────────────────────────────────
# When you add a new `defaults write`, add the matching read here.
check_defaults() {
  section "defaults (defaults.sh)"
  if [[ "$(defaults read com.apple.finder ShowPathbar 2>/dev/null)" == "1" ]]; then
    ok "Finder ShowPathbar=true"
  else
    bad "Finder ShowPathbar not set"
  fi
}

# ── files: every chezmoi-managed entry is materialized in ~ ──────────────────
check_files() {
  section "managed files"
  command -v chezmoi >/dev/null 2>&1 || { bad "chezmoi not on PATH"; return; }
  local missing=0 rel p
  while IFS= read -r rel; do
    # .chezmoiscripts/ are run-only, no target file is produced.
    [[ "$rel" == .chezmoiscripts/* ]] && continue
    p="$HOME/$rel"
    if [[ ! -e "$p" && ! -L "$p" ]]; then
      bad "missing: $p"
      missing=$((missing + 1))
    fi
  done < <(chezmoi managed 2>/dev/null)
  (( missing == 0 )) && ok "all managed entries exist"
}

# ── secrets: encrypted_* should be plaintext in ~ ────────────────────────────
check_secrets() {
  section "secrets decrypted"
  local f
  for f in "$HOME/.config/fish/conf.d/env.secret.fish" \
           "$HOME/.config/git/config.secret"; do
    if [[ ! -f "$f" ]]; then bad "missing $f"; continue; fi
    if head -c 200 "$f" | grep -qE 'BEGIN AGE|^age-encryption'; then
      bad "$f still appears encrypted"
    else
      ok "plaintext $f"
    fi
  done
}

# ── external: .chezmoiexternal.toml entries fetched ──────────────────────────
check_external() {
  section "externals"
  local d="$HOME/.local/share/tmux/oh-my-tmux"
  [[ -d "$d/.git" ]] && ok "$d is a git checkout" || bad "$d not a git repo"
  [[ -f "$d/.tmux.conf" ]] && ok "oh-my-tmux .tmux.conf present" || bad "oh-my-tmux .tmux.conf missing"
  local link="$HOME/.config/tmux/tmux.conf"
  if [[ -L "$link" ]]; then
    local tgt; tgt=$(readlink "$link")
    [[ "$tgt" == *oh-my-tmux/.tmux.conf ]] && ok "$link -> oh-my-tmux" || bad "wrong symlink target: $tgt"
  else
    bad "$link is not a symlink"
  fi
}

# ── shell: fish env after sourcing config.fish ───────────────────────────────
check_shell() {
  section "fish env"
  command -v fish >/dev/null 2>&1 || { bad "fish not on PATH"; return; }
  local out; out=$(fish -c 'echo "SHELL=$SHELL"; echo "EDITOR=$EDITOR"' 2>&1)
  grep -q 'SHELL=.*fish' <<<"$out" && ok "SHELL points at fish" || bad "SHELL not fish: $out"
  grep -q 'EDITOR=.*nvim' <<<"$out" && ok "EDITOR points at nvim" || bad "EDITOR not nvim: $out"
  for fn in dots dotfiles-check ll keychain-env; do
    if fish -c "functions -q $fn" 2>/dev/null; then ok "fish fn $fn"; else bad "fish fn missing: $fn"; fi
  done
}

# ── dispatcher ───────────────────────────────────────────────────────────────
declare -ar ALL_CHECKS=(brew packages defaults files secrets external shell)

usage() {
  cat <<EOF
Usage: bash tests/smoke.sh [section...]
  (no args)  run every section
  --list     print available sections and exit
  --help     this help

Sections:
  ${ALL_CHECKS[*]}

Add new defaults? edit check_defaults() and add a matching 'defaults read'.
Add new section? define check_<name>() and append <name> to ALL_CHECKS.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --list)    printf '%s\n' "${ALL_CHECKS[@]}"; exit 0 ;;
esac

if [[ $# -eq 0 ]]; then
  to_run=("${ALL_CHECKS[@]}")
else
  to_run=("$@")
fi

for c in "${to_run[@]}"; do
  if ! declare -F "check_$c" >/dev/null; then
    bad "unknown section: $c"
    continue
  fi
  "check_$c"
done

echo
if (( fail > 0 )); then
  echo "✗ $fail check(s) failed"
  exit 1
fi
echo "✓ all checks passed"
