import AppKit
import Foundation

/// macOS power-mode state. `pmset -g custom` reports a unified `powermode`
/// key on Apple silicon (0 = normal, 1 = Low Power, 2 = High Power); older
/// macOS uses separate `lowpowermode` / `highpowermode` keys.
enum PowerMode: String, Equatable {
    case normal = "Normal"
    case lowPower = "Low Power"
    case highPower = "High Power"
    case unknown = "Unknown"
}

struct PowerStatus: Equatable {
    var mode: PowerMode
    var modeValue: Int?
    var thermalLabel: String
    var thermalLevel: Int
}

enum SystemPower {
    static func thermal() -> (label: String, level: Int) {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return ("NOM", 0)
        case .fair: return ("FAIR", 1)
        case .serious: return ("HOT", 2)
        case .critical: return ("CRIT", 3)
        @unknown default: return ("—", 0)
        }
    }

    /// Runs `/usr/bin/pmset -g custom` (read-only, no sudo) and parses the
    /// active power mode. Returns `.unknown` if it cannot be determined.
    static func powerMode() -> (mode: PowerMode, value: Int?) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "custom"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return (.unknown, nil)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return parsePowerMode(text)
    }

    /// Pure parser, testable without spawning a process.
    static func parsePowerMode(_ text: String) -> (mode: PowerMode, value: Int?) {
        var lowPower = false
        var highPower = false
        var unified: Int?
        for rawLine in text.split(separator: "\n") {
            let parts = rawLine.trimmingCharacters(in: .whitespaces)
                .split(separator: " ").filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }
            let key = String(parts[0])
            let value = String(parts[1])
            switch key {
            case "lowpowermode":
                lowPower = value == "1" || lowPower
            case "highpowermode":
                highPower = value == "1" || highPower
            case "powermode":
                if unified == nil { unified = Int(value) }
            default:
                break
            }
        }

        if let pm = unified {
            switch pm {
            case 1: return (.lowPower, pm)
            case 2: return (.highPower, pm)
            default: return (.normal, pm)
            }
        }
        if highPower { return (.highPower, 2) }
        if lowPower { return (.lowPower, 1) }
        return (.unknown, nil)
    }

    static func snapshot() -> PowerStatus {
        let th = thermal()
        let pm = powerMode()
        return PowerStatus(
            mode: pm.mode,
            modeValue: pm.value,
            thermalLabel: th.label,
            thermalLevel: th.level
        )
    }

    static func openEnergySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Battery-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.battery",
            "x-apple.systempreferences:com.apple.Energy-Saver.extension",
        ]
        for s in urls {
            if let u = URL(string: s), NSWorkspace.shared.open(u) { return }
        }
    }
}

@MainActor
final class PowerMonitor: ObservableObject {
    static let shared = PowerMonitor()

    @Published private(set) var status: PowerStatus?
    @Published private(set) var checking = false

    func refresh() {
        guard !checking else { return }
        checking = true
        Task {
            let s = await Task.detached(priority: .utility) { SystemPower.snapshot() }.value
            status = s
            checking = false
        }
    }
}
