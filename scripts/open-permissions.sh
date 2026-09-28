#!/bin/bash
# Opens System Settings panes Michael should enable for Mac Gaming Helper.
# TCC cannot be granted from the command line — flip each toggle ON for the app.
set -euo pipefail

echo "=== Mac Gaming Helper — permissions to enable ==="
echo "1) Bluetooth (Privacy) — pad discovery"
echo "2) Accessibility — Mapping (keyboard/mouse)"
echo "3) Notifications — low-battery alerts"
echo "4) Local Network — optional, if Ping metric fails"
echo "5) Automation — if prompted for Steam / System Events"
echo "Then: open the app → menu bar → Show Performance Bar (or ⌃⌥⌘P)"
echo

open_url() {
  open "$1" 2>/dev/null || true
  sleep 0.8
}

open_url "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
open_url "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
open_url "x-apple.systempreferences:com.apple.preference.notifications"
open_url "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork"

APP="/Applications/Mac Gaming Helper.app"
if [[ ! -d "$APP" ]]; then
  APP="$HOME/Applications/Mac Gaming Helper.app"
fi
if [[ -d "$APP" ]]; then
  echo "Opening app: $APP"
  open "$APP"
else
  echo "App not found in /Applications or ~/Applications — run scripts/install.sh first."
fi
