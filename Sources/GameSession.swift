import AppKit
import Foundation

enum FrontmostKind: String {
    case none
    case steam
    case steamGame
    case heroic
    case geforce
    case other
}

@MainActor
final class GameSession: ObservableObject {
    @Published var frontmost: FrontmostKind = .none
    @Published var frontmostName: String = ""
    @Published var steamInputHint = false

    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func refresh() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            frontmost = .none
            frontmostName = ""
            steamInputHint = false
            return
        }
        let name = app.localizedName ?? ""
        let bundle = app.bundleIdentifier ?? ""
        frontmostName = name
        let blob = "\(name) \(bundle)".lowercased()
        if blob.contains("geforce") || bundle.contains("nvidia") {
            frontmost = .geforce
            steamInputHint = false
        } else if blob.contains("heroic") {
            frontmost = .heroic
            steamInputHint = false
        } else if bundle == "com.valvesoftware.steam" || name == "Steam" {
            frontmost = .steam
            steamInputHint = true
        } else if blob.contains("steam") || bundle.contains("steam") {
            // Steam Helper / game often has steam in path or parent
            frontmost = .steamGame
            steamInputHint = true
        } else {
            frontmost = .other
            steamInputHint = false
        }
    }

    struct PrepItem: Identifiable {
        let id: String
        let title: String
        let ok: Bool
        let detail: String
    }

    static func prepItems(monitor: ControllerMonitor, mapper: InputMapper, launchers: LauncherShelf) -> [PrepItem] {
        let pad = monitor.selected
        let batOK: Bool = {
            guard pad.connected else { return false }
            if let p = pad.batteryPercent { return p > 20 || pad.batteryCharging }
            return true // unknown battery — don't fail hard
        }()
        let steam = launchers.items.first(where: { $0.id == "steam" })
        return [
            PrepItem(id: "pad", title: "Controller seen", ok: pad.connected,
                     detail: pad.connected ? "\(pad.kind.rawValue) · \(pad.transportLabel)" : "No pad — Pairing / Rediscover"),
            PrepItem(id: "bat", title: "Battery OK (>20% or charging)", ok: batOK,
                     detail: pad.connected ? (pad.battery.isEmpty ? "Battery not reported" : pad.battery) : "—"),
            PrepItem(id: "map", title: "Mapping off for Steam Input", ok: !mapper.enabled || mapper.pausedByUser,
                     detail: mapper.enabled && !mapper.pausedByUser
                        ? "Mapping is LIVE/ARMED — pause for Steam games"
                        : "Good for Steam Input / Big Picture"),
            PrepItem(id: "steam", title: "Steam installed", ok: steam?.isInstalled == true,
                     detail: steam?.isInstalled == true ? "Ready" : "Install Steam for Big Picture"),
        ]
    }

    static func prepSteamSession(mapper: InputMapper, launchers: LauncherShelf) {
        if mapper.enabled { mapper.stop() }
        launchers.openSteamBigPicture()
    }

    static func compatCards() -> [CompatTool] {
        CompatTools.detect()
    }
}
