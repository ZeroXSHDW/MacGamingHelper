import AppKit
import CoreHaptics
import Foundation
import GameController
import SwiftUI
import UserNotifications

enum HapticPatternKind: String, CaseIterable, Identifiable {
    case short, medium, rumble
    var id: String { rawValue }
    var title: String {
        switch self {
        case .short: return "Short"
        case .medium: return "Medium"
        case .rumble: return "Rumble"
        }
    }
}

/// DualShock 4–first controller desk using Apple's Game Controller framework.
@MainActor
final class ControllerMonitor: ObservableObject {
    @Published var snapshots: [ControllerSnapshot] = []
    @Published var selectedID: String?
    @Published var statusLine: String = "Looking for controllers…"
    @Published var lightHue: Double = 0.55
    @Published var discovering = false
    @Published var lowBatteryBanner: String?
    @Published var lastHapticNote: String = ""
    @Published var lastRediscoverAt: Date?
    @Published var connectPulse = false

    private var timer: Timer?
    private var started = false
    private var observers: [NSObjectProtocol] = []
    private var lowBatteryAnnouncedIDs = Set<String>()
    private weak var settings: AppSettings?
    private var preferredStableKey: String?

    var lastRediscoverDescription: String {
        guard let d = lastRediscoverAt else { return "never" }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f.string(from: d)
    }

    var selected: ControllerSnapshot {
        if let id = selectedID, let hit = snapshots.first(where: { $0.id == id }) {
            return hit
        }
        return snapshots.first ?? .empty
    }

    func attach(settings: AppSettings) {
        self.settings = settings
        lightHue = settings.preferredLightHue
    }

    func start() {
        guard !started else { return }
        started = true
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh(reason: "connected") }
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh(reason: "disconnected") }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(reason: nil) }
        }
        requestNotificationPermission()
        rediscover()
        refresh(reason: "start")
    }

    func rediscover() {
        discovering = true
        lastRediscoverAt = Date()
        statusLine = "Scanning Bluetooth / USB for DualShock 4 and other pads…"
        GCController.stopWirelessControllerDiscovery()
        GCController.startWirelessControllerDiscovery { [weak self] in
            Task { @MainActor in
                self?.discovering = false
                self?.refresh(reason: "scan finished")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self, self.discovering else { return }
            GCController.stopWirelessControllerDiscovery()
            self.discovering = false
            self.refresh(reason: "scan timed out")
        }
    }

    func applyLightBar() {
        guard let controller = matchedController(for: selected.id) else { return }
        guard let light = controller.light else {
            statusLine = "This pad does not expose a controllable light bar."
            return
        }
        let color = NSColor(hue: CGFloat(lightHue), saturation: 0.85, brightness: 0.95, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        light.color = GCColor(red: Float(r), green: Float(g), blue: Float(b))
        settings?.preferredLightHue = lightHue
        statusLine = "Light bar updated."
    }

    func pulseHaptics(_ kind: HapticPatternKind = .medium) {
        guard let controller = matchedController(for: selected.id) else { return }
        guard let haptics = controller.haptics,
              let engine = haptics.createEngine(withLocality: .all) else {
            lastHapticNote = "Haptics not available on this pad."
            statusLine = lastHapticNote
            return
        }
        do {
            try engine.start()
            let (intensity, sharpness, duration): (Float, Float, TimeInterval) = {
                switch kind {
                case .short: return (0.85, 0.7, 0.12)
                case .medium: return (0.7, 0.4, 0.35)
                case .rumble: return (0.95, 0.25, 0.85)
                }
            }()
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ],
                relativeTime: 0,
                duration: duration
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.2) {
                engine.stop(completionHandler: nil)
            }
            lastHapticNote = "\(kind.title) haptic sent."
            statusLine = lastHapticNote
        } catch {
            lastHapticNote = "Haptics failed: \(error.localizedDescription)"
            statusLine = lastHapticNote
        }
    }

    private func matchedController(for id: String?) -> GCController? {
        guard let id else { return nil }
        return GCController.controllers().first { stableID(for: $0) == id }
    }

    private func stableID(for controller: GCController) -> String {
        let vendor = controller.vendorName ?? "pad"
        let cat = controller.productCategory
        let idx = controller.playerIndex.rawValue
        return "\(vendor)|\(cat)|\(idx)|\(ObjectIdentifier(controller).hashValue)"
    }

    func refresh(reason: String?) {
        let pads = GCController.controllers()
        var next: [ControllerSnapshot] = []
        for controller in pads {
            if let snap = snapshot(from: controller) {
                next.append(snap)
            }
        }
        let wasEmpty = snapshots.isEmpty
        snapshots = next
        resolveSelection(in: next)
        if wasEmpty && !next.isEmpty {
            connectPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.connectPulse = false
            }
        }
        evaluateLowBattery(in: next)
        if let reason {
            if next.isEmpty {
                statusLine = "No controller connected (\(reason)). Try USB Micro-USB + PS, or Share+PS → Bluetooth → Rediscover. See Pairing / Setup."
            } else {
                let names = next.map(\.kind.rawValue).joined(separator: ", ")
                statusLine = "\(next.count) controller(s): \(names) · \(reason)"
            }
        } else if next.isEmpty {
            statusLine = "Waiting for a DualShock 4… If lights flash but nothing lists, use USB first (Pairing / Setup)."
        }
        MenuBarController.shared.refreshTitle()
    }

    private func resolveSelection(in next: [ControllerSnapshot]) {
        // Keep current id if still present.
        if let selectedID, next.contains(where: { $0.id == selectedID }) {
            if let hit = next.first(where: { $0.id == selectedID }) {
                preferredStableKey = hit.preferenceKey
                settings?.preferredPadKey = hit.preferenceKey
            }
            return
        }
        // Reconnect recovery: same vendor|category preference key.
        let preferred = preferredStableKey?.isEmpty == false ? preferredStableKey : settings?.preferredPadKey
        if let preferred, !preferred.isEmpty,
           let hit = next.first(where: { $0.preferenceKey == preferred }) {
            selectedID = hit.id
            return
        }
        selectedID = next.first(where: { $0.kind == .dualShock4 })?.id
            ?? next.first(where: { $0.kind == .dualSense })?.id
            ?? next.first?.id
        if let id = selectedID, let hit = next.first(where: { $0.id == id }) {
            preferredStableKey = hit.preferenceKey
            settings?.preferredPadKey = hit.preferenceKey
        }
    }

    func selectPad(_ snap: ControllerSnapshot) {
        selectedID = snap.id
        preferredStableKey = snap.preferenceKey
        settings?.preferredPadKey = snap.preferenceKey
    }

    /// Sample sticks at rest and suggest a deadzone (stretch calibration).
    func suggestDeadzoneFromCenter(samples: Int = 20) -> Double {
        guard selected.connected else { return settings?.stickDeadzone ?? 0.12 }
        var peak: Double = 0
        // Use current reading as a single-frame sample helper; caller may average.
        peak = max(abs(selected.lx), abs(selected.ly), abs(selected.rx), abs(selected.ry))
        let suggested = min(0.40, max(0.06, peak + 0.04))
        return suggested
    }

    private func evaluateLowBattery(in snaps: [ControllerSnapshot]) {
        guard settings?.lowBatteryAlerts != false else {
            lowBatteryBanner = nil
            return
        }
        let connectedIDs = Set(snaps.map(\.id))
        lowBatteryAnnouncedIDs = lowBatteryAnnouncedIDs.intersection(connectedIDs)
        if let low = snaps.first(where: { snap in
            guard let p = snap.batteryPercent, !snap.batteryCharging else { return false }
            return p <= 20
        }) {
            let text = "Low battery: \(low.kind.rawValue) at \(low.batteryPercent ?? 0)%"
            lowBatteryBanner = text
            if !lowBatteryAnnouncedIDs.contains(low.id) {
                lowBatteryAnnouncedIDs.insert(low.id)
                postLowBatteryNotification(text)
            }
        } else {
            lowBatteryBanner = nil
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postLowBatteryNotification(_ body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Mac Gaming Helper"
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: "low-battery-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    private func snapshot(from controller: GCController) -> ControllerSnapshot? {
        guard let pad = controller.extendedGamepad else { return nil }
        let vendor = controller.vendorName ?? ""
        let category = controller.productCategory
        let kind = classify(vendor: vendor, category: category, pad: pad)
        let face = kind.face
        var pressed: [String] = []

        if pad.buttonA.isPressed { pressed.append(face.a) }
        if pad.buttonB.isPressed { pressed.append(face.b) }
        if pad.buttonX.isPressed { pressed.append(face.x) }
        if pad.buttonY.isPressed { pressed.append(face.y) }
        if pad.leftShoulder.isPressed { pressed.append("L1") }
        if pad.rightShoulder.isPressed { pressed.append("R1") }
        if pad.leftTrigger.isPressed { pressed.append("L2") }
        if pad.rightTrigger.isPressed { pressed.append("R2") }
        if pad.dpad.up.isPressed { pressed.append("Up") }
        if pad.dpad.down.isPressed { pressed.append("Down") }
        if pad.dpad.left.isPressed { pressed.append("Left") }
        if pad.dpad.right.isPressed { pressed.append("Right") }
        if pad.leftThumbstickButton?.isPressed == true { pressed.append("L3") }
        if pad.rightThumbstickButton?.isPressed == true { pressed.append("R3") }
        if pad.buttonMenu.isPressed { pressed.append(kind.isPlayStation ? "Options" : "Menu") }
        if pad.buttonOptions?.isPressed == true { pressed.append(kind.isPlayStation ? "Share" : "View") }

        var touchpad = false
        var tpx: Double = 0
        var tpy: Double = 0
        if let ds4 = pad as? GCDualShockGamepad {
            touchpad = ds4.touchpadButton.isPressed
            tpx = Double(ds4.touchpadPrimary.xAxis.value)
            tpy = Double(ds4.touchpadPrimary.yAxis.value)
            if touchpad { pressed.append("Touchpad") }
        } else if let dual = pad as? GCDualSenseGamepad {
            touchpad = dual.touchpadButton.isPressed
            tpx = Double(dual.touchpadPrimary.xAxis.value)
            tpy = Double(dual.touchpadPrimary.yAxis.value)
            if touchpad { pressed.append("Touchpad") }
        }

        var home = false
        if let homeBtn = pad.buttonHome {
            home = homeBtn.isPressed
            if home { pressed.append(kind.isPlayStation ? "PS" : "Home") }
        }

        let title: String
        if !vendor.isEmpty {
            title = "\(vendor) · \(kind.rawValue)"
        } else if !category.isEmpty {
            title = "\(category) · \(kind.rawValue)"
        } else {
            title = kind.rawValue
        }

        let (batText, batPct, charging) = batteryInfo(controller)
        let transport: PadTransport = controller.isAttachedToDevice ? .usb : .bluetooth
        let pref = "\(vendor)|\(category)|\(kind.rawValue)"
        let motion = readMotion(controller)

        return ControllerSnapshot(
            id: stableID(for: controller),
            title: title,
            vendor: vendor,
            category: category,
            kind: kind,
            battery: batText,
            batteryPercent: batPct,
            batteryCharging: charging,
            connected: true,
            buttons: pressed,
            lx: Double(pad.leftThumbstick.xAxis.value),
            ly: Double(pad.leftThumbstick.yAxis.value),
            rx: Double(pad.rightThumbstick.xAxis.value),
            ry: Double(pad.rightThumbstick.yAxis.value),
            lt: Double(pad.leftTrigger.value),
            rt: Double(pad.rightTrigger.value),
            touchpadPressed: touchpad,
            touchpadX: tpx,
            touchpadY: tpy,
            homePressed: home,
            lightBarSupported: controller.light != nil,
            hapticsSupported: controller.haptics != nil,
            playerIndex: controller.playerIndex.rawValue,
            transport: transport,
            preferenceKey: pref,
            motionAvailable: motion.available,
            motionNote: motion.note,
            gravityX: motion.gx, gravityY: motion.gy, gravityZ: motion.gz,
            pitch: motion.pitch, yaw: motion.yaw, roll: motion.roll
        )
    }

    private func readMotion(_ controller: GCController) -> (available: Bool, note: String, gx: Double, gy: Double, gz: Double, pitch: Double, yaw: Double, roll: Double) {
        guard let motion = controller.motion else {
            return (false, "Motion / gyro not exposed by Game Controller for this pad on macOS.", 0, 0, 0, 0, 0, 0)
        }
        if motion.valueChangedHandler == nil {
            motion.valueChangedHandler = { _ in }
        }
        let g = motion.gravity
        let attitudeOK = motion.hasAttitude || motion.hasRotationRate
        if !attitudeOK && abs(g.x) < 0.001 && abs(g.y) < 0.001 && abs(g.z) < 0.001 {
            return (false, "GCMotion present but attitude/rotation not available for this DualShock connection.", 0, 0, 0, 0, 0, 0)
        }
        var pitch = 0.0, yaw = 0.0, roll = 0.0
        if attitudeOK || abs(g.x) + abs(g.y) + abs(g.z) > 0.05 {
            pitch = atan2(g.y, max(0.0001, g.z))
            roll = atan2(-g.x, sqrt(g.y * g.y + g.z * g.z))
            yaw = 0
        }
        let note = attitudeOK
            ? "Motion exposed (gravity + attitude flags). Yaw not synthesized."
            : "Gravity vector readable — full gyro attitude not flagged for this pad."
        return (true, note, Double(g.x), Double(g.y), Double(g.z), pitch, yaw, roll)
    }

    private func classify(vendor: String, category: String, pad: GCExtendedGamepad) -> PadKind {
        if pad is GCDualShockGamepad { return .dualShock4 }
        if pad is GCDualSenseGamepad { return .dualSense }
        let blob = "\(vendor) \(category)".lowercased()
        if blob.contains("dualshock") || blob.contains("dual shock") { return .dualShock4 }
        if blob.contains("dualsense") || blob.contains("dual sense") { return .dualSense }
        if blob.contains("xbox") || blob.contains("microsoft") { return .xbox }
        if blob.contains("sony") || blob.contains("playstation") {
            if blob.contains("wireless controller") { return .dualShock4 }
            return .dualSense
        }
        if blob.contains("dual") { return .dualShock4 }
        return .generic
    }

    private func batteryInfo(_ controller: GCController) -> (String, Int?, Bool) {
        guard let battery = controller.battery else { return ("Battery not reported", nil, false) }
        let percent = Int((battery.batteryLevel * 100).rounded())
        switch battery.batteryState {
        case .charging: return ("Charging \(percent)%", percent, true)
        case .full: return ("Full \(percent)%", percent, false)
        case .discharging: return ("\(percent)%", percent, false)
        default: return ("Connected", percent, false)
        }
    }
}
