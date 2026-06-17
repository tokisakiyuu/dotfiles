#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

# Arch Linux ARM package setup. Three sources, by responsibility:
#   1. pacman — system-level pieces brew-on-Linux can't manage: the docker
#      daemon + its systemd units, buildx/compose plugins.
#   2. brew   — every daily-driver CLI tool, from Brewfile.linux (glibc host,
#      so the arm64_linux bottles install cleanly — same flow as macOS).
#   3. claude-code — Anthropic's native installer; the Homebrew formula is a
#      cask (macOS-only) so brew can't deliver it on Linux.

# pacman packages. Kept minimal — anything that also ships as a brew bottle
# lives in Brewfile.linux instead, to mirror the macOS setup.
readonly PACMAN_PACKAGES=(
  docker
  docker-buildx
  docker-compose
)

# Anthropic native install script. Auto-updates in the background and drops the
# binary at ~/.local/bin/claude (added to PATH in config.fish).
# Docs: https://code.claude.com/docs/en/setup
readonly CLAUDE_CODE_INSTALL_URL="https://claude.ai/install.sh"

function require_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not found; install it first and add yourself to the wheel group." >&2
    exit 1
  fi
}

function load_brew_env() {
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
}

function require_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "brew not found at /home/linuxbrew/.linuxbrew; install Homebrew on Linux first." >&2
    exit 1
  fi
}

function install_pacman_packages() {
  # `--needed` skips already-installed packages, making re-runs a no-op.
  # We intentionally do NOT pass -y: a `pacman -Sy <pkg>` partial sync can
  # break an Arch system (Arch wiki: System maintenance / Partial upgrades).
  # The package DBs are already populated on a fresh Arch install; run a full
  # `pacman -Syu` yourself if pacman reports a target as not found.
  sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
}

function install_brew_packages() {
  # --no-upgrade keeps the run idempotent: already-installed formulae are not
  # touched, so re-running this script is cheap and safe.
  brew bundle install --no-upgrade --file="${HOME}/.config/brew/Brewfile.linux"
}

function install_claude_code() {
  if command -v claude >/dev/null 2>&1; then
    return 0
  fi
  curl -fsSL "$CLAUDE_CODE_INSTALL_URL" | bash
}

function main() {
  require_sudo
  load_brew_env
  require_brew
  install_pacman_packages
  install_brew_packages
  install_claude_code
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
