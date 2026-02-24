#!/usr/bin/env bash

# ~/.macos — https://mths.be/macos

# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
osascript -e 'tell application "System Preferences" to quit'

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `.macos` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &


###############################################################################
# Finder.app                                                                  #
###############################################################################

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true


###############################################################################
# Hammerspoon.app                                                             #
###############################################################################

# Hammerspoon: set script entry point
defaults write org.hammerspoon.Hammerspoon MJConfigFile "~/.config/hammerspoon/init.lua"

###############################################################################
# Finished                                                                    #
###############################################################################

echo "Done. Note that some of these changes require a logout/restart to take effect."
