import AppKit
import ApplicationServices
import Combine
import Foundation

/// Optional DualShock → keyboard / mouse mapping for games that do not speak gamepads.
@MainActor
final class InputMapper: ObservableObject {
    @Published var enabled = false
    @Published var profile: MappingProfile = .fpsWASD
    @Published var profiles: [MappingProfile] = MappingProfile.presets
    @Published var accessibilityTrusted = false
    @Published var lastAction: String = "Mapping idle"
    @Published var stickThreshold: Double = 0.35
    /// True while actively posting CGEvents this frame.
    @Published var isLive = false
    /// User-paused via hotkey; distinct from enabled=false.
    @Published var pausedByUser = false

    private weak var monitor: ControllerMonitor?
    private var appObservers: [NSObjectProtocol] = []
    private weak var settings: AppSettings?
    private var cancellable: AnyCancellable?
    private var heldKeys = Set<UInt16>()
    private var heldMouse = Set<Int64>()
    private var lastTouchpadX: Double?
    private var lastTouchpadY: Double?

    func bind(monitor: ControllerMonitor, settings: AppSettings) {
        self.monitor = monitor
        self.settings = settings
        accessibilityTrusted = AXIsProcessTrusted()
        reloadProfiles()
        if let match = profiles.first(where: { $0.id == settings.activeProfileID }) {
            profile = match
        }
        stickThreshold = max(settings.stickDeadzone, 0.15)
        cancellable = monitor.$snapshots
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.tick()
            }
        installAppActivityObservers()
    }

    private func installAppActivityObservers() {
        guard appObservers.isEmpty else { return }
        let center = NotificationCenter.default
        appObservers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.settings?.pauseMappingWhenInactive == true else { return }
                if self.enabled && !self.pausedByUser {
                    self.pausedByUser = true
                    self.releaseAll()
                    self.isLive = false
                    self.lastAction = "Auto-paused — app inactive (⌥⌘M to resume)"
                }
            }
        })
    }

    func togglePauseHotkey() {
        if !enabled {
            _ = enableIfTrusted()
            pausedByUser = false
            lastAction = "Mapping on"
            return
        }
        pausedByUser.toggle()
        if pausedByUser {
            releaseAll()
            isLive = false
            lastAction = "Paused (⌥⌘M)"
        } else {
            lastAction = "Resumed (⌥⌘M)"
        }
    }

    func selectProfileAtIndex(_ index: Int) {
        reloadProfiles()
        guard index >= 0, index < profiles.count else {
            lastAction = "No profile at slot \(index + 1)"
            return
        }
        selectPreset(profiles[index])
        lastAction = "Profile \(index + 1): \(profiles[index].name)"
    }

    func reloadProfiles() {
        profiles = ProfileStore.loadAll()
    }

    func refreshTrust() {
        accessibilityTrusted = AXIsProcessTrusted()
    }

    func promptAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityTrusted = AXIsProcessTrustedWithOptions(opts)
    }

    func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        ]
        for s in candidates {
            if let url = URL(string: s), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func enableIfTrusted() -> Bool {
        refreshTrust()
        if accessibilityTrusted {
            enabled = true
            lastAction = "Mapping on"
            return true
        }
        promptAccessibility()
        refreshTrust()
        if accessibilityTrusted {
            enabled = true
            lastAction = "Mapping on"
            return true
        }
        enabled = false
        lastAction = "Accessibility denied — Mapping stays off. Open Accessibility, enable Mac Gaming Helper, then Recheck."
        return false
    }

    func selectPreset(_ preset: MappingProfile) {
        profile = preset
        settings?.activeProfileID = preset.id
        lastAction = "Loaded profile “\(preset.name)”"
    }

    func saveCurrentProfile() {
        do {
            try ProfileStore.save(profile)
            reloadProfiles()
            settings?.activeProfileID = profile.id
            lastAction = "Saved “\(profile.name)”"
        } catch {
            lastAction = "Save failed: \(error.localizedDescription)"
        }
    }

    func duplicateAsCustom(named name: String) {
        let copy = profile.duplicating(name: name)
        profile = copy
        saveCurrentProfile()
    }

    func deleteCurrentIfCustom() {
        guard !ProfileStore.isPreset(profile.id) else {
            lastAction = "Built-in presets cannot be deleted."
            return
        }
        do {
            try ProfileStore.delete(id: profile.id)
            reloadProfiles()
            profile = .fpsWASD
            settings?.activeProfileID = profile.id
            lastAction = "Deleted custom profile."
        } catch {
            lastAction = "Delete failed: \(error.localizedDescription)"
        }
    }

    func updateBindingKey(control: String, code: UInt16, name: String) {
        if let idx = profile.bindings.firstIndex(where: { $0.control == control && $0.target == .key }) {
            profile.bindings[idx].keyCode = code
            profile.bindings[idx].keyName = name
        } else {
            profile.bindings.append(.key(control, code: code, name: name))
        }
    }

    private func tick() {
        guard enabled else {
            releaseAll()
            isLive = false
            lastTouchpadX = nil
            lastTouchpadY = nil
            return
        }
        if pausedByUser {
            releaseAll()
            isLive = false
            return
        }
        guard accessibilityTrusted else {
            lastAction = "Enable Accessibility for Mac Gaming Helper to map keys/mouse."
            isLive = false
            return
        }
        guard let snap = monitor?.selected, snap.connected else {
            releaseAll()
            lastAction = "No controller — mapping paused"
            return
        }

        let settingsDZ = settings?.stickDeadzone ?? profile.deadzone
        let trigDZ = settings?.triggerDeadzone ?? 0.08
        let sens = settings?.stickSensitivity ?? 1.0
        let dz = max(settingsDZ, profile.deadzone * 0.5)
        let thresh = max(stickThreshold, dz)

        var wantKeys = Set<UInt16>()
        var wantMouse = Set<Int64>()
        var mouseDX: Double = 0
        var mouseDY: Double = 0

        for binding in profile.bindings {
            switch binding.target {
            case .key:
                guard let code = binding.keyCode else { continue }
                if isActive(control: binding.control, snap: snap, deadzone: dz, stickThreshold: thresh, triggerDeadzone: trigDZ) {
                    wantKeys.insert(code)
                }
            case .mouseButton:
                guard let btn = binding.mouseButton else { continue }
                if isActive(control: binding.control, snap: snap, deadzone: dz, stickThreshold: thresh, triggerDeadzone: trigDZ) {
                    wantMouse.insert(Int64(btn))
                }
            case .mouseMove:
                if binding.control == "RightStick" || binding.control == "LeftStick" {
                    let rawX = binding.control == "RightStick" ? snap.rx : snap.lx
                    let rawY = binding.control == "RightStick" ? snap.ry : snap.ly
                    let curve = settings?.stickCurve ?? .linear
                    let sx = StickMath.shaped(value: rawX, deadzone: dz, curve: curve)
                    var sy = StickMath.shaped(value: rawY, deadzone: dz, curve: curve)
                    if settings?.invertLookY == true { sy = -sy }
                    let aim = (settings?.aimSensitivity ?? 1.0) * sens
                    if abs(sx) > 0.001 || abs(sy) > 0.001 {
                        mouseDX += sx * binding.scale * aim
                        mouseDY += -sy * binding.scale * aim
                    }
                }
            case .scroll, .none:
                break
            }
        }

        // Optional DualShock touchpad → mouse
        if settings?.touchpadAsMouse == true {
            if snap.touchpadPressed {
                wantMouse.insert(0) // left click
            }
            let tx = snap.touchpadX
            let ty = snap.touchpadY
            if abs(tx) > 0.02 || abs(ty) > 0.02 {
                if let lx = lastTouchpadX, let ly = lastTouchpadY {
                    mouseDX += (tx - lx) * 28 * sens
                    mouseDY += -(ty - ly) * 28 * sens
                }
                lastTouchpadX = tx
                lastTouchpadY = ty
            } else {
                lastTouchpadX = nil
                lastTouchpadY = nil
            }
        }

        // Optional gyro assist → mouse (only when motion exposed; never faked)
        if settings?.gyroAssistMouse == true, snap.motionAvailable {
            let gx = snap.roll * 6 * (settings?.aimSensitivity ?? 1)
            let gy = snap.pitch * 6 * (settings?.aimSensitivity ?? 1) * (settings?.invertLookY == true ? -1 : 1)
            mouseDX += gx
            mouseDY += gy
        }

        for code in wantKeys where !heldKeys.contains(code) {
            postKey(code, down: true)
        }
        for code in heldKeys where !wantKeys.contains(code) {
            postKey(code, down: false)
        }
        heldKeys = wantKeys

        for btn in wantMouse where !heldMouse.contains(btn) {
            postMouseButton(btn, down: true)
        }
        for btn in heldMouse where !wantMouse.contains(btn) {
            postMouseButton(btn, down: false)
        }
        heldMouse = wantMouse

        let live = !wantKeys.isEmpty || !wantMouse.isEmpty || abs(mouseDX) > 0.01 || abs(mouseDY) > 0.01
        isLive = live
        if abs(mouseDX) > 0.01 || abs(mouseDY) > 0.01 {
            postMouseMove(dx: mouseDX, dy: mouseDY)
            lastAction = String(format: "LIVE mouse Δ %.1f, %.1f · keys %d", mouseDX, mouseDY, wantKeys.count)
        } else if !wantKeys.isEmpty || !wantMouse.isEmpty {
            lastAction = "LIVE: \(snap.buttons.joined(separator: " "))"
        } else {
            lastAction = "Mapping armed — waiting for input"
        }
    }

    private func isActive(control: String, snap: ControllerSnapshot, deadzone: Double, stickThreshold: Double, triggerDeadzone: Double) -> Bool {
        switch control {
        case "Cross", "A": return snap.buttons.contains("Cross") || snap.buttons.contains("A")
        case "Circle", "B": return snap.buttons.contains("Circle") || snap.buttons.contains("B")
        case "Square", "X": return snap.buttons.contains("Square") || snap.buttons.contains("X")
        case "Triangle", "Y": return snap.buttons.contains("Triangle") || snap.buttons.contains("Y")
        case "L1": return snap.buttons.contains("L1")
        case "R1": return snap.buttons.contains("R1")
        case "L2":
            let thr = (settings?.hairTrigger == true)
                ? max(0.05, settings?.hairTriggerThreshold ?? 0.12)
                : max(0.3, triggerDeadzone)
            return snap.lt > thr || snap.buttons.contains("L2")
        case "R2":
            let thr = (settings?.hairTrigger == true)
                ? max(0.05, settings?.hairTriggerThreshold ?? 0.12)
                : max(0.3, triggerDeadzone)
            return snap.rt > thr || snap.buttons.contains("R2")
        case "L3": return snap.buttons.contains("L3")
        case "R3": return snap.buttons.contains("R3")
        case "Up": return snap.buttons.contains("Up")
        case "Down": return snap.buttons.contains("Down")
        case "Left": return snap.buttons.contains("Left")
        case "Right": return snap.buttons.contains("Right")
        case "Options", "Menu": return snap.buttons.contains("Options") || snap.buttons.contains("Menu")
        case "Share", "View": return snap.buttons.contains("Share") || snap.buttons.contains("View")
        case "Touchpad": return snap.touchpadPressed || snap.buttons.contains("Touchpad")
        case "PS", "Home": return snap.homePressed || snap.buttons.contains("PS") || snap.buttons.contains("Home")
        case "LeftStickUp": return snap.ly > stickThreshold
        case "LeftStickDown": return snap.ly < -stickThreshold
        case "LeftStickLeft": return snap.lx < -stickThreshold
        case "LeftStickRight": return snap.lx > stickThreshold
        case "RightStickUp": return snap.ry > stickThreshold
        case "RightStickDown": return snap.ry < -stickThreshold
        case "RightStickLeft": return snap.rx < -stickThreshold
        case "RightStickRight": return snap.rx > stickThreshold
        default:
            return snap.buttons.contains(control)
        }
    }

    private func postKey(_ code: UInt16, down: Bool) {
        let src = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down)
        event?.post(tap: .cghidEventTap)
    }

    private func postMouseButton(_ button: Int64, down: Bool) {
        let loc = NSEvent.mouseLocation
        let screenH = NSScreen.main?.frame.height ?? 0
        let point = CGPoint(x: loc.x, y: screenH - loc.y)
        let type: CGEventType
        let btn: CGMouseButton
        switch button {
        case 1:
            type = down ? .rightMouseDown : .rightMouseUp
            btn = .right
        default:
            type = down ? .leftMouseDown : .leftMouseUp
            btn = .left
        }
        let src = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: point, mouseButton: btn)
        event?.post(tap: .cghidEventTap)
    }

    private func postMouseMove(dx: Double, dy: Double) {
        let loc = NSEvent.mouseLocation
        let screenH = NSScreen.main?.frame.height ?? 0
        let point = CGPoint(x: loc.x + dx, y: (screenH - loc.y) + dy)
        let src = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }

    private func releaseAll() {
        for code in heldKeys { postKey(code, down: false) }
        for btn in heldMouse { postMouseButton(btn, down: false) }
        heldKeys.removeAll()
        heldMouse.removeAll()
    }

    func stop() {
        enabled = false
        pausedByUser = false
        isLive = false
        releaseAll()
        lastAction = "Mapping off"
    }
}
