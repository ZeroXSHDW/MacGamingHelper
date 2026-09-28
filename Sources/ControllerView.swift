import SwiftUI

struct ControllerPage: View {
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var launchers: LauncherShelf
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                HeroPadArt(connected: monitor.selected.connected, maxHeight: 210)
                    .frame(maxWidth: .infinity)
                if !monitor.snapshots.isEmpty {
                    picker
                }
                if monitor.selected.connected {
                    DualShockDiagram(snap: monitor.selected)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                readouts
                if monitor.selected.connected {
                    lightAndHaptics
                    deadzoneCard
                }
                tips
            }
            .padding(28)
            .animation(.easeInOut(duration: 0.3), value: monitor.selected.connected)
        }
        .background(Theme.heroGradient.opacity(0.35))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DualShock 4 Desk")
                        .font(.largeTitle.weight(.bold))
                        .tracking(-0.4)
                    Text(monitor.statusLine)
                        .foregroundStyle(Theme.mute)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                BundledImage(name: "badge-help", maxHeight: 56, cornerRadius: 12)
                    .frame(width: 100)
                    .opacity(0.9)
            }
            HStack(spacing: 10) {
                PillButton(title: monitor.discovering ? "Scanning…" : "Rediscover", primary: true) {
                    monitor.rediscover()
                }
                PillButton(title: "Bluetooth Settings") { launchers.openBluetooth() }
                if launchers.items.first(where: { $0.id == "steam" })?.isInstalled == true {
                    PillButton(title: "Steam Big Picture") { launchers.openSteamBigPicture() }
                }
            }
        }
    }

    private var picker: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connected controllers")
                    .font(.headline)
                ForEach(monitor.snapshots) { snap in
                    Button {
                        monitor.selectedID = snap.id
                    } label: {
                        HStack {
                            Image(systemName: snap.kind.isPlayStation ? "gamecontroller.fill" : "gamecontroller")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snap.title).font(.callout.weight(.semibold))
                                Text("\(snap.category) · \(snap.battery)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.mute)
                            }
                            Spacer()
                            if snap.id == monitor.selected.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(8)
                        .background(
                            snap.id == monitor.selected.id
                                ? Theme.accent.opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var readouts: some View {
        let s = monitor.selected
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(s.connected ? s.title : "Waiting for a DualShock 4")
                    .font(.title3.weight(.semibold))
                if s.connected {
                    Text([s.kind.rawValue, s.category, s.battery].filter { !$0.isEmpty }.joined(separator: " · "))
                        .foregroundStyle(Theme.mute)
                    Text(s.buttons.isEmpty ? "Press a button or move a stick." : s.buttons.joined(separator: "   "))
                        .font(.title3.monospaced())
                        .foregroundStyle(Theme.ds4Blue)
                        .frame(minHeight: 28, alignment: .leading)
                    AxisLine(name: "Left stick X", value: s.lx, bipolar: true)
                    AxisLine(name: "Left stick Y", value: s.ly, bipolar: true)
                    AxisLine(name: "Right stick X", value: s.rx, bipolar: true)
                    AxisLine(name: "Right stick Y", value: s.ry, bipolar: true)
                    AxisLine(name: "L2 trigger", value: s.lt, bipolar: false)
                    AxisLine(name: "R2 trigger", value: s.rt, bipolar: false)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No DualShock 4 yet — try this:")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        HStack(spacing: 12) {
                            CoachStepArt(imageName: "coach-usb", title: "USB first")
                            CoachStepArt(imageName: "coach-share-ps", title: "Share + PS")
                            CoachStepArt(imageName: "coach-bluetooth", title: "Bluetooth")
                            CoachStepArt(imageName: "coach-reset", title: "Reset")
                        }
                        Text("1. Lights flash but pad never appears? Plug Micro-USB (data cable) first, press PS, then Rediscover.")
                        Text("2. Or hold Share + PS until the light flashes quickly → Bluetooth → Wireless Controller.")
                        Text("3. Still invisible? Reset pinhole (paperclip, ~5s), forget stale Bluetooth entries, retry USB.")
                        Text("Full coach: sidebar → Pairing / Setup.")
                            .foregroundStyle(Theme.mute)
                        HStack(spacing: 10) {
                            PillButton(title: monitor.discovering ? "Scanning…" : "Rediscover", primary: true) {
                                monitor.rediscover()
                            }
                            PillButton(title: "Bluetooth Settings") { launchers.openBluetooth() }
                        }
                    }
                    .font(.callout)
                    .foregroundStyle(Theme.mute)
                }
            }
        }
    }

    private var lightAndHaptics: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Light bar & haptics")
                    .font(.headline)
                connectionDetail
                if monitor.selected.lightBarSupported {
                    HStack {
                        Text("Tint")
                        Slider(value: $monitor.lightHue, in: 0...1)
                        Circle()
                            .fill(Color(hue: monitor.lightHue, saturation: 0.85, brightness: 0.95))
                            .frame(width: 22, height: 22)
                    }
                    PillButton(title: "Apply light bar", primary: true) { monitor.applyLightBar() }
                } else {
                    Text(monitor.selected.connected
                         ? "This pad does not expose a controllable light bar through Game Controller."
                         : "Connect a DualShock 4 / DualSense to try light bar tint and rumble.")
                        .foregroundStyle(Theme.mute)
                }
                Text("Haptic tests")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HapticPatternKind.allCases) { kind in
                        PillButton(title: kind.title, primary: kind == .medium) {
                            monitor.pulseHaptics(kind)
                        }
                    }
                }
                if !monitor.lastHapticNote.isEmpty {
                    Text(monitor.lastHapticNote)
                        .font(.caption)
                        .foregroundStyle(Theme.mute)
                }
            }
        }
    }

    private var connectionDetail: some View {
        let s = monitor.selected
        return VStack(alignment: .leading, spacing: 4) {
            Text("Connection")
                .font(.subheadline.weight(.semibold))
            Text([
                s.transportLabel,
                s.vendor.isEmpty ? nil : s.vendor,
                s.category.isEmpty ? nil : s.category,
                s.playerIndex >= 0 ? "Player \(s.playerIndex + 1)" : nil,
                s.battery.isEmpty ? nil : s.battery,
            ].compactMap { $0 }.joined(separator: " · "))
            .font(.caption)
            .foregroundStyle(Theme.mute)
        }
    }

    private var deadzoneCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Stick deadzone (live)")
                    .font(.headline)
                HStack(spacing: 20) {
                    DeadzoneRing(title: "Left", x: monitor.selected.lx, y: monitor.selected.ly, deadzone: settings.stickDeadzone)
                    DeadzoneRing(title: "Right", x: monitor.selected.rx, y: monitor.selected.ry, deadzone: settings.stickDeadzone)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: "Deadzone %.2f", settings.stickDeadzone))
                            .font(.caption.monospaced())
                        Slider(value: $settings.stickDeadzone, in: 0.02...0.45)
                        Text(String(format: "Triggers L2 %.2f  R2 %.2f  (dz %.2f)", monitor.selected.lt, monitor.selected.rt, settings.triggerDeadzone))
                            .font(.caption2)
                            .foregroundStyle(Theme.mute)
                    }
                }
            }
        }
    }

    private var tips: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pairing a DualShock 4")
                    .font(.headline)
                Text("1. Prefer USB first if Bluetooth discovery fails — plug Micro-USB, press PS, Rediscover.")
                Text("2. Wireless: hold Share + PlayStation until the light bar flashes quickly.")
                Text("3. System Settings → Bluetooth → Wireless Controller → Connect.")
                Text("4. Press Rediscover here. Live buttons/sticks mean Game Controller sees the pad.")
                Text("5. Steam: Big Picture + Steam Input. Mapping is for apps that ignore gamepads.")
                    .foregroundStyle(Theme.mute)
                Text("Stuck? Open Pairing / Setup for reset pinhole, USB rescue, and permissions.")
                    .font(.caption)
                    .foregroundStyle(Theme.warn)
            }
            .font(.callout)
        }
    }
}

struct AxisLine: View {
    let name: String
    let value: Double
    let bipolar: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(name)  \(String(format: "%+.2f", value))")
                .font(.caption.monospaced())
                .foregroundStyle(Theme.mute)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    if bipolar {
                        let w = geo.size.width
                        Capsule()
                            .fill(Theme.ds4Blue)
                            .frame(width: max(4, abs(value) * w / 2), height: 8)
                            .offset(x: value >= 0 ? w / 2 : w / 2 + CGFloat(value) * w / 2)
                    } else {
                        Capsule()
                            .fill(Theme.ds4Blue)
                            .frame(width: max(4, CGFloat(value) * geo.size.width), height: 8)
                    }
                }
            }
            .frame(height: 8)
        }
    }
}

/// Schematic DualShock-style layout that lights up with the live pad state.
struct DualShockDiagram: View {
    let snap: ControllerSnapshot

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Live DualShock layout")
                    .font(.headline)
                ZStack {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.14, blue: 0.18),
                                    Color(red: 0.18, green: 0.20, blue: 0.26),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 36, style: .continuous)
                                .strokeBorder(Theme.ds4Blue.opacity(0.35), lineWidth: 2)
                        )
                        .frame(height: 260)

                    // Touchpad
                    RoundedRectangle(cornerRadius: 8)
                        .fill(lit("Touchpad") ? Theme.ds4Blue : Color.white.opacity(0.12))
                        .frame(width: 160, height: 70)
                        .offset(y: -70)

                    // Face buttons
                    faceCluster
                        .offset(x: 140, y: 10)

                    // D-pad
                    dpadCluster
                        .offset(x: -140, y: 10)

                    // Sticks
                    stick(x: snap.lx, y: snap.ly, pressed: lit("L3"))
                        .offset(x: -70, y: 70)
                    stick(x: snap.rx, y: snap.ry, pressed: lit("R3"))
                        .offset(x: 70, y: 70)

                    // Shoulders / triggers
                    HStack {
                        VStack(spacing: 6) {
                            triggerBar(value: snap.lt, label: "L2", active: lit("L2"))
                            shoulder("L1", active: lit("L1"))
                        }
                        Spacer()
                        VStack(spacing: 6) {
                            triggerBar(value: snap.rt, label: "R2", active: lit("R2"))
                            shoulder("R1", active: lit("R1"))
                        }
                    }
                    .padding(.horizontal, 36)
                    .offset(y: -110)

                    // Share / Options / PS
                    HStack(spacing: 28) {
                        smallBtn("Share", active: lit("Share") || lit("View"))
                        Circle()
                            .fill(lit("PS") || lit("Home") ? Theme.ds4Blue : Color.white.opacity(0.2))
                            .frame(width: 22, height: 22)
                            .overlay(Text("PS").font(.system(size: 7, weight: .bold)).foregroundStyle(.white))
                        smallBtn("Options", active: lit("Options") || lit("Menu"))
                    }
                    .offset(y: -20)
                }
                .frame(maxWidth: .infinity)
                .opacity(snap.connected ? 1 : 0.45)
            }
        }
    }

    private func lit(_ name: String) -> Bool {
        if name == "Touchpad" { return snap.touchpadPressed || snap.buttons.contains("Touchpad") }
        if name == "PS" { return snap.homePressed || snap.buttons.contains("PS") }
        return snap.buttons.contains(name)
    }

    private var faceCluster: some View {
        let f = snap.kind.face
        return ZStack {
            faceBtn(f.y, dx: 0, dy: -28)
            faceBtn(f.b, dx: 28, dy: 0)
            faceBtn(f.a, dx: 0, dy: 28)
            faceBtn(f.x, dx: -28, dy: 0)
        }
    }

    private func faceBtn(_ name: String, dx: CGFloat, dy: CGFloat) -> some View {
        Circle()
            .fill(lit(name) ? Theme.ds4Blue : Color.white.opacity(0.18))
            .frame(width: 28, height: 28)
            .overlay(Text(String(name.prefix(1))).font(.caption2.bold()).foregroundStyle(.white))
            .offset(x: dx, y: dy)
    }

    private var dpadCluster: some View {
        ZStack {
            dpadArm(active: lit("Up"), w: 22, h: 28).offset(y: -18)
            dpadArm(active: lit("Down"), w: 22, h: 28).offset(y: 18)
            dpadArm(active: lit("Left"), w: 28, h: 22).offset(x: -18)
            dpadArm(active: lit("Right"), w: 28, h: 22).offset(x: 18)
        }
    }

    private func dpadArm(active: Bool, w: CGFloat, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(active ? Theme.ds4Blue : Color.white.opacity(0.18))
            .frame(width: w, height: h)
    }

    private func stick(x: Double, y: Double, pressed: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 2)
                .frame(width: 64, height: 64)
            Circle()
                .fill(pressed ? Theme.ds4Blue : Color.white.opacity(0.35))
                .frame(width: 28, height: 28)
                .offset(x: CGFloat(x) * 16, y: CGFloat(-y) * 16)
        }
    }

    private func shoulder(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.caption2.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(active ? Theme.ds4Blue : Color.white.opacity(0.15), in: Capsule())
            .foregroundStyle(.white)
    }

    private func triggerBar(value: Double, label: String, active: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.8))
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.12))
                .frame(width: 50, height: 8)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(active || value > 0.05 ? Theme.ds4Blue : Color.clear)
                        .frame(width: max(2, 50 * value))
                }
        }
    }

    private func smallBtn(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(active ? Theme.ds4Blue : Color.white.opacity(0.15), in: Capsule())
            .foregroundStyle(.white)
    }
}


struct DeadzoneRing: View {
    let title: String
    let x: Double
    let y: Double
    let deadzone: Double

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption.weight(.semibold))
            ZStack {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 2)
                    .frame(width: 88, height: 88)
                Circle()
                    .strokeBorder(Theme.warn.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 88 * deadzone * 2, height: 88 * deadzone * 2)
                Circle()
                    .fill(Theme.ds4Blue)
                    .frame(width: 10, height: 10)
                    .offset(x: CGFloat(x) * 36, y: CGFloat(-y) * 36)
            }
            Text(String(format: "%+.2f, %+.2f", x, y))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.mute)
        }
    }
}
