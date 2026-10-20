import AppKit
import SwiftUI

/// Which PlayStation pad the setup coach is currently explaining.
enum PadFamily: String, CaseIterable, Identifiable {
    case dualSense = "DualSense (PS5)"
    case dualShock4 = "DualShock 4 (PS4)"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .dualSense: return "DualSense"
        case .dualShock4: return "DualShock 4"
        }
    }

    var cable: String {
        switch self {
        case .dualSense: return "USB-C"
        case .dualShock4: return "Micro-USB"
        }
    }

    var bluetoothChord: String {
        switch self {
        case .dualSense: return "Create + PS"
        case .dualShock4: return "Share + PS"
        }
    }
}

/// DualSense / DualShock 4 pairing and setup coach.
enum PairingCoach {
    static func bluetoothSteps(for family: PadFamily) -> [String] {
        [
            "Charge the \(family.shortName); the light bar should light when you briefly press PS.",
            "Hold \(family.bluetoothChord) together until the light bar flashes quickly — that is pairing mode.",
            "Open System Settings → Bluetooth. Wait for “\(family.shortName) Wireless Controller” (or “Wireless Controller”).",
            "Click Connect. The light bar should go steady.",
            "Return here and press Rediscover. The Controller page should show \(family.shortName) live.",
            "If it still does not appear, quit Steam, remove stale Bluetooth entries, and try the USB-first steps.",
        ]
    }

    static func usbFirstSteps(for family: PadFamily) -> [String] {
        [
            "If the pad flashes but never appears in Bluetooth, use USB first — this is the most reliable fix on modern macOS.",
            "Plug a \(family.cable) data cable into the \(family.shortName) and the Mac. Charge-only cables will not work.",
            "Press PS once. macOS should enumerate the pad over USB; Mac Gaming Helper should show it within a few seconds (try Rediscover).",
            "With the pad still on USB and connected, open Bluetooth Settings. Some Macs then keep the pairing after you unplug.",
            "Unplug the cable. If the light goes out, press PS once. If it never reconnects wirelessly, forget stale “Wireless Controller” entries and repeat \(family.bluetoothChord) pairing.",
        ]
    }

    static func resetSteps(for family: PadFamily) -> [String] {
        switch family {
        case .dualSense:
            return [
                "Flip the DualSense over. Find the tiny reset pinhole on the back near the L2 trigger.",
                "Use a paperclip to press and hold the reset button for about 5 seconds.",
                "Release, then try USB-C first (above), or Create + PS for Bluetooth pairing again.",
                "In Bluetooth Settings, remove any old “DualSense Wireless Controller” entries that show Not Connected forever.",
            ]
        case .dualShock4:
            return [
                "Flip the DualShock 4 over. Find the tiny reset pinhole near the L2 shoulder.",
                "Use a paperclip to press and hold the reset button for about 5 seconds.",
                "Release, then try USB first (above), or Share + PS for Bluetooth pairing again.",
                "In Bluetooth Settings, remove any old “Wireless Controller” entries that show Not Connected forever.",
            ]
        }
    }

    static let steamVsMapping: [String] = [
        "Steam games: prefer Steam Big Picture + Steam Input. Steam owns the DualSense / DualShock 4 and applies game configs.",
        "Turn Mapping OFF while using Steam Input so keys are not double-fired.",
        "Non-gamepad apps (browsers, older Mac titles): enable Mapping and pick FPS WASD or Arrows.",
        "Heroic / Wine games: try the pad natively first; fall back to Mapping only if the game ignores gamepads.",
    ]

    static let permissions: [(title: String, detail: String)] = [
        ("Bluetooth", "Required to pair and reconnect a DualSense / DualShock 4 wirelessly. Grant when macOS prompts, or enable under System Settings → Privacy & Security → Bluetooth."),
        ("Accessibility", "Only needed when Mapping is ON. This app posts keyboard/mouse events (CGEvent). Deny Mapping safely stays off."),
        ("Input Monitoring", "Usually not required for Game Controller readouts. Grant only if macOS asks while troubleshooting HID."),
    ]

    /// Illustration asset names shipped in Resources/.
    static let artNames = [
        "hero-pad", "hero-pad-lit", "coach-usb", "coach-bluetooth",
        "coach-reset", "coach-share-ps", "badge-mapping", "badge-launchers", "badge-help",
    ]
}

struct SetupPage: View {
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var mapper: InputMapper
    @EnvironmentObject private var launchers: LauncherShelf
    @State private var padFamily: PadFamily = .dualSense

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pairing / Setup")
                            .font(.largeTitle.weight(.bold))
                            .tracking(-0.4)
                        Text("DualSense and DualShock 4 on this Mac — Bluetooth, USB-first rescue, reset, Steam vs Mapping, and permissions.")
                            .foregroundStyle(Theme.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    HeroPadArt(connected: monitor.selected.connected, maxHeight: 100)
                        .frame(width: 180)
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Which controller are you pairing?")
                            .font(.headline)
                        Picker("Controller model", selection: $padFamily) {
                            ForEach(PadFamily.allCases) { family in
                                Text(family.rawValue).tag(family)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text("Steps below update for \(padFamily.shortName): \(padFamily.cable) cable, \(padFamily.bluetoothChord) pairing.")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                    }
                }

                // Visual strip of coach arts
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Illustrated guide")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                            CoachStepArt(imageName: "coach-share-ps", title: "Create/Share + PS")
                            CoachStepArt(imageName: "coach-bluetooth", title: "Bluetooth")
                            CoachStepArt(imageName: "coach-usb", title: "USB-first")
                            CoachStepArt(imageName: "coach-reset", title: "Reset pinhole")
                        }
                    }
                }

                statusCard

                coachCard(
                    title: "Bluetooth pairing (\(padFamily.bluetoothChord))",
                    steps: PairingCoach.bluetoothSteps(for: padFamily),
                    tint: Theme.ds4Blue,
                    art: "coach-share-ps"
                )
                coachCard(
                    title: "USB-first (\(padFamily.cable)) when Bluetooth won’t list the pad",
                    steps: PairingCoach.usbFirstSteps(for: padFamily),
                    tint: Theme.warn,
                    art: "coach-usb"
                )
                coachCard(
                    title: "Reset pinhole (stuck / invisible pad)",
                    steps: PairingCoach.resetSteps(for: padFamily),
                    tint: Theme.bad,
                    art: "coach-reset"
                )
                coachCard(
                    title: "Steam Big Picture vs Mapping",
                    steps: PairingCoach.steamVsMapping,
                    tint: Theme.accent,
                    art: "badge-mapping"
                )

                permissionsCard
                actionsCard
                aboutCard
            }
            .padding(28)
        }
        .background(Theme.heroGradient.opacity(0.25))
        .onAppear { syncFamilyToConnectedPad() }
        .onChange(of: monitor.selected.kind) { _, _ in syncFamilyToConnectedPad() }
    }

    private func syncFamilyToConnectedPad() {
        switch monitor.selected.kind {
        case .dualSense:
            padFamily = .dualSense
        case .dualShock4:
            padFamily = .dualShock4
        default:
            break
        }
    }

    private var statusCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Live status")
                    .font(.headline)
                HStack(spacing: 8) {
                    Circle()
                        .fill(monitor.selected.connected ? Theme.good : Theme.bad)
                        .frame(width: 10, height: 10)
                    Text(monitor.selected.connected
                         ? "\(monitor.selected.kind.rawValue) connected — \(monitor.selected.battery)"
                         : "No PlayStation controller seen by Game Controller yet")
                        .font(.callout.weight(.semibold))
                }
                if monitor.selected.connected {
                    Text([
                        monitor.selected.transportLabel,
                        monitor.selected.adaptiveTriggersSupported ? "Adaptive triggers available" : nil,
                    ].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(monitor.selected.adaptiveTriggersSupported ? Theme.good : Theme.mute)
                }
                Text(monitor.statusLine)
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Circle()
                        .fill(mapper.accessibilityTrusted ? Theme.good : Theme.warn)
                        .frame(width: 8, height: 8)
                    Text(mapper.accessibilityTrusted ? "Accessibility granted" : "Accessibility not granted (Mapping disabled until allowed)")
                        .font(.caption)
                }
            }
        }
    }

    private func coachCard(title: String, steps: [String], tint: Color, art: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    BundledImage(name: art, maxHeight: 88, cornerRadius: 12)
                        .frame(width: 140)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tint)
                                .frame(width: 4, height: 18)
                            Text(title)
                                .font(.headline)
                        }
                        ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(idx + 1).")
                                    .font(.callout.monospaced().weight(.bold))
                                    .foregroundStyle(tint)
                                    .frame(width: 24, alignment: .trailing)
                                Text(step)
                                    .font(.callout)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private var permissionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Required permissions")
                    .font(.headline)
                ForEach(PairingCoach.permissions, id: \.title) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.callout.weight(.semibold))
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var actionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick actions")
                    .font(.headline)
                HStack(spacing: 10) {
                    PillButton(title: monitor.discovering ? "Scanning…" : "Rediscover", primary: true) {
                        monitor.rediscover()
                    }
                    PillButton(title: "Bluetooth Settings") { PermissionsHelper.openBluetoothSettings() }
                    if monitor.selected.connected {
                        PillButton(title: "Identify pad") { monitor.identifyController() }
                    }
                    PillButton(title: "Bluetooth privacy") { PermissionsHelper.openBluetoothPrivacy() }
                    PillButton(title: "Open Accessibility") { PermissionsHelper.openAccessibility() }
                    PillButton(title: "Notifications") { PermissionsHelper.openNotifications() }
                    if launchers.items.first(where: { $0.id == "steam" })?.isInstalled == true {
                        PillButton(title: "Steam Big Picture") { launchers.openSteamBigPicture() }
                    }
                }
                PillButton(title: "Recheck Accessibility") {
                    mapper.refreshTrust()
                }
            }
        }
    }

    private var aboutCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("About this helper")
                    .font(.headline)
                Text(Theme.relationNote)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Version \(Theme.version) · offline controller desk · no account required for pad status.")
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
            }
        }
    }
}
