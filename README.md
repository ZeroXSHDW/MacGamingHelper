# Mac Gaming Helper

Native SwiftUI macOS app for playing with a **PlayStation DualShock 4** on Apple silicon Macs (macOS 14+).

Live controller desk (Game Controller / `GCController`), DualShock layout, light bar & haptics when available, optional keyboard/mouse mapping, and a **Pairing / Setup** coach for the common “lights flash but Bluetooth never lists the pad” failure.

## Relation to Game Bay

This project **continues and improves** [Game Bay](https://github.com/ZeroXSHDW) (local predecessor at `~/Projects/game-bay` when present).

- Game Bay is **not deleted**. Keep using it for Coach / library features if you like.
- Mac Gaming Helper keeps the launcher hub (Steam, Heroic, GeForce NOW) and replaces the thin controller page with a DualShock 4–first desk: multi-pad selection, live diagram, light bar, haptics test, pairing coach, and optional keyboard/mouse mapping.

## Features

- Apple **Game Controller** — DualShock 4 (`GCDualShockGamepad`), DualSense, and other extended pads
- Connect / disconnect notifications + **Rediscover** wireless scan
- Live button / stick / trigger readouts and a schematic DualShock layout
- Battery, light-bar tint (when exposed), haptic pulse
- **Pairing / Setup** coach: Bluetooth Share+PS, **USB-first** rescue, reset pinhole, Steam Big Picture vs Mapping, permissions
- Optional **keyboard / mouse mapping** profiles (FPS WASD, Arrows) for non-gamepad titles
- Offline self-test: `MacGamingHelper --self-test`
- Offline — no accounts required for controller status or mapping

## Requirements

- macOS 14 or later (Apple silicon recommended)
- Xcode Command Line Tools (`xcode-select --install`) so `swiftc` and a macOS SDK are available

## Clone / build / install

```bash
git clone https://github.com/ZeroXSHDW/MacGamingHelper.git
cd MacGamingHelper
./scripts/install.sh
```

Installs to `~/Applications/Mac Gaming Helper.app` and adds a Desktop symlink. Game Bay is left untouched.

Build only (into `dist/`):

```bash
./scripts/build.sh
```

Self-test after install:

```bash
./scripts/self-test.sh
# or:
"/Users/$USER/Applications/Mac Gaming Helper.app/Contents/MacOS/MacGamingHelper" --self-test
```

Open the Sources folder in Xcode if you prefer an IDE; the build script compiles with `swiftc` the same way Game Bay does.

## Pair a DualShock 4

### Normal Bluetooth

1. Hold **Share + PlayStation** until the light bar flashes quickly.
2. System Settings → Bluetooth → **Wireless Controller** → Connect.
3. Open Mac Gaming Helper → **Rediscover** → watch the Controller page.

### USB-first (when lights flash but the pad never appears)

1. Use a Micro-USB **data** cable (not charge-only).
2. Plug into the Mac, press **PS** once, then Rediscover.
3. Optionally complete Bluetooth pairing while still on USB, then unplug.

### Reset

Flip the pad over → paperclip in the **reset pinhole** near L2 for ~5 seconds → retry USB or Share+PS.

Full steps live in the app under **Pairing / Setup**.

### Steam vs Mapping

- Steam: use **Big Picture** so Steam Input owns the pad. Keep Mapping **off**.
- Mapping: for apps that ignore gamepads. Requires **Accessibility**.

## Permissions

| Permission | When |
|---|---|
| **Bluetooth** | Pair DualShock 4 wirelessly |
| **Accessibility** | Only when Mapping is enabled (posts CGEvents). Deny safely leaves Mapping off. |
| **Input Monitoring** | Only if macOS prompts; not required for basic GCController readouts |

## Known limits

- **Gatekeeper / ad-hoc signature**: builds are ad-hoc signed (`codesign -s -`). First open may need Right-click → Open, or `xattr -cr` on the `.app` (install.sh already clears quarantine when possible).
- **Accessibility**: Mapping cannot post keys until you enable the app in Privacy & Security → Accessibility.
- **Bluetooth quirks**: some DualShock 4 units never show in macOS Bluetooth until USB pairing succeeds once.
- **Light bar / haptics**: depend on what Game Controller exposes for that firmware / connection mode.
- **Sandbox**: entitlements disable App Sandbox so Bluetooth + CGEvent mapping work; this is intentional for a local helper.

## License

MIT — see [LICENSE](LICENSE).
