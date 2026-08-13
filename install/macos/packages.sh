#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

function load_brew_env() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

function require_brew() {
  if ! command -v brew &>/dev/null; then
    echo "brew not found; run install/macos/brew.sh first." >&2
    exit 1
  fi
}

function load_node_env() {
  # node@24 is keg-only, so `brew shellenv` leaves it off PATH — but the
  # Brewfile's `npm "corepack"` entry shells out to npm and would abort the run.
  # Seeding the path up front works even on a fresh machine: the directory
  # appears mid-run once `brew bundle` installs the formula, and PATH is
  # consulted at each lookup.
  local prefix
  prefix="$(brew --prefix)"
  export PATH="${prefix}/opt/node@24/bin:${PATH}"
}

function install_packages() {
  # --no-upgrade keeps the run idempotent: already-installed formulae are
  # not touched, so re-running this script is cheap and safe.
  brew bundle install --no-upgrade --file="${HOME}/.config/brew/Brewfile"
}

function main() {
  load_brew_env
  require_brew
  load_node_env
  install_packages
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
