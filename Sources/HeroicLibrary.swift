import AppKit
import Foundation

struct HeroicGame: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let store: String
    let detail: String
    let appName: String
}

@MainActor
final class HeroicShelf: ObservableObject {
    @Published var games: [HeroicGame] = []
    @Published var note: String = ""
    @Published var appInstalled = false

    /// Heroic 2.x stores installed-game manifests under
    /// `~/Library/Application Support/heroic/store_cache/`. Older builds and
    /// the CLI legendary client used the `.config` paths, so both are read.
    static func manifestPaths(home: URL = URL(fileURLWithPath: NSHomeDirectory())) -> [(URL, String)] {
        let support = home.appendingPathComponent("Library/Application Support/heroic")
        return [
            (support.appendingPathComponent("store_cache/legendary_install_info.json"), "Epic"),
            (support.appendingPathComponent("store_cache/gog_install_info.json"), "GOG"),
            (support.appendingPathComponent("store_cache/nile_install_info.json"), "Amazon"),
            (support.appendingPathComponent("sideload_apps/library.json"), "Heroic"),
            (support.appendingPathComponent("gog_store/installed.json"), "GOG"),

            (home.appendingPathComponent(".config/heroic/store_cache/legendary_install_info.json"), "Epic"),
            (home.appendingPathComponent(".config/heroic/store_cache/gog_install_info.json"), "GOG"),
            (home.appendingPathComponent(".config/heroic/store_cache/nile_install_info.json"), "Amazon"),
            (home.appendingPathComponent(".config/heroic/sideload_apps/library.json"), "Heroic"),
            (home.appendingPathComponent(".config/heroic/gog_store/installed.json"), "GOG"),
            (home.appendingPathComponent(".config/legendary/installed.json"), "Epic"),
            (home.appendingPathComponent("Library/Application Support/legendary/installed.json"), "Epic"),
        ]
    }

    func refresh() {
        appInstalled = AppFinder.find(
            ["Heroic.app", "Heroic Games Launcher.app", "Heroic-Games-Launcher.app"],
            bundleIdentifiers: ["com.heroicgameslauncher.hgl"]
        ) != nil

        var list: [HeroicGame] = []
        var seen = Set<String>()
        for (url, store) in Self.manifestPaths() {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            collect(json, store: store, into: &list, seen: &seen)
        }
        list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        games = list

        if !list.isEmpty {
            note = "\(list.count) installed Heroic/Epic/GOG title(s)."
        } else if appInstalled {
            note = "Heroic is installed — no Epic / GOG / Amazon titles installed yet."
        } else {
            note = "Heroic is not installed. Use Install on the Launchers page, or run scripts/install-heroic.sh."
        }
    }

    private func collect(_ json: Any, store: String, into list: inout [HeroicGame], seen: inout Set<String>) {
        if let arr = json as? [Any] {
            for item in arr { collect(item, store: store, into: &list, seen: &seen) }
            return
        }
        guard let dict = json as? [String: Any] else { return }
        let title = (dict["title"] as? String) ?? (dict["name"] as? String)
        if let title, !title.isEmpty {
            let path = (dict["install_path"] as? String) ?? (dict["folder_name"] as? String) ?? ""
            let appName = (dict["app_name"] as? String) ?? (dict["appName"] as? String) ?? title
            let key = "\(store)-\(appName)"
            if seen.insert(key).inserted {
                list.append(HeroicGame(id: key, name: title, store: store, detail: path.isEmpty ? store : path, appName: appName))
            }
            return
        }
        for value in dict.values {
            collect(value, store: store, into: &list, seen: &seen)
        }
    }

    static func deepLinkURL(for appName: String) -> URL? {
        let encoded = appName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? appName
        guard !encoded.isEmpty else { return nil }
        return URL(string: "heroic://launch/\(encoded)")
    }

    func launch(_ game: HeroicGame, launchers: LauncherShelf) {
        // Best-effort deep link first: heroic://launch/<app_name>
        if let deep = Self.deepLinkURL(for: game.appName), NSWorkspace.shared.open(deep) {
            return
        }
        // Fallback: open Heroic itself.
        if let heroic = launchers.items.first(where: { $0.id == "heroic" }), heroic.isInstalled {
            launchers.open(heroic)
        } else if let url = URL(string: "heroic://library") {
            NSWorkspace.shared.open(url)
        }
    }
}
