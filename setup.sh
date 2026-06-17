#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

readonly DOTFILES_REPO_URL="https://github.com/tokisakiyuu/dotfiles"
readonly BIN_DIR="${HOME}/.local/bin"
readonly BOOTSTRAP_CHEZMOI="${BIN_DIR}/chezmoi"
readonly CHEZMOI_SOURCE="${HOME}/.local/share/chezmoi"
readonly AGE_KEY="${HOME}/.config/chezmoi/age-key.txt"

# Resolve a usable chezmoi: prefer a package-manager copy on PATH (brew on
# macOS and Arch Linux), fall back to a throwaway binary fetched from
# get.chezmoi.io. We only delete the throwaway later if a real one shows up.
bootstrapped=0
if command -v chezmoi >/dev/null 2>&1; then
  chezmoi_bin=$(command -v chezmoi)
else
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${BIN_DIR}"
  chezmoi_bin="${BOOTSTRAP_CHEZMOI}"
  bootstrapped=1
fi

# `chezmoi init` is one-shot; skip when the source tree already exists so this
# script remains safe to re-run on a partially-set-up host (e.g. one where the
# previous run installed the source but never reached `apply`).
if [ ! -d "${CHEZMOI_SOURCE}/.git" ]; then
  "${chezmoi_bin}" init --use-builtin-git=true "${DOTFILES_REPO_URL}"
else
  echo "chezmoi source already exists at ${CHEZMOI_SOURCE}; skipping init."
fi

# Warn (don't abort) when the age key is missing. `chezmoi apply` will still
# work for non-encrypted files; the missing key only matters when an encrypted
# entry is reached.
if [ ! -f "${AGE_KEY}" ]; then
  cat >&2 <<EOF
warning: age private key not found at ${AGE_KEY}
         encrypted files (env.secret.fish, git config.secret, ...) will fail to decrypt.
         drop the key there with chmod 600 and re-run this script, or just 'chezmoi apply'.
EOF
fi

# `apply` is the step that actually installs everything (brew on macOS; pacman
# + brew on Arch) including a package-manager copy of chezmoi. Without it the
# throwaway binary would be the only chezmoi on disk, and the cleanup below
# would leave the host with no chezmoi at all.
"${chezmoi_bin}" apply

# Retire the throwaway only when a package-manager copy is now on PATH;
# otherwise leave it so the user still has a working chezmoi.
if (( bootstrapped )); then
  resolved=$(command -v chezmoi || true)
  if [[ -n "$resolved" && "$resolved" != "${BOOTSTRAP_CHEZMOI}" ]]; then
    rm -fv "${BOOTSTRAP_CHEZMOI}"
  fi
fi
