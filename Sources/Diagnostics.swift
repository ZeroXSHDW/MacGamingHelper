import AppKit
import ApplicationServices
import Foundation

/// Copyable support dump for Help / Settings.
enum Diagnostics {
    @MainActor
    static func dump(monitor: ControllerMonitor, mapper: InputMapper, settings: AppSettings) -> String {
        let ver = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? Theme.version
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let ax = AXIsProcessTrusted()
        let pads: String
        if monitor.snapshots.isEmpty {
            pads = "  (none)"
        } else {
            pads = monitor.snapshots.map { s in
                """
                  - \(s.kind.rawValue) | \(s.transportLabel) | \(s.vendor) | \(s.category) | player \(s.playerIndex) | \(s.battery) | motion=\(s.motionAvailable) | key=\(s.preferenceKey)
                """
            }.joined()
        }
        let rediscover = monitor.lastRediscoverDescription
        return """
        Mac Gaming Helper diagnostics
        =============================
        App: \(ver) (\(build)) · Theme.version \(Theme.version)
        macOS: \(os)
        Bundle: \(Bundle.main.bundleIdentifier ?? "?")
        Path: \(Bundle.main.bundleURL.path)

        Permissions
        -----------
        Accessibility (AXIsProcessTrusted): \(ax ? "granted" : "not granted")
        Bluetooth: pair DualShock 4 in System Settings (usage string present in Info.plist)
        Mapping enabled: \(mapper.enabled) · LIVE posting: \(mapper.isLive) · paused: \(mapper.pausedByUser)
        Active profile: \(mapper.profile.name) (\(mapper.profile.id))

        Controllers
        -----------
        Status: \(monitor.statusLine)
        Last rediscover: \(rediscover)
        Selected: \(monitor.selected.connected ? monitor.selected.title : "none")
        Pads:
        \(pads)

        Settings snapshot
        -----------------
        Menu bar: \(settings.showMenuBar)
        Start minimized: \(settings.startMinimizedToMenuBar)
        Open pairing on empty: \(settings.openPairingOnEmpty)
        Low battery alerts: \(settings.lowBatteryAlerts)
        Pause mapping when inactive: \(settings.pauseMappingWhenInactive)
        Stick deadzone: \(String(format: "%.3f", settings.stickDeadzone))
        Trigger deadzone: \(String(format: "%.3f", settings.triggerDeadzone))
        Sensitivity: \(String(format: "%.2f", settings.stickSensitivity))
        Touchpad→mouse: \(settings.touchpadAsMouse)
        Focus mode: \(settings.focusModeController)

        Generated: \(ISO8601DateFormatter().string(from: Date()))
        """
    }

    @MainActor
    static func exportToDesktop(monitor: ControllerMonitor, mapper: InputMapper, settings: AppSettings) -> URL? {
        let text = dump(monitor: monitor, mapper: mapper, settings: settings)
        let name = "MacGamingHelper-diagnostics-\(Int(Date().timeIntervalSince1970)).txt"
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop").appendingPathComponent(name)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
