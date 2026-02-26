#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

readonly TMUX_PLUGINS_DIR="${HOME%/}/.config/tmux/plugins"
readonly TPM_DIR="${TMUX_PLUGINS_DIR}/tpm"

function clone_tpm() {
  local dir="$1"
  local url="https://github.com/tmux-plugins/tpm"

  if [ ! -d "${dir}" ]; then
    git clone "${url}" "${dir}"
  fi
}

function install_tpm_plugins() {
  local cmd="${TPM_DIR}/scripts/install_plugins.sh"

  "${cmd}"
}

function install_tpm() {
  export TMUX_PLUGIN_MANAGER_PATH="${TMUX_PLUGINS_DIR}"

  if [ ! "${DOTFILES_DEBUG:-}" ] || [ ! -d "${TPM_DIR}" ]; then
    clone_tpm "${TPM_DIR}"
    install_tpm_plugins
  fi
}

function uninstall_tpm() {
  rm -rfv "${TPM_DIR}"
}

function main() {
  install_tpm
  install_tpm_plugins
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
