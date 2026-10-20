#!/bin/bash
# Install the gaming launchers Mac Gaming Helper can open.
#
# Honest behaviour:
#   - Heroic is installed with the real Homebrew cask (or the official DMG).
#   - Steam is optional because the Homebrew cask is Intel-only and needs Rosetta.
#   - GeForce NOW is optional and installed with its Homebrew cask when requested.
#
# Usage:
#   ./scripts/install-gaming-launchers.sh              # Heroic only (recommended)
#   ./scripts/install-gaming-launchers.sh --steam      # Heroic + Steam
#   ./scripts/install-gaming-launchers.sh --geforce    # Heroic + GeForce NOW
#   ./scripts/install-gaming-launchers.sh --all        # all three
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
want_steam=0
want_geforce=0

for arg in "$@"; do
  case "$arg" in
    --steam) want_steam=1 ;;
    --geforce) want_geforce=1 ;;
    --all) want_steam=1; want_geforce=1 ;;
    -h|--help)
      sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

valid_app() {
  local app="$1"
  [[ -d "$app" ]] || return 1
  [[ -f "$app/Contents/Info.plist" ]] || return 1
  local exe
  exe="$(/usr/bin/defaults read "$app/Contents/Info.plist" CFBundleExecutable 2>/dev/null || true)"
  [[ -n "$exe" && -x "$app/Contents/MacOS/$exe" ]]
}

echo "Mac Gaming Helper — launcher setup"
echo ""

# 1. Heroic — always installed/verified.
"$root/scripts/install-heroic.sh"

# 2. Optional launchers.
install_cask_if_missing() {
  local cask="$1" app="$2" name="$3"
  if valid_app "/Applications/$app"; then
    echo "==> $name is already installed."
    return
  fi
  if ! command -v brew >/dev/null 2>&1; then
    echo "warning: Homebrew not found — install $name manually from its website." >&2
    return
  fi
  echo "==> Installing $name with Homebrew (cask)..."
  HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask "$cask" || {
    echo "warning: could not install $name automatically." >&2
    return
  }
  valid_app "/Applications/$app" || echo "warning: $name installed but the app bundle did not validate." >&2
}

ensure_rosetta() {
  if /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    echo "==> Rosetta 2 is available."
    return 0
  fi
  echo "==> Installing Rosetta 2 (required by Steam's Intel build)..."
  if softwareupdate --install-rosetta --agree-to-license; then
    echo "==> Rosetta 2 installed."
    return 0
  fi
  echo "warning: Rosetta 2 could not be installed automatically." >&2
  echo "         Run: softwareupdate --install-rosetta --agree-to-license" >&2
  return 1
}

if [[ $want_steam -eq 1 ]]; then
  ensure_rosetta && install_cask_if_missing steam "Steam.app" "Steam"
fi

if [[ $want_geforce -eq 1 ]]; then
  install_cask_if_missing nvidia-geforce-now "GeForceNOW.app" "GeForce NOW"
fi

echo ""
echo "Launcher status"
for app in \
  "/Applications/Heroic.app" \
  "/Applications/Steam.app" \
  "/Applications/GeForceNOW.app"
do
  if valid_app "$app"; then
    echo "  ✅ $app"
  elif [[ -e "$app" ]]; then
    echo "  ⚠️  $app exists but is not a valid app bundle (failed download?)"
  else
    echo "  —  $app not installed (optional)"
  fi
done

echo ""
echo "Open Mac Gaming Helper → Launchers to start any installed launcher."
echo "Re-run this script any time; it is safe to repeat."
