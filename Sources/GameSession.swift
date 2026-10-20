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
            if frontmost != .none { frontmost = .none }
            if !frontmostName.isEmpty { frontmostName = "" }
            if steamInputHint { steamInputHint = false }
            return
        }
        let name = app.localizedName ?? ""
        let bundle = app.bundleIdentifier ?? ""
        let blob = "\(name) \(bundle)".lowercased()
        let kind: FrontmostKind
        let hint: Bool
        if blob.contains("geforce") || bundle.contains("nvidia") {
            kind = .geforce
            hint = false
        } else if blob.contains("heroic") {
            kind = .heroic
            hint = false
        } else if bundle == "com.valvesoftware.steam" || name == "Steam" {
            kind = .steam
            hint = true
        } else if blob.contains("steam") || bundle.contains("steam") {
            // Steam Helper / game often has steam in path or parent
            kind = .steamGame
            hint = true
        } else {
            kind = .other
            hint = false
        }
        if frontmostName != name { frontmostName = name }
        if frontmost != kind { frontmost = kind }
        if steamInputHint != hint { steamInputHint = hint }
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
        let heroic = launchers.items.first(where: { $0.id == "heroic" })
        return [
            PrepItem(id: "pad", title: "Controller seen", ok: pad.connected,
                     detail: pad.connected ? "\(pad.kind.rawValue) · \(pad.transportLabel)" : "No pad — Pairing / Rediscover"),
            PrepItem(id: "bat", title: "Battery OK (>20% or charging)", ok: batOK,
                     detail: pad.connected ? (pad.battery.isEmpty ? "Battery not reported" : pad.battery) : "—"),
            PrepItem(id: "map", title: "Mapping off for Steam Input", ok: !mapper.enabled || mapper.pausedByUser,
                     detail: mapper.enabled && !mapper.pausedByUser
                        ? "Mapping is LIVE/ARMED — pause for Steam games"
                        : "Good for Steam Input / Big Picture"),
            PrepItem(id: "steam", title: "Steam installed", ok: steam?.isInstalled == true && !SystemSupport.steamLaunchBlockedByRosetta,
                     detail: steam?.isInstalled == true
                        ? (SystemSupport.steamLaunchBlockedByRosetta ? "Needs Rosetta 2 — run softwareupdate --install-rosetta" : "Ready")
                        : (steam?.isBroken == true ? "Failed download — reinstall Steam" : "Install Steam for Big Picture")),
            PrepItem(id: "heroic", title: "Heroic installed (optional)", ok: heroic?.isInstalled == true,
                     detail: heroic?.isInstalled == true
                        ? "Epic / GOG ready"
                        : (heroic?.isBroken == true ? "Failed download — use Install Heroic" : "Install Heroic for Epic / GOG")),
        ]
    }

    static func prepSteamSession(mapper: InputMapper, launchers: LauncherShelf) {
        mapper.pauseForSteamSession()
        let settings = AppSettings.shared
        settings.gamingSessionActive = true
        settings.showOverlay = true
        settings.overlayMode = .performance
        GamingOverlayController.shared.applyVisibility()
        settings.syncKeepAwake()
        launchers.openSteamBigPicture()
    }

    static func compatCards() -> [CompatTool] {
        CompatTools.detect()
    }
}
