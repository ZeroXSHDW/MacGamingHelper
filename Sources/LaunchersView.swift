import AppKit
import SwiftUI

struct LaunchersPage: View {
    @EnvironmentObject private var launchers: LauncherShelf
    @EnvironmentObject private var mapper: InputMapper

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Launchers")
                            .font(.largeTitle.weight(.bold))
                            .tracking(-0.4)
                        Text("Same job as Game Bay’s Play page: open the tools that already run games on this Mac.")
                            .foregroundStyle(Theme.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    BundledImage(name: "badge-launchers", maxHeight: 100, cornerRadius: 14)
                        .frame(width: 160)
                }

                ForEach(launchers.items) { item in
                    launcherCard(item, primary: true)
                }

                Text("Also on this Mac")
                    .font(.title3.weight(.semibold))
                    .padding(.top, 8)

                ForEach(launchers.extras) { item in
                    launcherCard(item, primary: false)
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Cloud fallbacks")
                            .font(.headline)
                        Text("Modern Call of Duty’s Ricochet anti-cheat will not run locally through Steam, Heroic, Whisky, CrossOver, GPTK, or a VM. Use GeForce NOW or Xbox Cloud with the DualShock 4.")
                            .foregroundStyle(Theme.mute)
                        HStack {
                            PillButton(title: "Xbox Cloud Gaming", primary: true) { launchers.openXboxCloud() }
                            if let gfn = launchers.items.first(where: { $0.id == "geforce" }), gfn.isInstalled {
                                PillButton(title: "Open GeForce NOW") { launchers.open(gfn) }
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .onAppear { launchers.refresh() }
    }

    private func launcherCard(_ item: Launcher, primary: Bool) -> some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: item.symbol)
                    .font(.title2)
                    .foregroundStyle(item.isInstalled ? Theme.accent : Theme.mute)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.name).font(.headline)
                        Spacer()
                        Text(item.isInstalled ? "Installed" : "Not found")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(item.isInstalled ? Theme.good : Theme.warn)
                    }
                    Text(item.blurb)
                        .font(.callout)
                        .foregroundStyle(Theme.mute)
                        .fixedSize(horizontal: false, vertical: true)
                    if item.isInstalled {
                        HStack {
                            PillButton(title: "Open", primary: primary) { launchers.open(item) }
                            if item.id == "steam" {
                                PillButton(title: "Open + Big Picture", primary: true) {
                                    if mapper.enabled {
                                        mapper.stop()
                                    }
                                    launchers.openSteamBigPicture()
                                }
                                .accessibilityLabel("Open Steam Big Picture and turn mapping off")
                            }
                            if item.id == "heroic" {
                                PillButton(title: "Open + tip") {
                                    launchers.open(item)
                                }
                            }
                            if item.id == "geforce" {
                                PillButton(title: "Open + tip") { launchers.open(item) }
                            }
                        }
                        if item.id == "steam" {
                            Text("Tip: Use Steam Input in Big Picture. Mapping is turned off when you launch Big Picture from here so keys are not double-fired.")
                                .font(.caption)
                                .foregroundStyle(Theme.warn)
                        }
                        if item.id == "heroic" {
                            Text("Tip: Install a Wine / GPTK runner in Heroic before Windows builds. Prefer native pad first; Mapping only if the game ignores gamepads.")
                                .font(.caption)
                                .foregroundStyle(Theme.mute)
                        }
                        if item.id == "geforce" {
                            Text("Tip: Cloud play for titles blocked by anti-cheat on Mac. DualShock 4 usually works once GFN sees the pad.")
                                .font(.caption)
                                .foregroundStyle(Theme.mute)
                        }
                    }
                }
            }
        }
    }
}

struct HelpPage: View {
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var mapper: InputMapper
    @EnvironmentObject private var settings: AppSettings
    @State private var diagPreview = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    Text("Help")
                        .font(.largeTitle.weight(.bold))
                        .tracking(-0.4)
                    Spacer()
                    BundledImage(name: "badge-help", maxHeight: 80, cornerRadius: 14)
                        .frame(width: 120)
                }

                BundledImage(name: "banner", maxHeight: 160, cornerRadius: 16)
                    .frame(maxWidth: .infinity)

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What this app is")
                            .font(.headline)
                        Text(Theme.relationNote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DualShock 4 features")
                            .font(.headline)
                        Text("• Connect / disconnect via Game Controller (GCController), with Rediscover for wireless scan")
                        Text("• Prefers DualShock 4 when several pads are present; DualSense also fully supported")
                        Text("• Live buttons, sticks, L2/R2 triggers, Share / Options / PS / touchpad")
                        Text("• Visual DualShock layout that lights up with presses")
                        Text("• Battery readout when the pad reports it")
                        Text("• Light-bar tint when GCDeviceLight is available; haptic pulse test")
                        Text("• Optional keyboard / mouse mapping profiles (FPS WASD, Arrows)")
                        Text("• Pairing / Setup coach: USB-first rescue, reset pinhole, Steam vs Mapping, permissions")
                        Text("• Launcher shortcuts for Steam, Heroic, GeForce NOW, and detected extras")
                        Text("• Offline self-test: MacGamingHelper --self-test")
                    }
                    .font(.callout)
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Easiest run")
                            .font(.headline)
                        Text("1. Open /Applications/Mac Gaming Helper.app (or Desktop → Start Mac Gaming Helper.command)")
                        Text("2. Tap Start gaming on the Play page (or menu bar → Start gaming)")
                        Text("3. Performance Bar appears at the top — play")
                        Text("Version \(Theme.version). ⇧⌘G Start gaming · ⌃⌥⌘P Overlay · ⌘R Rediscover.")
                        Text("Game Bay (unchanged): ~/Projects/game-bay")
                            .foregroundStyle(Theme.mute)
                        HStack {
                            PillButton(title: "Reset first-run tour") {
                                settings.didShowWelcome = false
                            }
                            PillButton(title: "Fix “can’t be opened”") {
                                EasyRun.copyGatekeeperCommand()
                            }
                        }
                        Text("Gatekeeper: copies `xattr -cr` command to clipboard. Or run scripts/fix-gatekeeper.sh. First open may need Right-click → Open.")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                    }
                    .font(.callout)
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permissions checklist")
                            .font(.headline)
                        Text("1. Bluetooth — System Settings → Bluetooth → pair Wireless Controller (DS4).")
                        Text("2. Accessibility — only if you turn Mapping on (Privacy & Security → Accessibility).")
                        Text("3. Input Monitoring — grant if macOS asks while reading HID; Game Controller usually needs neither for status alone.")
                        Text("If the pad flashes but never appears: use Pairing / Setup → USB-first steps.")
                        Text("No account sign-in is required for controller status or local mapping.")
                    }
                    .font(.callout)
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Diagnostics")
                            .font(.headline)
                        Text("Export a support dump for troubleshooting DualShock pairing or mapping.")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                        HStack {
                            PillButton(title: "Copy diagnostics", primary: true) {
                                let text = Diagnostics.dump(monitor: monitor, mapper: mapper, settings: settings)
                                diagPreview = String(text.prefix(400)) + "…"
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                            }
                            PillButton(title: "Export to Desktop") {
                                if let url = Diagnostics.exportToDesktop(monitor: monitor, mapper: mapper, settings: settings) {
                                    diagPreview = "Wrote \(url.lastPathComponent)"
                                }
                            }
                        }
                        if !diagPreview.isEmpty {
                            Text(diagPreview)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Theme.mute)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(28)
        }
    }
}
