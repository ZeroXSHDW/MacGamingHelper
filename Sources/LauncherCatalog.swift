import AppKit
import Foundation

struct Launcher: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let symbol: String
    let applications: [String]
    var bundleIdentifiers: [String] = []
    var installURL: URL? = nil
    var installCommand: String? = nil
    /// A launcher found on disk that is not a usable app bundle (usually a
    /// failed download saved as `<name>.app` HTML). Surfaced in the UI so it
    /// can be repaired instead of silently looking “installed”.
    var brokenURL: URL? = nil
    var appURL: URL? = nil

    var isInstalled: Bool { appURL != nil }
    var isBroken: Bool { brokenURL != nil }

    func located() -> Launcher {
        var copy = self
        copy.appURL = AppFinder.find(applications, bundleIdentifiers: bundleIdentifiers)
        if copy.appURL == nil {
            copy.brokenURL = AppFinder.findBroken(applications)
        }
        return copy
    }
}

enum AppFinder {
    private static var searchDirectories: [URL] {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        return [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications"),
        ]
    }

    /// A real macOS app is a directory with a valid Info.plist and an
    /// executable. An HTML error page saved as `.app` fails all three.
    static func isValidBundle(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        let plist = url.appendingPathComponent("Contents/Info.plist")
        guard FileManager.default.fileExists(atPath: plist.path),
              let data = try? Data(contentsOf: plist),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let executable = info["CFBundleExecutable"] as? String,
              !executable.isEmpty
        else { return false }
        let binary = url.appendingPathComponent("Contents/MacOS/\(executable)")
        return FileManager.default.isExecutableFile(atPath: binary.path)
    }

    static func find(_ names: [String], bundleIdentifiers: [String] = []) -> URL? {
        for dir in searchDirectories {
            for name in names {
                let url = dir.appendingPathComponent(name)
                if isValidBundle(url) { return url }
            }
        }
        // Spotlight-independent fallback: lets Heroic.app found in a custom
        // folder (or the vendor-named Heroic-Games-Launcher.app) still be
        // recognised by bundle identifier.
        for identifier in bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier),
               isValidBundle(url) {
                return url
            }
        }
        return nil
    }

    /// Locate a same-named artifact that is *not* a usable app bundle, so the
    /// UI can explain the failed install rather than claim “Not found”.
    static func findBroken(_ names: [String]) -> URL? {
        for dir in searchDirectories {
            for name in names {
                let url = dir.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: url.path), !isValidBundle(url) {
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
            blurb: "Mac Steam library. Big Picture is the controller-friendly front end; Steam Input understands PlayStation pads.",
            symbol: "square.stack.3d.up.fill",
            applications: ["Steam.app"],
            bundleIdentifiers: ["com.valvesoftware.steam"],
            installURL: URL(string: "https://store.steampowered.com/about/"),
            installCommand: "brew install --cask steam",
            appURL: nil
        ),
        Launcher(
            id: "heroic",
            name: "Heroic",
            blurb: "Epic and GOG. Install a Wine / GPTK runner in Heroic before starting Windows builds.",
            symbol: "shippingbox.fill",
            applications: ["Heroic.app", "Heroic Games Launcher.app", "Heroic-Games-Launcher.app"],
            bundleIdentifiers: ["com.heroicgameslauncher.hgl"],
            installURL: URL(string: "https://heroicgameslauncher.com/"),
            installCommand: "brew install --cask heroic",
            appURL: nil
        ),
        Launcher(
            id: "geforce",
            name: "GeForce NOW",
            blurb: "Cloud play for titles whose anti-cheat will not run on a Mac (e.g. modern Call of Duty).",
            symbol: "cloud.fill",
            applications: ["GeForceNOW.app", "GeForce NOW.app"],
            bundleIdentifiers: ["com.nvidia.gfnpc.mall", "com.nvidia.GeForceNOW"],
            installURL: URL(string: "https://www.nvidia.com/en-us/geforce-now/download/"),
            installCommand: "brew install --cask nvidia-geforce-now",
            appURL: nil
        ),
    ]

    static let extraCatalog: [Launcher] = [
        Launcher(id: "crossover", name: "CrossOver", blurb: "Paid Wine build for many Windows games.", symbol: "wineglass", applications: ["CrossOver.app"], bundleIdentifiers: ["com.codeweavers.CrossOver"], installURL: URL(string: "https://www.codeweavers.com/crossover"), appURL: nil),
        Launcher(id: "whisky", name: "Whisky", blurb: "Unmaintained GPTK wrapper — leave if a game already works.", symbol: "cylinder.split.1x2", applications: ["Whisky.app"], bundleIdentifiers: ["com.isaacmarovitz.Whisky"], appURL: nil),
        Launcher(id: "remoteplay", name: "PS Remote Play", blurb: "Stream a PlayStation console with the same DualShock 4.", symbol: "play.display", applications: ["PS Remote Play.app", "RemotePlay.app"], bundleIdentifiers: ["com.playstation.RemotePlay"], installURL: URL(string: "https://remoteplay.dl.playstation.net/remoteplay/"), appURL: nil),
        Launcher(id: "utm", name: "UTM", blurb: "Virtual machines. Not a path for kernel anti-cheat titles.", symbol: "desktopcomputer", applications: ["UTM.app"], bundleIdentifiers: ["com.utmapp.UTM"], installURL: URL(string: "https://mac.getutm.app/"), appURL: nil),
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

    func openInstallPage(_ launcher: Launcher) {
        guard let url = launcher.installURL else { return }
        NSWorkspace.shared.open(url)
    }

    func copyInstallCommand(_ launcher: Launcher) {
        guard let command = launcher.installCommand else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    func copyRosettaCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(SystemSupport.rosettaInstallCommand, forType: .string)
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
