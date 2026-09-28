#!/bin/bash
# Double-click to open Mac Gaming Helper (/Applications build) with Start-gaming defaults.
set -euo pipefail
APP="/Applications/Mac Gaming Helper.app"
if [[ ! -d "$APP" ]]; then
  APP="$HOME/Applications/Mac Gaming Helper.app"
fi
if [[ ! -d "$APP" ]]; then
  osascript -e 'display alert "Mac Gaming Helper not installed" message "Run scripts/install.sh from the project, or download the latest release zip into /Applications."'
  exit 1
fi

# Prefer /Applications when both exist
if [[ -d "/Applications/Mac Gaming Helper.app" ]]; then
  APP="/Applications/Mac Gaming Helper.app"
fi

xattr -cr "$APP" 2>/dev/null || true

DOMAIN="com.zeroxshdw.mac-gaming-helper"
defaults write "$DOMAIN" settings.showOverlay -bool true
defaults write "$DOMAIN" settings.overlayMode -string performance
defaults write "$DOMAIN" settings.overlayEdge -string top
defaults write "$DOMAIN" settings.showMenuBar -bool true
defaults write "$DOMAIN" settings.gamingSessionActive -bool true
defaults write "$DOMAIN" settings.metricController -bool true
defaults write "$DOMAIN" settings.metricCPU -bool true
defaults write "$DOMAIN" settings.metricMemory -bool true
defaults write "$DOMAIN" settings.metricGPU -bool true
defaults write "$DOMAIN" settings.metricPanel -bool true
defaults write "$DOMAIN" settings.metricPing -bool true
defaults write "$DOMAIN" settings.metricMapping -bool true
defaults write "$DOMAIN" settings.metricAwake -bool true
defaults write "$DOMAIN" settings.pingEnabled -bool true

# Open by path so we always hit this build (not a stale Launch Services match)
open "$APP"
