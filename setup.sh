#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

readonly DOTFILES_REPO_URL="https://github.com/tokisakiyuu/dotfiles"
readonly BIN_DIR="${HOME}/.local/bin"
readonly CHEZMOI_CMD="${BIN_DIR}/chezmoi"

sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${BIN_DIR}"

"${CHEZMOI_CMD}" init "${DOTFILES_REPO_URL}" \
  --force \
  --use-builtin-git true

rm -fv "${CHEZMOI_CMD}"
