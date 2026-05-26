#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

readonly DOTFILES_REPO_URL="https://github.com/tokisakiyuu/dotfiles"
readonly BIN_DIR="${HOME}/.local/bin"
readonly BOOTSTRAP_CHEZMOI="${BIN_DIR}/chezmoi"
readonly CHEZMOI_SOURCE="${HOME}/.local/share/chezmoi"

# Idempotency: once the source tree exists, this script is a no-op. Daily
# refreshes go through `chezmoi update`; re-running setup.sh must never
# clobber a working tree that may hold uncommitted changes.
if [ -d "${CHEZMOI_SOURCE}/.git" ]; then
  echo "chezmoi source already exists at ${CHEZMOI_SOURCE}."
  echo "Use 'chezmoi update' to pull and apply remote changes."
  exit 0
fi

# Reuse an existing chezmoi if one is on PATH (e.g. brew-installed already),
# otherwise drop a throwaway binary just for the bootstrap.
if command -v chezmoi >/dev/null 2>&1; then
  chezmoi init --use-builtin-git=true "${DOTFILES_REPO_URL}"
else
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${BIN_DIR}"
  "${BOOTSTRAP_CHEZMOI}" init --use-builtin-git=true "${DOTFILES_REPO_URL}"
  rm -fv "${BOOTSTRAP_CHEZMOI}"
fi
