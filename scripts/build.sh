#!/bin/bash
# Build an ad-hoc signed Mac Gaming Helper.app into dist/.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

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
mkdir -p "$stage/Contents/MacOS" "$stage/Contents/Resources" "$root/build" "$root/Resources"

# Generate stylized PNGs into Resources/
swiftc -sdk "$sdk" -target arm64-apple-macosx14.0 -framework AppKit \
  -o "$root/build/make-assets" "$root/scripts/make-assets.swift"
"$root/build/make-assets" "$root/Resources"

# Marketing copies for README (optional, regenerated each build)
mkdir -p "$root/docs/screenshots"
cp -f "$root/Resources/banner.png" "$root/docs/screenshots/banner.png"
cp -f "$root/Resources/hero-pad-lit.png" "$root/docs/screenshots/controller-hero.png"
cp -f "$root/Resources/coach-usb.png" "$root/docs/screenshots/pairing-usb.png"
cp -f "$root/Resources/coach-bluetooth.png" "$root/docs/screenshots/pairing-bluetooth.png"

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
  <string>3.4.0</string>
  <key>CFBundleVersion</key>
  <string>11</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.games</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>Mac Gaming Helper looks for a DualShock 4 or DualSense paired or advertising over Bluetooth so the Performance Bar and Controller desk can show live pad status.</string>
  <key>NSBluetoothPeripheralUsageDescription</key>
  <string>Mac Gaming Helper uses Bluetooth to find and reconnect DualShock 4 / DualSense controllers.</string>
  <key>NSLocalNetworkUsageDescription</key>
  <string>Mac Gaming Helper measures optional network latency (Ping) for the Gaming Performance Bar. Disable Ping in Settings if you prefer not to allow this.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Mac Gaming Helper may open Steam Big Picture and System Settings for controller setup and permissions.</string>
  <key>NSUserNotificationsUsageDescription</key>
  <string>Mac Gaming Helper can notify you when controller battery is low during a gaming session.</string>
</dict>
</plist>
PLIST
printf 'APPL????' > "$stage/Contents/PkgInfo"

# Richer app icon from AppIcon-1024.png
swiftc -sdk "$sdk" -target arm64-apple-macosx14.0 -framework AppKit \
  -o "$root/build/make-icon" "$root/scripts/make-icon.swift"
"$root/build/make-icon" "$root/build/AppIcon.iconset" "$root/Resources/AppIcon-1024.png"
iconutil -c icns "$root/build/AppIcon.iconset" -o "$stage/Contents/Resources/AppIcon.icns"

# Bundle UI PNGs (exclude master icon source from runtime needs but include is fine)
cp -f "$root/Resources/"*.png "$stage/Contents/Resources/"

sources=("$root"/Sources/*.swift)
swiftc -parse-as-library -O -sdk "$sdk" -target arm64-apple-macosx14.0 \
  -framework SwiftUI -framework AppKit -framework GameController -framework CoreHaptics \
  -framework ServiceManagement -framework UserNotifications -framework IOKit \
  -o "$stage/Contents/MacOS/MacGamingHelper" \
  "${sources[@]}"
codesign --force --sign - --entitlements "$root/scripts/entitlements.plist" "$stage" 2>/dev/null \
  || codesign --force --sign - "$stage"
echo "built $stage"
echo "resources: $(ls "$stage/Contents/Resources" | wc -l | tr -d ' ') files"
