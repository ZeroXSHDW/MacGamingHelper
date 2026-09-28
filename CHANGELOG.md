# Changelog

## 3.4.1 — 2026-09-28

### Works better
- Stable controller IDs across sleep/reconnect (no more random selection drops)
- Rediscover debounce + auto-rescan after Mac wake
- Start gaming Mapping pause is sticky (no accidental toggle-resume); Steam prep uses same path
- Stop gaming clears overlay, keep-awake, and tears down zombie Performance Bar panels
- Start gaming is idempotent; Desktop `.command` always opens `/Applications` by path
- Perf metrics: Game CPU sampled off the main thread; ping timeouts clear stale ms; GPU never shows NaN
- Steam library buttons disabled / clearer empty copy when Steam missing
- Self-test covers session start/stop + sticky Mapping pause

## 3.4.0 — 2026-09-28

### Easier to run
- Big **Start gaming** / **Start gaming + Steam Big Picture** on Play (and menu bar / ⇧⌘G)
- 3-step first-run tour: Permissions → Pair → Start gaming (Reset tour in Help)
- Dock & Login: keep in Dock, Launch at login + “Start gaming minimized with Performance Bar”
- Desktop `Start Mac Gaming Helper.command` + `fix-gatekeeper.sh`
- Permissions one screen with status lights + Open all panes
- Start gaming turns Performance Bar on automatically; menu bar Start / Stop gaming session

## 3.3.1 — 2026-09-28

- Install to **/Applications** (fallback `~/Applications`) with quarantine strip + entitlements codesign
- Settings → **Permissions** one-tap deep links (Bluetooth, Accessibility, Notifications, Local Network, Automation)
- “Apply recommended gaming setup” enables Performance Bar (top), menu bar, keep-awake session, core metrics
- New-install default: Gaming Overlay ON in Performance Bar mode
- `scripts/open-permissions.sh` walks privacy panes for first-time setup
- Info.plist: Local Network + Bluetooth peripheral + notifications usage strings

## 3.3.0 — 2026-09-28

- **Gaming Performance Bar** — unified always-on-top Overlay (Compact HUD | Full Performance Bar)
- Live capsules: Controller + battery, CPU, Memory, GPU (IOKit best-effort), Panel Hz, Game CPU %, Ping, Mapping, Keep-awake
- Honest FPS policy: shows **Panel Hz** and frontmost **Game CPU** — never invents game FPS
- Settings → Overlay & performance (metrics checklist, ping host, opacity, top/bottom)
- Menu bar + ⌃⌥⌘P toggle; auto-show on Prep Steam / gaming session; auto-hide option
- Ping paused when overlay hidden

## 3.2.0 — 2026-09-28

- Keep-awake (IOPMAssertion) while Play HUD or Gaming session is on
- Live Input Tester page (press flash + stick trails + optional beeps)
- Audio cues: connect/disconnect + low battery
- Steam library: multi-folder roots, LastUpdated sort, search, favourites
- Heroic/Epic/GOG best-effort library list
- CrossOver / Whisky / GPTK detection on Session Prep
- One combo macro per mapping profile (hold + tap → key)
- Mouse acceleration tip + Open Mouse settings
- Play HUD: profile name, Pairing shortcut when disconnected, remembered position

## 3.1.0 — 2026-09-28

Gaming-first DualShock 4 session tools.

- **Play** page: Session Prep checklist, Prep Steam session (Mapping off + Big Picture), Steam library quick-launch (`steam://rungameid`)
- **Play HUD**: optional always-on-top floating panel (battery, LIVE/PAUSED, ⌥⌘M)
- Stick **response curves** (Linear / Ease-out / Expo), aim sensitivity, invert Y
- Hair-trigger L2/R2 thresholds; optional gyro assist when motion is exposed
- Running-game awareness banner when Steam/Heroic/GFN frontmost
- Profile hotkeys ⌘⌥1–3; menu bar Prep Steam / HUD / battery tint

## 3.0.0 — 2026-09-28

Major quality leap for a shipping DualShock 4 Mac utility.

### Shell / UX
- Sidebar sections (Desk / Setup), remembered last tab
- Window title shows pad short name + battery when connected
- Spring animations on connect, LIVE / PAUSED / ARMED mapping badges
- VoiceOver labels on major controls and diagram regions
- Focus mode (Controller-first) toggle

### Controller
- Stable pad selection + reconnect recovery by preference key
- Clear USB vs Bluetooth chips and player-index badge
- Honest motion / gyro readout (or explicit “not exposed” note)
- Stick calibration helper (sample center → suggest deadzone)
- Details disclosure for axes / light / haptics / motion

### Mapping / launchers
- ⌥⌘M pause/resume; optional auto-pause when app resigns active
- LIVE badge while posting CGEvents
- Steam Big Picture action turns Mapping off; Heroic / GFN tip cards

### Quality
- Diagnostics dump (copy / export to Desktop)
- Expanded self-test
- GitHub Release so in-app Check for updates sees `releases/latest`

## 2.3.0
Menu bar, Settings, deadzones, custom profiles, low battery, update check, haptics patterns, welcome sheet.

## 2.2.0
Bundled stylized art, Pairing coach illustrations, hero pad.

## 2.1.0
Pairing / Setup coach, self-test, USB-first guidance.

## 2.0.0
Initial DualShock 4 desk successor to Game Bay.
