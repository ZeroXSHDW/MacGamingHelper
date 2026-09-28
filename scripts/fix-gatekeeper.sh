#!/bin/bash
# Strip quarantine so double-click / open works for ad-hoc Mac Gaming Helper.
set -euo pipefail
APP="/Applications/Mac Gaming Helper.app"
if [[ ! -d "$APP" ]]; then
  APP="$HOME/Applications/Mac Gaming Helper.app"
fi
if [[ ! -d "$APP" ]]; then
  echo "Mac Gaming Helper.app not found. Run scripts/install.sh first."
  exit 1
fi
echo "Clearing quarantine on: $APP"
xattr -cr "$APP" || true
find "$APP" -exec xattr -d com.apple.quarantine {} \; 2>/dev/null || true
echo "Done. Opening…"
open -a "$APP"
echo "If macOS still blocks: Right-click the app → Open → Open."
