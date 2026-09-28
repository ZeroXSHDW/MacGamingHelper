#!/bin/bash
# Build an ad-hoc signed Mac Gaming Helper.app into dist/.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

# Prefer SDKs that match the installed swiftc. MacOSX27.sdk currently requires
# Swift 6.4; Command Line Tools on this Mac ship 6.3.x — use 26.x / 15.x.
pick_sdk() {
  local candidate
  for candidate in \
    /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
    /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk \
    /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
    /Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk \
    /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
  do
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  # Only use 27.x if nothing else exists (may need a matching toolchain).
  for candidate in \
    /Library/Developer/CommandLineTools/SDKs/MacOSX27.sdk \
    /Library/Developer/CommandLineTools/SDKs/MacOSX27.0.sdk
  do
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  xcrun --sdk macosx --show-sdk-path 2>/dev/null || true
}

sdk="$(pick_sdk)"
if [[ -z "$sdk" || ! -d "$sdk" ]]; then
  echo "No compatible macOS SDK found. Install Xcode Command Line Tools." >&2
  exit 1
fi
echo "sdk $sdk"
stage="$root/dist/Mac Gaming Helper.app"
rm -rf "$stage"
mkdir -p "$stage/Contents/MacOS" "$stage/Contents/Resources" "$root/build"
cat > "$stage/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>MacGamingHelper</string>
  <key>CFBundleIdentifier</key>
  <string>com.zeroxshdw.mac-gaming-helper</string>
  <key>CFBundleName</key>
  <string>Mac Gaming Helper</string>
  <key>CFBundleDisplayName</key>
  <string>Mac Gaming Helper</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>2.1.0</string>
  <key>CFBundleVersion</key>
  <string>3</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.games</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>Mac Gaming Helper looks for a DualShock 4 or DualSense paired or advertising over Bluetooth.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Mac Gaming Helper may open Steam Big Picture and System Settings for controller setup.</string>
</dict>
</plist>
PLIST
printf 'APPL????' > "$stage/Contents/PkgInfo"
swiftc -sdk "$sdk" -target arm64-apple-macosx14.0 -framework AppKit \
  -o "$root/build/make-icon" "$root/scripts/make-icon.swift"
"$root/build/make-icon" "$root/build/AppIcon.iconset"
iconutil -c icns "$root/build/AppIcon.iconset" -o "$stage/Contents/Resources/AppIcon.icns"
sources=("$root"/Sources/*.swift)
swiftc -parse-as-library -O -sdk "$sdk" -target arm64-apple-macosx14.0 \
  -framework SwiftUI -framework AppKit -framework GameController -framework CoreHaptics \
  -o "$stage/Contents/MacOS/MacGamingHelper" \
  "${sources[@]}"
codesign --force --sign - --entitlements "$root/scripts/entitlements.plist" "$stage" 2>/dev/null \
  || codesign --force --sign - "$stage"
echo "built $stage"
