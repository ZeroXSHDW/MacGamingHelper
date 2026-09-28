import AppKit
import CoreHaptics
import Foundation
import GameController
import SwiftUI

/// DualShock 4–first controller desk using Apple's Game Controller framework.
@MainActor
final class ControllerMonitor: ObservableObject {
    @Published var snapshots: [ControllerSnapshot] = []
    @Published var selectedID: String?
    @Published var statusLine: String = "Looking for controllers…"
    @Published var lightHue: Double = 0.55
    @Published var discovering = false

    private var timer: Timer?
    private var started = false
    private var observers: [NSObjectProtocol] = []

    var selected: ControllerSnapshot {
        if let id = selectedID, let hit = snapshots.first(where: { $0.id == id }) {
            return hit
        }
        return snapshots.first ?? .empty
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
        rediscover()
        refresh(reason: "start")
    }

    func rediscover() {
        discovering = true
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
        statusLine = "Light bar updated."
    }

    func pulseHaptics() {
        guard let controller = matchedController(for: selected.id) else { return }
        guard let haptics = controller.haptics,
              let engine = haptics.createEngine(withLocality: .all) else {
            statusLine = "Haptics not available on this pad."
            return
        }
        do {
            try engine.start()
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
                ],
                relativeTime: 0,
                duration: 0.35
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                engine.stop(completionHandler: nil)
            }
            statusLine = "Haptic pulse sent."
        } catch {
            statusLine = "Haptics failed: \(error.localizedDescription)"
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
        snapshots = next
        if let selectedID, !next.contains(where: { $0.id == selectedID }) {
            self.selectedID = next.first?.id
        } else if selectedID == nil {
            self.selectedID = next.first(where: { $0.kind == .dualShock4 })?.id
                ?? next.first(where: { $0.kind == .dualSense })?.id
                ?? next.first?.id
        }
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
        if let ds4 = pad as? GCDualShockGamepad {
            touchpad = ds4.touchpadButton.isPressed
            if touchpad { pressed.append("Touchpad") }
        } else if let dual = pad as? GCDualSenseGamepad {
            touchpad = dual.touchpadButton.isPressed
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

        return ControllerSnapshot(
            id: stableID(for: controller),
            title: title,
            vendor: vendor,
            category: category,
            kind: kind,
            battery: batteryText(controller),
            connected: true,
            buttons: pressed,
            lx: Double(pad.leftThumbstick.xAxis.value),
            ly: Double(pad.leftThumbstick.yAxis.value),
            rx: Double(pad.rightThumbstick.xAxis.value),
            ry: Double(pad.rightThumbstick.yAxis.value),
            lt: Double(pad.leftTrigger.value),
            rt: Double(pad.rightTrigger.value),
            touchpadPressed: touchpad,
            homePressed: home,
            lightBarSupported: controller.light != nil,
            playerIndex: controller.playerIndex.rawValue
        )
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

    private func batteryText(_ controller: GCController) -> String {
        guard let battery = controller.battery else { return "Battery not reported" }
        let percent = Int((battery.batteryLevel * 100).rounded())
        switch battery.batteryState {
        case .charging: return "Charging \(percent)%"
        case .full: return "Full \(percent)%"
        case .discharging: return "\(percent)%"
        default: return "Connected"
        }
    }
}
