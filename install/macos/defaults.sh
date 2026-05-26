#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

# ~/.macos — https://mths.be/macos

# Close any open Settings panes to prevent them from overriding our writes.
# The app was renamed in macOS 13; try both, ignore failures.
osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true
osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true

###############################################################################
# Finder.app                                                                  #
###############################################################################

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

###############################################################################
# Finished                                                                    #
###############################################################################

echo "Done. Note that some of these changes require a logout/restart to take effect."
