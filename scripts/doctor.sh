#!/bin/bash
# Health check for Mac Gaming Helper and its launchers.
# Read-only: reports problems and the exact command to fix each one.
#
# Usage: ./scripts/doctor.sh
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
issues=0
warnings=0

ok()   { printf '  ✅ %s\n' "$*"; }
warn() { printf '  ⚠️  %s\n' "$*"; warnings=$((warnings + 1)); }
bad()  { printf '  ❌ %s\n' "$*"; issues=$((issues + 1)); }
info() { printf '     %s\n' "$*"; }

valid_app() {
  local app="$1"
  [[ -d "$app" ]] || return 1
  [[ -f "$app/Contents/Info.plist" ]] || return 1
  /usr/bin/plutil -lint "$app/Contents/Info.plist" >/dev/null 2>&1 || return 1
  local exe
  exe="$(/usr/bin/defaults read "$app/Contents/Info.plist" CFBundleExecutable 2>/dev/null || true)"
  [[ -n "$exe" && -x "$app/Contents/MacOS/$exe" ]]
}

app_version() {
  /usr/bin/defaults read "$1/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown"
}

echo "Mac Gaming Helper — doctor"
echo "=========================="

# ---------------------------------------------------------------- app install
echo ""
echo "App"
APP="/Applications/Mac Gaming Helper.app"
[[ -d "$APP" ]] || APP="$HOME/Applications/Mac Gaming Helper.app"
if valid_app "$APP"; then
  ok "Installed at $APP (v$(app_version "$APP"))"
  if /usr/bin/codesign --verify --deep --strict "$APP" >/dev/null 2>&1; then
    ok "Code signature verifies"
  else
    bad "Code signature is invalid"
    info "Fix: cd '$root' && ./scripts/install.sh"
  fi
  if xattr -p com.apple.quarantine "$APP" >/dev/null 2>&1; then
    warn "App still has a quarantine flag"
    info "Fix: ./scripts/fix-gatekeeper.sh"
  else
    ok "No quarantine flag"
  fi
  if "$APP/Contents/MacOS/MacGamingHelper" --self-test >/tmp/mgh-doctor-selftest.$$ 2>&1; then
    ok "Self-test passed"
  else
    bad "Self-test failed"
    tail -20 /tmp/mgh-doctor-selftest.$$ | sed 's/^/     /'
  fi
  rm -f /tmp/mgh-doctor-selftest.$$
else
  bad "App is not installed in /Applications or ~/Applications"
  info "Fix: cd '$root' && ./scripts/install.sh"
fi

# Duplicate copies are a common cause of opening a stale build.
if valid_app "/Applications/Mac Gaming Helper.app" && [[ -d "$HOME/Applications/Mac Gaming Helper.app" ]]; then
  warn "A second copy exists at ~/Applications/Mac Gaming Helper.app"
  info "Remove it to avoid launching a stale build: rm -rf \"$HOME/Applications/Mac Gaming Helper.app\""
fi

# ------------------------------------------------------------------- launchers
echo ""
echo "Launchers"
if valid_app "/Applications/Heroic.app"; then
  ok "Heroic $(app_version /Applications/Heroic.app) (/Applications/Heroic.app)"
  if [[ -f "$HOME/Library/Application Support/heroic/config.json" ]]; then
    ok "Heroic config present"
  else
    warn "Heroic has not been opened yet — launch it once to create its config"
  fi
else
  bad "Heroic is missing or not a valid app bundle"
  info "Fix: ./scripts/install-heroic.sh"
fi

if valid_app "/Applications/Steam.app"; then
  ok "Steam installed (/Applications/Steam.app)"
  if /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    ok "Rosetta 2 available (required by Steam)"
  else
    bad "Steam needs Rosetta 2, which is not installed"
    info "Fix: softwareupdate --install-rosetta --agree-to-license"
  fi
  if [[ -d "$HOME/Library/Application Support/Steam" ]]; then
    ok "Steam data folder present"
  else
    warn "Steam has not completed its first launch"
    info "Open Steam once and sign in, then Refresh in Mac Gaming Helper"
  fi
else
  warn "Steam is not installed (optional)"
  info "Install: ./scripts/install-gaming-launchers.sh --steam"
fi

# ------------------------------------------------------------------ controllers
echo ""
echo "Controllers"
app_bin="$APP/Contents/MacOS/MacGamingHelper"
if [[ -x "$app_bin" ]]; then
  if grep -aq -- "--controller-test" "$app_bin"; then
    ctrl_out="$("$app_bin" --controller-test 2>/dev/null)" || true
    if grep -q "controller-test: 0 connected" <<<"$ctrl_out"; then
      warn "No controller detected by Game Controller"
      info "Plug USB-C (DualSense) or Micro-USB (DualShock 4), press PS, then rerun."
    else
      ok "$(grep -m1 "controller-test:" <<<"$ctrl_out" | sed 's/^controller-test: //')"
      grep -E "kind=|light=|bluetooth:" <<<"$ctrl_out" | sed 's/^/     /'
    fi
  else
    warn "Installed app is too old for --controller-test"
    info "Fix: cd '$root' && ./scripts/install.sh"
  fi
else
  warn "Cannot check controllers without the app binary"
fi

# ---------------------------------------------------------------- integrations
echo ""
echo "Libraries"
steam_roots=0
for vdf in "$HOME/Library/Application Support/Steam/steamapps/libraryfolders.vdf" "$HOME/Library/Application Support/Steam/config/libraryfolders.vdf"; do
  [[ -f "$vdf" ]] && steam_roots=$((steam_roots + 1))
done
if (( steam_roots > 0 )); then
  ok "Steam library folders found ($steam_roots manifest(s))"
else
  warn "No Steam library folders yet — install a game in Steam, then Refresh"
fi

heroic_manifests=0
for f in \
  "$HOME/Library/Application Support/heroic/store_cache/legendary_install_info.json" \
  "$HOME/Library/Application Support/heroic/store_cache/gog_install_info.json" \
  "$HOME/Library/Application Support/heroic/store_cache/nile_install_info.json"
do
  [[ -f "$f" ]] && heroic_manifests=$((heroic_manifests + 1))
done
if (( heroic_manifests > 0 )); then
  ok "Heroic store manifests found ($heroic_manifests)"
else
  warn "No Heroic store manifests — sign in to Epic/GOG in Heroic and install a title"
fi

# ------------------------------------------------------------------- shortcuts
echo ""
echo "Shortcuts"
if [[ -L "$HOME/Desktop/Mac Gaming Helper.app" ]] || [[ -d "$HOME/Desktop/Mac Gaming Helper.app" ]]; then
  ok "Desktop shortcut present"
else
  warn "Desktop shortcut missing"
  info "Fix: ./scripts/install.sh"
fi
if [[ -x "$HOME/Desktop/Start Mac Gaming Helper.command" ]]; then
  ok "Desktop launcher script present"
else
  warn "Desktop launcher script missing"
  info "Fix: ./scripts/install.sh"
fi

# ----------------------------------------------------------------------- done
echo ""
if (( issues == 0 && warnings == 0 )); then
  echo "Everything looks good."
elif (( issues == 0 )); then
  echo "No blocking issues; $warnings warning(s) to review."
else
  echo "$issues blocking issue(s) and $warnings warning(s)."
fi
exit $(( issues > 0 ? 1 : 0 ))
