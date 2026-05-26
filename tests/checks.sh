# shellcheck shell=bash
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
        name="${line#"$kind" \"}"
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

# check_protected_paths
#   pass if every entry in chezmoi's `protected_paths` data exists AND has
#   the macOS uchg flag set. Only checks the top-level path; if a directory
#   was chflags -R uchg'd, the directory itself carries the flag.
check_protected_paths() {
  local raw path flags failed=0
  while IFS= read -r raw; do
    [[ -z "$raw" ]] && continue
    path="${raw/#\~/$HOME}"
    if [[ ! -e "$path" ]]; then
      # Same policy as the apply-time script: paths that don't exist yet
      # are skipped, not failed. Once they exist, the next apply will
      # protect them and the next audit will verify it.
      echo "skip (missing): $path" >&2
      continue
    fi
    flags=$(stat -f '%Sf' "$path" 2>/dev/null)
    if [[ "$flags" != *uchg* ]]; then
      echo "$path is not uchg-locked (flags='$flags')" >&2
      failed=$((failed + 1))
    fi
  done < <(chezmoi data | yq -p=json -r '.protected_paths[]?')
  (( failed == 0 ))
}

# check_github_auth
#   pass if git's credential helper can produce a github.com credential AND
#   that credential actually authenticates against the GitHub API.
check_github_auth() {
  local resp username token http_code
  resp=$(printf 'protocol=https\nhost=github.com\n\n' \
         | GIT_TERMINAL_PROMPT=0 git credential fill 2>/dev/null) || {
    echo "git credential helper produced no credential for github.com" >&2
    return 1
  }
  username=$(awk -F= '/^username=/{print $2}' <<<"$resp")
  token=$(awk -F= '/^password=/{print $2}' <<<"$resp")
  [[ -n "$username" && -n "$token" ]] || {
    echo "credential helper returned empty username/password" >&2
    return 1
  }
  http_code=$(curl -s -o /dev/null -w '%{http_code}' \
              --max-time 5 \
              -u "$username:$token" \
              https://api.github.com/user)
  if [[ "$http_code" != "200" ]]; then
    echo "GitHub API rejected the credential (HTTP $http_code)" >&2
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
