#!/bin/bash
# Install or repair Heroic Games Launcher on macOS (Apple silicon or Intel).
#
# Why this script exists: the old install-gaming-launchers.sh used
#   brew install --formula heroic
# which does not exist. A failed download can also leave an HTML error page
# named "Heroic-Games-Launcher.app" in /Applications, which looks installed in
# Finder but never opens.
#
# Usage:
#   ./scripts/install-heroic.sh            # Homebrew first, DMG fallback
#   ./scripts/install-heroic.sh --dmg      # skip Homebrew, use official DMG
#   ./scripts/install-heroic.sh --force    # reinstall even if valid
set -euo pipefail

APP_NAME="Heroic.app"
TARGET="/Applications/$APP_NAME"
FORCE=0
USE_DMG=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --dmg) USE_DMG=1 ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

say() { echo "==> $*"; }
warn() { echo "warning: $*" >&2; }

trash_path() {
  local path="$1"
  mkdir -p "$HOME/.Trash"
  local dest="$HOME/.Trash/$(basename "$path").broken-$(date +%Y%m%d-%H%M%S)"
  mv "$path" "$dest" 2>/dev/null && say "Moved broken artifact to $dest" || rm -rf "$path"
}

# A real .app is a directory with an Info.plist and a launchable executable.
valid_app() {
  local app="$1"
  [[ -d "$app" ]] || return 1
  [[ -f "$app/Contents/Info.plist" ]] || return 1
  /usr/bin/plutil -lint "$app/Contents/Info.plist" >/dev/null 2>&1 || return 1
  local exe
  exe="$(/usr/bin/defaults read "$app/Contents/Info.plist" CFBundleExecutable 2>/dev/null || true)"
  [[ -n "$exe" && -x "$app/Contents/MacOS/$exe" ]]
}

# Remove fake / half-downloaded bundles that shadow a good install.
clean_broken() {
  local candidate
  for candidate in \
    "$TARGET" \
    "/Applications/Heroic-Games-Launcher.app" \
    "/Applications/Heroic Games Launcher.app" \
    "$HOME/Applications/Heroic.app" \
    "$HOME/Applications/Heroic-Games-Launcher.app"
  do
    if [[ -e "$candidate" ]] && ! valid_app "$candidate"; then
      warn "not a valid app bundle: $candidate"
      trash_path "$candidate"
    fi
  done
}

clean_broken

if [[ $FORCE -eq 0 ]] && valid_app "$TARGET"; then
  version="$(/usr/bin/defaults read "$TARGET/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo unknown)"
  say "Heroic is already installed at $TARGET (version $version)."
  say "Use --force to reinstall."
  exit 0
fi

if [[ $FORCE -eq 1 && -e "$TARGET" ]]; then
  rm -rf "$TARGET"
fi

installed=0

if [[ $USE_DMG -eq 0 ]] && command -v brew >/dev/null 2>&1; then
  say "Installing Heroic with Homebrew (cask)..."
  # HOMEBREW_NO_AUTO_UPDATE keeps this fast; the cask is notarized upstream.
  if HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask heroic; then
    # Homebrew may report "already installed" while the app is missing.
    if ! valid_app "$TARGET"; then
      warn "Homebrew reported success but $TARGET is missing; trying the official DMG."
      HOMEBREW_NO_AUTO_UPDATE=1 brew reinstall --cask heroic >/dev/null 2>&1 || true
    fi
    valid_app "$TARGET" && installed=1
  else
    warn "Homebrew cask install failed; falling back to the official DMG."
  fi
fi

if [[ $installed -eq 0 ]]; then
  command -v curl >/dev/null 2>&1 || { echo "curl is required for the DMG fallback." >&2; exit 1; }
  command -v python3 >/dev/null 2>&1 || { echo "python3 is required for the DMG fallback." >&2; exit 1; }

  arch="$(uname -m)"
  if [[ "$arch" == "arm64" ]]; then
    asset_re='macOS-arm64\.dmg$'
    label="arm64"
  else
    asset_re='macOS-x64\.dmg$'
    label="x64"
  fi

  say "Finding the latest official Heroic release ($label)..."
  url="$(curl -fsSL --retry 3 --max-time 60 \
    https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest \
    | python3 -c 'import json,re,sys
pattern = re.compile(sys.argv[1])
data = json.load(sys.stdin)
for asset in data.get("assets", []):
    if pattern.search(asset.get("name", "")):
        print(asset["browser_download_url"])
        break
' "$asset_re")"

  if [[ -z "${url:-}" ]]; then
    echo "Could not find a macOS $label DMG in the latest Heroic release." >&2
    echo "Download manually from https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest" >&2
    exit 1
  fi

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/heroic-install.XXXXXX")"
  mountpoint=""
  cleanup() {
    [[ -n "$mountpoint" && -d "$mountpoint" ]] && hdiutil detach "$mountpoint" -quiet >/dev/null 2>&1 || true
    rm -rf "$tmp"
  }
  trap cleanup EXIT

  dmg="$tmp/Heroic.dmg"
  say "Downloading $(basename "$url")..."
  curl -fL --retry 3 --progress-bar "$url" -o "$dmg"

  if ! file "$dmg" | grep -qi "disk image"; then
    echo "Downloaded file is not a disk image — refusing to install." >&2
    exit 1
  fi

  say "Verifying code signature..."
  hdiutil verify "$dmg" >/dev/null

  say "Mounting DMG..."
  mountpoint="$(hdiutil attach "$dmg" -nobrowse -readonly | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/"))}' | tail -1)"
  if [[ -z "$mountpoint" || ! -d "$mountpoint" ]]; then
    echo "Could not mount the Heroic DMG." >&2
    exit 1
  fi

  src_app="$(find "$mountpoint" -maxdepth 2 -name "*.app" -type d | head -1)"
  if [[ -z "$src_app" ]]; then
    echo "No .app found inside the Heroic DMG." >&2
    exit 1
  fi

  say "Installing to $TARGET..."
  rm -rf "$TARGET"
  ditto "$src_app" "$TARGET"
  xattr -cr "$TARGET" 2>/dev/null || true
  hdiutil detach "$mountpoint" -quiet >/dev/null 2>&1 || true
  mountpoint=""

  valid_app "$TARGET" || { echo "Install validation failed for $TARGET." >&2; exit 1; }
  installed=1
fi

if [[ $installed -ne 1 ]]; then
  echo "Heroic installation failed." >&2
  exit 1
fi

xattr -cr "$TARGET" 2>/dev/null || true
version="$(/usr/bin/defaults read "$TARGET/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo unknown)"
say "Installed Heroic $version at $TARGET"
codesign --verify --deep --strict "$TARGET" 2>/dev/null && say "Code signature verified." || warn "Code signature check did not pass."
spctl --assess --type execute "$TARGET" >/dev/null 2>&1 && say "Gatekeeper accepts the app." || warn "Gatekeeper assessment failed; right-click → Open may be needed."

say "Done. Open Heroic from /Applications, or use the Launchers page in Mac Gaming Helper."
