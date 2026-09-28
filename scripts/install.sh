#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
"$root/scripts/build.sh"
target="$HOME/Applications/Mac Gaming Helper.app"
mkdir -p "$HOME/Applications"
rm -rf "$target"
cp -R "$root/dist/Mac Gaming Helper.app" "$target"
xattr -cr "$target" || true
codesign --force --sign - "$target"
# Desktop shortcut for easy discovery (symlink, does not replace Game Bay)
desk="$HOME/Desktop/Mac Gaming Helper.app"
rm -f "$desk"
ln -s "$target" "$desk"
echo "installed $target"
echo "desktop link $desk"
echo "source remains at $root (Game Bay untouched at $HOME/Projects/game-bay)"
