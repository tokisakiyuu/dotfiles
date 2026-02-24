#!/usr/bin/env bash

declare -r DOTFILES_REPO_URL="https://github.com/shunk031/dotfiles"

sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin
local chezmoi_cmd="${bin_dir}/chezmoi"

"${chezmoi_cmd}" init "${DOTFILES_REPO_URL}" \
  --force \
  --use-builtin-git true

rm -fv "${chezmoi_cmd}"
