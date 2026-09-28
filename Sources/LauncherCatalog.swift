import AppKit
import Foundation

struct Launcher: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let symbol: String
    let applications: [String]
    var appURL: URL?

    var isInstalled: Bool { appURL != nil }

    func located() -> Launcher {
        var copy = self
        copy.appURL = AppFinder.find(applications)
        return copy
    }
}

enum AppFinder {
    static func find(_ names: [String]) -> URL? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let dirs = [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications"),
        ]
        for dir in dirs {
            for name in names {
                let url = dir.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
        }
        return nil
    }
}

@MainActor
final class LauncherShelf: ObservableObject {
    @Published var items: [Launcher] = []
    @Published var extras: [Launcher] = []

    static let catalog: [Launcher] = [
        Launcher(
            id: "steam",
            name: "Steam",
            blurb: "Mac Steam library. Big Picture is the controller-friendly front end; Steam Input understands DualShock 4.",
            symbol: "square.stack.3d.up.fill",
            applications: ["Steam.app"],
            appURL: nil
        ),
        Launcher(
            id: "heroic",
            name: "Heroic",
            blurb: "Epic and GOG. Install a Wine / GPTK runner in Heroic before starting Windows builds.",
            symbol: "shippingbox.fill",
            applications: ["Heroic.app", "Heroic Games Launcher.app"],
            appURL: nil
        ),
        Launcher(
            id: "geforce",
            name: "GeForce NOW",
            blurb: "Cloud play for titles whose anti-cheat will not run on a Mac (e.g. modern Call of Duty).",
            symbol: "cloud.fill",
            applications: ["GeForceNOW.app", "GeForce NOW.app"],
            appURL: nil
        ),
    ]

    static let extraCatalog: [Launcher] = [
        Launcher(id: "crossover", name: "CrossOver", blurb: "Paid Wine build for many Windows games.", symbol: "wineglass", applications: ["CrossOver.app"], appURL: nil),
        Launcher(id: "whisky", name: "Whisky", blurb: "Unmaintained GPTK wrapper — leave if a game already works.", symbol: "cylinder.split.1x2", applications: ["Whisky.app"], appURL: nil),
        Launcher(id: "remoteplay", name: "PS Remote Play", blurb: "Stream a PlayStation console with the same DualShock 4.", symbol: "play.display", applications: ["PS Remote Play.app", "RemotePlay.app"], appURL: nil),
        Launcher(id: "utm", name: "UTM", blurb: "Virtual machines. Not a path for kernel anti-cheat titles.", symbol: "desktopcomputer", applications: ["UTM.app"], appURL: nil),
        Launcher(id: "gamebay", name: "Game Bay", blurb: "Earlier companion app this helper improves upon. Still installed; not deleted.", symbol: "gamecontroller", applications: ["Game Bay.app"], appURL: nil),
    ]

    func refresh() {
        items = Self.catalog.map { $0.located() }
        extras = Self.extraCatalog.map { $0.located() }
    }

    func open(_ launcher: Launcher) {
        guard let url = launcher.appURL else { return }
        NSWorkspace.shared.open(url)
    }

    func openSteamBigPicture() {
        if let url = URL(string: "steam://open/bigpicture") {
            NSWorkspace.shared.open(url)
        }
    }

    func openBluetooth() {
        let candidates = [
            "x-apple.systempreferences:com.apple.BluetoothSettings",
            "x-apple.systempreferences:com.apple.preference.bluetooth",
            "x-apple.systempreferences:com.apple.settings.Bluetooth",
        ]
        for s in candidates {
            if let url = URL(string: s), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func openXboxCloud() {
        if let url = URL(string: "https://www.xbox.com/play") {
            NSWorkspace.shared.open(url)
        }
    }
}
