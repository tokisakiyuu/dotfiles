# Helper functions for tests/audit.yaml `cmd:` snippets.
# Sourced by tests/audit.sh; every check_* function is auto-exported so the
# bash subshells that run `cmd:` can call them.
#
# To add a helper: define `check_<something>` here, then call it from a
# `cmd:` in audit.yaml. Failing helpers should print diagnostics to stderr
# and `return 1`.

# check_brewfile <formula|cask>
#   pass if every formula/cask declared in ~/.config/brew/Brewfile is currently installed
check_brewfile() {
  local kind=$1 bf installed line name
  bf="$HOME/.config/brew/Brewfile"
  [[ -f "$bf" ]] || { echo "Brewfile not found at $bf" >&2; return 1; }
  installed=$(brew list "--$kind" -1 2>/dev/null | sort -u)
  while IFS= read -r line; do
    case "$line" in
      "$kind \""*)
        name="${line#$kind \"}"
        name="${name%%\"*}"
        name="${name##*/}"
        grep -qFx "$name" <<<"$installed" || { echo "missing $kind: $name" >&2; return 1; }
        ;;
    esac
  done <"$bf"
}

# check_plaintext <path>
#   pass if the file exists and doesn't look like age ciphertext
check_plaintext() {
  local f=$1
  [[ -f "$f" ]] || { echo "missing: $f" >&2; return 1; }
  if head -c 200 "$f" | grep -qE 'BEGIN AGE|^age-encryption'; then
    echo "$f appears to still be encrypted" >&2
    return 1
  fi
}

# check_managed_files
#   pass if every chezmoi-managed entry exists at its target path
check_managed_files() {
  local rel p missing=0
  while IFS= read -r rel; do
    [[ "$rel" == .chezmoiscripts/* ]] && continue
    p="$HOME/$rel"
    if [[ ! -e "$p" && ! -L "$p" ]]; then
      echo "missing: $p" >&2
      missing=$((missing + 1))
    fi
  done < <(chezmoi managed 2>/dev/null)
  (( missing == 0 ))
}
