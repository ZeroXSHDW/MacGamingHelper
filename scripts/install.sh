#!/bin/bash
# Install Mac Gaming Helper into /Applications (fallback ~/Applications).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/scripts/build.sh"

src="$root/dist/Mac Gaming Helper.app"
app_name="Mac Gaming Helper.app"
entitlements="$root/scripts/entitlements.plist"

valid_app() {
  local app="$1"
  [[ -d "$app" ]] || return 1
  [[ -f "$app/Contents/Info.plist" ]] || return 1
  /usr/bin/plutil -lint "$app/Contents/Info.plist" >/dev/null 2>&1 || return 1
  local exe
  exe="$(/usr/bin/defaults read "$app/Contents/Info.plist" CFBundleExecutable 2>/dev/null || true)"
  [[ -n "$exe" && -x "$app/Contents/MacOS/$exe" ]]
}

# Fail early instead of installing a half-built bundle.
if ! valid_app "$src"; then
  echo "Build output is not a valid app bundle: $src" >&2
  exit 1
fi
"$src/Contents/MacOS/MacGamingHelper" --self-test >/dev/null 2>&1 || {
  echo "Built binary failed its self-test; refusing to install." >&2
  exit 1
}

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

# Remove a stale user-level copy when the primary install is in /Applications.
# Two copies confuse LaunchServices and can make an old build open.
if [[ "$target" == /Applications/* && -e "$HOME/Applications/$app_name" ]]; then
  rm -rf "$HOME/Applications/$app_name"
  echo "removed stale mirror $HOME/Applications/$app_name"
fi

desk="$HOME/Desktop/Mac Gaming Helper.app"
rm -f "$desk"
ln -sf "$target" "$desk"

echo "installed $target"
echo "desktop link $desk → $target"

if ! valid_app "$target"; then
  echo "Install validation failed: $target is not a valid app bundle." >&2
  exit 1
fi
"$target/Contents/MacOS/MacGamingHelper" --self-test >/dev/null 2>&1 \
  && echo "self-test: ok" \
  || echo "warning: installed app self-test reported a failure (run --self-test for details)" >&2

# Surface the common failed-launcher download instead of leaving a fake .app.
for launcher_app in "/Applications/Heroic.app" "/Applications/Heroic-Games-Launcher.app" "/Applications/Steam.app"; do
  if [[ -e "$launcher_app" ]] && ! valid_app "$launcher_app"; then
    echo "warning: $launcher_app exists but is not a real app (failed download)." >&2
    echo "         Repair Heroic with: $root/scripts/install-heroic.sh" >&2
  fi
done

if ! [[ -d "/Applications/Heroic.app" ]] && ! [[ -d "$HOME/Applications/Heroic.app" ]]; then
  echo ""
  echo "Heroic is not installed. Install it with:"
  echo "  $root/scripts/install-heroic.sh"
fi

echo "source remains at $root (Game Bay untouched at $HOME/Projects/game-bay)"
if spctl --assess --type execute "$target" >/dev/null 2>&1; then
  echo "gatekeeper: accepted"
else
  # Expected for a locally built, ad-hoc signed app. Not an install failure.
  echo "gatekeeper: ad-hoc build (not notarized). Double-click normally works because quarantine was cleared;"
  echo "            if macOS blocks it, right-click → Open, or run scripts/fix-gatekeeper.sh."
fi
codesign --verify --deep --strict "$target" 2>/dev/null && echo "code signature: verified" || echo "warning: code signature verification failed" >&2
codesign -dv --verbose=2 "$target" 2>&1 | grep -E "Identifier|Format|Signature|TeamIdentifier" | head -6 || true

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
