import AppKit
import ApplicationServices
import Combine
import Foundation

/// Optional DualShock → keyboard / mouse mapping for games that do not speak gamepads.
/// Requires Accessibility (Input Monitoring is not enough for CGEventPost).
@MainActor
final class InputMapper: ObservableObject {
    @Published var enabled = false
    @Published var profile: MappingProfile = .fpsWASD
    @Published var accessibilityTrusted = false
    @Published var lastAction: String = "Mapping idle"
    @Published var stickThreshold: Double = 0.35

    private weak var monitor: ControllerMonitor?
    private var cancellable: AnyCancellable?
    private var heldKeys = Set<UInt16>()
    private var heldMouse = Set<Int64>()
    private var lastMouseFire = Date.distantPast

    func bind(monitor: ControllerMonitor) {
        self.monitor = monitor
        accessibilityTrusted = AXIsProcessTrusted()
        cancellable = monitor.$snapshots
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.tick()
            }
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
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Enable only when trusted; otherwise leave Mapping off and surface the prompt path.
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
        lastAction = "Loaded profile “\(preset.name)”"
    }

    private func tick() {
        guard enabled else {
            releaseAll()
            return
        }
        guard accessibilityTrusted else {
            lastAction = "Enable Accessibility for Mac Gaming Helper to map keys/mouse."
            return
        }
        guard let snap = monitor?.selected, snap.connected else {
            releaseAll()
            lastAction = "No controller — mapping paused"
            return
        }

        let dz = profile.deadzone
        var wantKeys = Set<UInt16>()
        var wantMouse = Set<Int64>()
        var mouseDX: Double = 0
        var mouseDY: Double = 0

        for binding in profile.bindings {
            switch binding.target {
            case .key:
                guard let code = binding.keyCode else { continue }
                if isActive(control: binding.control, snap: snap, deadzone: dz, stickThreshold: stickThreshold) {
                    wantKeys.insert(code)
                }
            case .mouseButton:
                guard let btn = binding.mouseButton else { continue }
                if isActive(control: binding.control, snap: snap, deadzone: dz, stickThreshold: stickThreshold) {
                    wantMouse.insert(Int64(btn))
                }
            case .mouseMove:
                if binding.control == "RightStick" || binding.control == "LeftStick" {
                    let x = binding.control == "RightStick" ? snap.rx : snap.lx
                    let y = binding.control == "RightStick" ? snap.ry : snap.ly
                    if abs(x) > dz || abs(y) > dz {
                        mouseDX += x * binding.scale
                        mouseDY += -y * binding.scale
                    }
                }
            case .scroll, .none:
                break
            }
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

        if abs(mouseDX) > 0.01 || abs(mouseDY) > 0.01 {
            postMouseMove(dx: mouseDX, dy: mouseDY)
            lastAction = String(format: "Mouse Δ %.1f, %.1f · keys %d", mouseDX, mouseDY, wantKeys.count)
        } else if !wantKeys.isEmpty || !wantMouse.isEmpty {
            lastAction = "Active: \(snap.buttons.joined(separator: " "))"
        } else {
            lastAction = "Mapping on — waiting for input"
        }
    }

    private func isActive(control: String, snap: ControllerSnapshot, deadzone: Double, stickThreshold: Double) -> Bool {
        switch control {
        case "Cross", "A": return snap.buttons.contains("Cross") || snap.buttons.contains("A")
        case "Circle", "B": return snap.buttons.contains("Circle") || snap.buttons.contains("B")
        case "Square", "X": return snap.buttons.contains("Square") || snap.buttons.contains("X")
        case "Triangle", "Y": return snap.buttons.contains("Triangle") || snap.buttons.contains("Y")
        case "L1": return snap.buttons.contains("L1")
        case "R1": return snap.buttons.contains("R1")
        case "L2": return snap.lt > 0.3 || snap.buttons.contains("L2")
        case "R2": return snap.rt > 0.3 || snap.buttons.contains("R2")
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
        // Convert AppKit bottom-left to CG top-left.
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
        releaseAll()
        lastAction = "Mapping off"
    }
}
