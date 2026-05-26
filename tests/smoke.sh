#!/usr/bin/env bash
#
# Verify that the run_once_* installer scripts actually achieved what they
# set out to do.
#
# Runs in CI after `chezmoi apply`, or locally:
#   bash tests/smoke.sh

set -Eeuo pipefail

fail=0
ok()  { printf '  ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1" >&2; fail=$((fail + 1)); }

echo "── brew.sh ──"
if command -v brew >/dev/null 2>&1; then
  ok "brew on PATH"
else
  bad "brew not on PATH"
fi
if [[ "$(brew analytics state 2>/dev/null)" == *disabled* ]]; then
  ok "brew analytics disabled"
else
  bad "brew analytics not disabled"
fi

echo
echo "── packages.sh (sample of Brewfile formulae) ──"
for pkg in fish git neovim tmux starship zoxide chezmoi; do
  if brew list --formula --quiet 2>/dev/null | grep -qFx "$pkg"; then
    ok "formula $pkg installed"
  else
    bad "formula $pkg not installed"
  fi
done

echo
echo "── defaults.sh ──"
if [[ "$(defaults read com.apple.finder ShowPathbar 2>/dev/null)" == "1" ]]; then
  ok "Finder ShowPathbar=true"
else
  bad "Finder ShowPathbar not set"
fi

echo
if (( fail > 0 )); then
  echo "✗ $fail check(s) failed"
  exit 1
fi
echo "✓ all installer scripts landed"
