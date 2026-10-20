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
                        Text("Modern Call of Duty’s Ricochet anti-cheat will not run locally through Steam, Heroic, Whisky, CrossOver, GPTK, or a VM. Use GeForce NOW or Xbox Cloud with a PlayStation controller.")
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
                        Text(item.isInstalled ? "Installed" : (item.isBroken ? "Needs reinstall" : "Not found"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(item.isInstalled ? Theme.good : (item.isBroken ? Theme.bad : Theme.warn))
                    }
                    Text(item.blurb)
                        .font(.callout)
                        .foregroundStyle(Theme.mute)
                        .fixedSize(horizontal: false, vertical: true)
                    if let broken = item.brokenURL {
                        Text("This item is not a real app bundle — usually a failed download saved as “\(broken.lastPathComponent)”. Install it again to repair.")
                            .font(.caption)
                            .foregroundStyle(Theme.bad)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
                            if SystemSupport.steamLaunchBlockedByRosetta {
                                Text("Steam is Intel-only and needs Rosetta 2. Until it is installed, Steam will not open.")
                                    .font(.caption)
                                    .foregroundStyle(Theme.bad)
                                PillButton(title: "Copy Rosetta 2 command") { launchers.copyRosettaCommand() }
                            }
                        }
                        if item.id == "heroic" {
                            Text("Tip: Install a Wine / GPTK runner in Heroic before Windows builds. Prefer native pad first; Mapping only if the game ignores gamepads.")
                                .font(.caption)
                                .foregroundStyle(Theme.mute)
                        }
                        if item.id == "geforce" {
                            Text("Tip: Cloud play for titles blocked by anti-cheat on Mac. A PlayStation pad usually works once GFN sees the pad.")
                                .font(.caption)
                                .foregroundStyle(Theme.mute)
                        }
                    } else {
                        HStack {
                            if item.installURL != nil {
                                PillButton(title: item.isBroken ? "Reinstall" : "Install", primary: true) {
                                    launchers.openInstallPage(item)
                                }
                            }
                            if item.installCommand != nil {
                                PillButton(title: "Copy install command") {
                                    launchers.copyInstallCommand(item)
                                }
                            }
                            if let broken = item.brokenURL {
                                PillButton(title: "Show failed download") {
                                    launchers.reveal(broken)
                                }
                            }
                        }
                        Text(installHint(for: item))
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func installHint(for item: Launcher) -> String {
        switch item.id {
        case "heroic":
            return "Official download. Or run ./scripts/install-heroic.sh, which verifies the app bundle and repairs broken downloads automatically."
        case "steam":
            return "Official Steam download. The Homebrew cask is Intel-only and needs Rosetta 2."
        default:
            return "Opens the official download page in your browser."
        }
    }
}

struct HelpPage: View {
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var mapper: InputMapper
    @EnvironmentObject private var settings: AppSettings
    @State private var diagPreview = ""
    @State private var updateInfo: UpdateInfo?
    @State private var checkingUpdate = false

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
                        Text("PlayStation controller features")
                            .font(.headline)
                        Text("• Connect / disconnect via Game Controller (GCController), with Rediscover for wireless scan")
                        Text("• DualSense (PS5) and DualShock 4 (PS4): face buttons, sticks, L2/R2, Create/Share, Options, PS and touchpad")
                        Text("• Live buttons, sticks, triggers, touchpad, light bar, haptics and DualSense adaptive triggers")
                        Text("• Pad Check — press each of 19 controls once and get a pass/incomplete report you can copy")
                        Text("• Wireless readiness — Bluetooth power, paired/connected pad, and when it is safe to unplug USB")
                        Text("• Correct USB vs Bluetooth transport, battery readout and Player 1–4 slots")
                        Text("• Background input, event-driven snapshots and a 60 Hz Mapping loop")
                        Text("• Optional keyboard / mouse mapping profiles (FPS WASD, Arrows)")
                        Text("• Pairing / Setup coach: USB-first rescue, reset pinhole, Steam vs Mapping, permissions")
                        Text("• Launcher shortcuts for Steam, Heroic, GeForce NOW, and detected extras")
                        Text("• Offline self-test: MacGamingHelper --self-test · controller test: --controller-test")
                    }
                    .font(.callout)
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Controller troubleshooting")
                            .font(.headline)
                        Text("• Not listed at all? Plug in USB-C (DualSense) or Micro-USB (DualShock 4) with a data cable first, press PS, then Rediscover.")
                        Text("• Presses not showing? Open Input Test. If it stays empty, quit Steam while testing — Steam Input can hold the pad exclusively.")
                        Text("• Wireless not connecting? Controller → Wireless readiness → Check. It should say Paired; press PS once if it says paired but not connected.")
                        Text("• Need every button checked? Controller → Pad check. It checks off each control automatically.")
                        Text("• Mapping not posting? Accessibility must be granted, Mapping must be on, and the app must be armed (not paused).")
                        HStack {
                            PillButton(title: "Open Controller page") {
                                NotificationCenter.default.post(name: .mghGoPage, object: NavPage.controller.rawValue)
                            }
                            PillButton(title: "Open Pairing") {
                                NotificationCenter.default.post(name: .mghGoPage, object: NavPage.setup.rawValue)
                            }
                        }
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
                        Text("Launchers: install or repair Heroic with scripts/install-heroic.sh. The Launchers page flags failed downloads as “Needs reinstall”.")
                            .foregroundStyle(Theme.mute)
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
                        Text("About")
                            .font(.headline)
                        Text("Mac Gaming Helper \(Theme.version) (build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"))")
                        Text("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                        Text("⌥⌘M pauses Mapping while the Performance Bar is up (enable Mapping first). Overlay does not steal the hotkey from the main app.")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                        HStack(spacing: 8) {
                            PillButton(title: "GitHub releases") {
                                NSWorkspace.shared.open(UpdateChecker.releasesPage)
                            }
                            PillButton(title: "Check for updates") {
                                checkingUpdate = true
                                Task {
                                    let info = await UpdateChecker.check()
                                    updateInfo = info
                                    checkingUpdate = false
                                }
                            }
                        }
                        if let info = updateInfo {
                            Text(info.message)
                                .font(.caption)
                                .foregroundStyle(info.isNewer ? Theme.good : Theme.mute)
                                .textSelection(.enabled)
                        }
                    }
                    .font(.callout)
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permissions checklist")
                            .font(.headline)
                        Text("1. Bluetooth — pair DualSense / DualShock 4 in System Settings → Bluetooth.")
                        Text("2. Accessibility — only if you turn Mapping on (Privacy & Security → Accessibility).")
                        Text("3. Input Monitoring — grant if macOS asks while reading HID; Game Controller usually needs neither for status alone.")
                        Text("4. Notifications — low-battery alerts (optional).")
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
