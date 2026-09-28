#!/bin/bash
# Install Mac Gaming Helper into /Applications (fallback ~/Applications).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/scripts/build.sh"

src="$root/dist/Mac Gaming Helper.app"
app_name="Mac Gaming Helper.app"
entitlements="$root/scripts/entitlements.plist"

pick_target() {
  if [[ -d /Applications ]] && touch /Applications/.mgh_write_test 2>/dev/null; then
    rm -f /Applications/.mgh_write_test
    echo "/Applications/$app_name"
    return
  fi
  mkdir -p "$HOME/Applications"
  echo "$HOME/Applications/$app_name"
}

target="$(pick_target)"
echo "install target: $target"

rm -rf "$target"
# ditto preserves resources/signing bits better than cp -R
ditto "$src" "$target"
xattr -cr "$target" || true
# Strip quarantine explicitly
xattr -d com.apple.quarantine "$target" 2>/dev/null || true
find "$target" -exec xattr -d com.apple.quarantine {} \; 2>/dev/null || true

if [[ -f "$entitlements" ]]; then
  codesign --force --deep --sign - --entitlements "$entitlements" "$target" \
    || codesign --force --sign - --entitlements "$entitlements" "$target"
else
  codesign --force --deep --sign - "$target"
fi

# Also mirror into ~/Applications when primary is /Applications (handy for older shortcuts)
if [[ "$target" == /Applications/* ]]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/$app_name"
  ditto "$target" "$HOME/Applications/$app_name"
  xattr -cr "$HOME/Applications/$app_name" || true
  codesign --force --deep --sign - --entitlements "$entitlements" "$HOME/Applications/$app_name" 2>/dev/null \
    || codesign --force --sign - "$HOME/Applications/$app_name" || true
fi

desk="$HOME/Desktop/Mac Gaming Helper.app"
rm -f "$desk"
ln -sf "$target" "$desk"

echo "installed $target"
echo "desktop link $desk → $target"
echo "source remains at $root (Game Bay untouched at $HOME/Projects/game-bay)"
spctl --assess --type execute -v "$target" 2>&1 || true
codesign -dv --verbose=2 "$target" 2>&1 | head -20 || true

# Desktop double-click launcher
cmd_src="$root/scripts/Start Mac Gaming Helper.command"
cmd_desk="$HOME/Desktop/Start Mac Gaming Helper.command"
if [[ -f "$cmd_src" ]]; then
  cp -f "$cmd_src" "$cmd_desk"
  chmod +x "$cmd_desk"
  echo "desktop launcher $cmd_desk"
fi

echo ""
echo "Easiest run:"
echo "  open -a 'Mac Gaming Helper'"
echo "  or double-click Desktop / Start Mac Gaming Helper.command"
echo "  or: $cmd_desk"
echo "Gatekeeper: $root/scripts/fix-gatekeeper.sh"
