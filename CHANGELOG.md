# Changelog

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
