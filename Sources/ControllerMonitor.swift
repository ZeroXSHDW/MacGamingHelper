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

/// DualSense adaptive-trigger demo modes. Each applies resistance for 2.5 s
/// then resets automatically.
enum AdaptiveTriggerDemo: String, CaseIterable, Identifiable {
    case weaponFeedback = "Weapon + feedback"
    case slope = "Slope ramp"
    case vibration = "Vibration"
    var id: String { rawValue }
}

/// PlayStation-first controller desk using Apple's Game Controller framework.
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
    private var wasConnected = false
    private var lastRediscoverRequest = Date.distantPast
    private var wakeObserver: NSObjectProtocol?
    private var handlerControllerIDs = Set<ObjectIdentifier>()
    /// Keeps a short action message ("Light bar updated") from being replaced
    /// by the 30 Hz connection status update.
    private var transientStatusUntil: Date?

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

    /// Keep pad input flowing while the user is in a game and this app is not
    /// frontmost. Without this, Mapping and the overlay can freeze the moment
    /// another app (or Steam Big Picture) takes focus.
    static func configureGameController() {
        GCController.shouldMonitorBackgroundEvents = true
    }

    func start() {
        guard !started else { return }
        started = true
        Self.configureGameController()
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
        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.statusLine = "Mac woke — rediscovering controllers…"
                    // Allow rediscover after wake even if recently scanned
                    self?.lastRediscoverRequest = .distantPast
                    self?.rediscover()
                }
            }
        }
        rediscover()
        refresh(reason: "start")
    }

    func rediscover() {
        let now = Date()
        if discovering || now.timeIntervalSince(lastRediscoverRequest) < 1.5 {
            statusLine = discovering
                ? "Scan already in progress…"
                : "Rediscover debounced — wait a moment, then try again."
            return
        }
        lastRediscoverRequest = now
        discovering = true
        lastRediscoverAt = now
        statusLine = "Scanning Bluetooth / USB for DualSense, DualShock 4 and other pads…"
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

    private func setTransientStatus(_ text: String, seconds: TimeInterval = 4) {
        statusLine = text
        transientStatusUntil = Date().addingTimeInterval(seconds)
    }

    func applyLightBar() {
        guard let controller = matchedController(for: selected.id) else { return }
        guard let light = controller.light else {
            setTransientStatus("This pad does not expose a controllable light bar.")
            return
        }
        let color = NSColor(hue: CGFloat(lightHue), saturation: 0.85, brightness: 0.95, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        light.color = GCColor(red: Float(r), green: Float(g), blue: Float(b))
        settings?.preferredLightHue = lightHue
        setTransientStatus("Light bar updated.")
    }

    /// Flash the light bar and send a short haptic pulse so the user can tell
    /// which physical pad is selected.
    func identifyController() {
        guard selected.connected else {
            statusLine = "No controller connected to identify."
            return
        }
        applyLightBar()
        pulseHaptics(.short)
        setTransientStatus("Identify sent — look for the light bar and feel the short rumble.")
    }

    /// Briefly apply adaptive-trigger resistance on a DualSense. L2 uses the
    /// weapon profile; R2 uses constant feedback. Both reset automatically.
    func pulseAdaptiveTriggers() {
        pulseAdaptiveTriggerDemo(.weaponFeedback)
    }

    func pulseAdaptiveTriggerDemo(_ demo: AdaptiveTriggerDemo) {
        guard let controller = matchedController(for: selected.id),
              let dual = controller.extendedGamepad as? GCDualSenseGamepad else {
            lastHapticNote = "Adaptive triggers need a DualSense (PS5) controller."
            setTransientStatus(lastHapticNote)
            return
        }
        let strength = Float(min(1.0, max(0.25, settings?.hapticIntensity ?? 0.7)))
        switch demo {
        case .weaponFeedback:
            dual.leftTrigger.setModeWeaponWithStartPosition(0.2, endPosition: 0.65, resistiveStrength: strength)
            dual.rightTrigger.setModeFeedbackWithStartPosition(0.25, resistiveStrength: strength * 0.85)
        case .slope:
            dual.leftTrigger.setModeSlopeFeedback(startPosition: 0.1, endPosition: 0.9, startStrength: 0.15, endStrength: strength)
            dual.rightTrigger.setModeSlopeFeedback(startPosition: 0.1, endPosition: 0.9, startStrength: strength, endStrength: 0.15)
        case .vibration:
            dual.leftTrigger.setModeVibrationWithStartPosition(0.0, amplitude: 0.3 + 0.5 * strength, frequency: 0.6)
            dual.rightTrigger.setModeVibrationWithStartPosition(0.0, amplitude: 0.25 + 0.45 * strength, frequency: 0.8)
        }
        lastHapticNote = "Adaptive triggers: \(demo.rawValue) — resets in 2.5 s."
        setTransientStatus(lastHapticNote, seconds: 3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            dual.leftTrigger.setModeOff()
            dual.rightTrigger.setModeOff()
            self?.lastHapticNote = "Adaptive triggers reset."
            self?.setTransientStatus("Adaptive triggers reset.", seconds: 3)
        }
    }

    func resetAdaptiveTriggers() {
        guard let controller = matchedController(for: selected.id),
              let dual = controller.extendedGamepad as? GCDualSenseGamepad else {
            lastHapticNote = "Adaptive triggers need a DualSense (PS5) controller."
            setTransientStatus(lastHapticNote)
            return
        }
        dual.leftTrigger.setModeOff()
        dual.rightTrigger.setModeOff()
        lastHapticNote = "Adaptive triggers reset to off."
        setTransientStatus(lastHapticNote, seconds: 3)
    }

    func pulseHaptics(_ kind: HapticPatternKind = .medium) {
        guard let controller = matchedController(for: selected.id) else { return }
        guard let haptics = controller.haptics,
              let engine = haptics.createEngine(withLocality: .all) else {
            lastHapticNote = "Haptics not available on this pad."
            setTransientStatus(lastHapticNote)
            return
        }
        do {
            try engine.start()
            let scale = Float(min(1.0, max(0.25, settings?.hapticIntensity ?? 0.7)))
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
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0.15, intensity * scale)),
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
            setTransientStatus(lastHapticNote, seconds: 3)
        } catch {
            lastHapticNote = "Haptics failed: \(error.localizedDescription)"
            setTransientStatus(lastHapticNote)
        }
    }

    private func matchedController(for id: String?) -> GCController? {
        guard let id else { return nil }
        return GCController.controllers().first { stableID(for: $0) == id }
    }

    private func stableID(for controller: GCController) -> String {
        // Stable across reconnect/sleep — do NOT use ObjectIdentifier (new GCController instance each time).
        let vendor = controller.vendorName ?? "pad"
        let cat = controller.productCategory
        let idx = controller.playerIndex.rawValue
        return "\(vendor)|\(cat)|\(idx)"
    }

    /// Give each pad a distinct 1–4 player slot. GameController leaves this
    /// unset by default; without it two identical PlayStation pads produce the
    /// same stable ID and selection/light-bar actions target the wrong one.
    private func assignPlayerIndicesIfNeeded(_ pads: [GCController]) {
        for (offset, controller) in pads.enumerated() where controller.playerIndex == .indexUnset {
            if let index = GCControllerPlayerIndex(rawValue: offset) {
                controller.playerIndex = index
            }
        }
    }

    /// Polling alone can miss a very fast button tap between 30 Hz frames.
    /// Install GameController's value-change callback so the snapshot is
    /// rebuilt the moment any button, stick, or trigger changes.
    private func installInputHandlers(for pads: [GCController]) {
        let live = Set(pads.map { ObjectIdentifier($0) })
        handlerControllerIDs.formIntersection(live)
        for controller in pads {
            let id = ObjectIdentifier(controller)
            guard !handlerControllerIDs.contains(id) else { continue }
            handlerControllerIDs.insert(id)
            controller.handlerQueue = .main
            controller.extendedGamepad?.valueChangedHandler = { [weak self] _, _ in
                Task { @MainActor in self?.refresh(reason: nil) }
            }
        }
    }

    func refresh(reason: String?) {
        let pads = GCController.controllers()
        assignPlayerIndicesIfNeeded(pads)
        installInputHandlers(for: pads)
        var next: [ControllerSnapshot] = []
        for controller in pads {
            if let snap = snapshot(from: controller) {
                next.append(snap)
            }
        }
        let previous = snapshots
        let wasEmpty = previous.isEmpty
        // Publishing at 30 Hz even when nothing changed forces SwiftUI to
        // recompute and relayout the whole window. Only notify on real change.
        let changed = next != previous
        if changed { snapshots = next }
        resolveSelection(in: next)
        if wasEmpty && !next.isEmpty {
            connectPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self, self.connectPulse else { return }
                self.connectPulse = false
            }
        }
        let nowConnected = !next.isEmpty
        let connectionChanged = nowConnected != wasConnected
        if let settings {
            if nowConnected && !wasConnected {
                GameAudio.play(.connected, settings: settings)
            } else if !nowConnected && wasConnected {
                GameAudio.play(.disconnected, settings: settings)
            }
        }
        wasConnected = nowConnected
        evaluateLowBattery(in: next)
        let nextStatus: String
        if let reason {
            if next.isEmpty {
                nextStatus = "No controller connected (\(reason)). Plug in USB-C (DualSense) or Micro-USB (DualShock 4), press PS, then Rediscover. Pairing / Setup has USB-first steps."
            } else {
                let names = next.map(\.kind.rawValue).joined(separator: ", ")
                nextStatus = "Detected \(next.count) controller(s): \(names) — \(reason)."
            }
        } else if next.isEmpty {
            transientStatusUntil = nil
            nextStatus = "Waiting for a PlayStation controller (DualSense or DualShock 4)… If the light flashes but nothing lists, use USB first (Pairing / Setup)."
        } else if let until = transientStatusUntil, until > Date() {
            nextStatus = statusLine
        } else {
            transientStatusUntil = nil
            let s = selected
            nextStatus = "\(s.kind.rawValue) connected · \(s.transportLabel) · \(s.battery)."
        }
        if statusLine != nextStatus { statusLine = nextStatus }
        if changed || reason != nil || connectionChanged {
            MenuBarController.shared.refreshTitle()
        }
    }

    private func resolveSelection(in next: [ControllerSnapshot]) {
        // Keep current id if still present.
        if let selectedID, next.contains(where: { $0.id == selectedID }) {
            if let hit = next.first(where: { $0.id == selectedID }) {
                preferredStableKey = hit.preferenceKey
                if let settings, settings.preferredPadKey != hit.preferenceKey {
                    settings.preferredPadKey = hit.preferenceKey
                }
            }
            return
        }
        // Reconnect recovery: same vendor|category preference key.
        let preferred = preferredStableKey?.isEmpty == false ? preferredStableKey : settings?.preferredPadKey
        if let preferred, !preferred.isEmpty,
           let hit = next.first(where: { $0.preferenceKey == preferred }) {
            setSelectedID(hit.id)
            return
        }
        let fallback = next.first(where: { $0.kind == .dualShock4 })?.id
            ?? next.first(where: { $0.kind == .dualSense })?.id
            ?? next.first?.id
        setSelectedID(fallback)
        if let id = fallback, let hit = next.first(where: { $0.id == id }) {
            preferredStableKey = hit.preferenceKey
            if let settings, settings.preferredPadKey != hit.preferenceKey {
                settings.preferredPadKey = hit.preferenceKey
            }
        }
    }

    /// Assigning an @Published value with the same value still emits
    /// objectWillChange, so guard every idle-path assignment.
    private func setSelectedID(_ id: String?) {
        if selectedID != id { selectedID = id }
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
            if lowBatteryBanner != text { lowBatteryBanner = text }
            if !lowBatteryAnnouncedIDs.contains(low.id) {
                lowBatteryAnnouncedIDs.insert(low.id)
                postLowBatteryNotification(text)
                if let settings {
                    GameAudio.play(.lowBattery, settings: settings)
                }
            }
        } else if lowBatteryBanner != nil {
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
        if pad.buttonOptions?.isPressed == true {
            if kind == .dualSense {
                pressed.append("Create")
            } else if kind == .dualShock4 {
                pressed.append("Share")
            } else {
                pressed.append("View")
            }
        }

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
        let transport: PadTransport
        if kind.isPlayStation, let probed = PadConnectionProbe.currentSonyTransport() {
            transport = probed
        } else {
            transport = controller.isAttachedToDevice ? .usb : .bluetooth
        }
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
            adaptiveTriggersSupported: pad is GCDualSenseGamepad,
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
        default:
            // Bluetooth pads often expose a battery object whose level is 0 or
            // stale and whose state is `.unknown`. Treat that as "connected but
            // unknown" instead of a misleading 0% low-battery warning.
            return ("Connected", nil, false)
        }
    }
}
