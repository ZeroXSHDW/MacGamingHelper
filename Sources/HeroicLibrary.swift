import AppKit
import Foundation

struct HeroicGame: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let store: String
    let detail: String
}

@MainActor
final class HeroicShelf: ObservableObject {
    @Published var games: [HeroicGame] = []
    @Published var note: String = ""

    func refresh() {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let files: [(URL, String)] = [
            (home.appendingPathComponent(".config/legendary/installed.json"), "Epic"),
            (home.appendingPathComponent("Library/Application Support/legendary/installed.json"), "Epic"),
            (home.appendingPathComponent("Library/Application Support/heroic/gog_store/installed.json"), "GOG"),
            (home.appendingPathComponent(".config/heroic/gog_store/installed.json"), "GOG"),
            (home.appendingPathComponent("Library/Application Support/heroic/sideload_apps/library.json"), "Heroic"),
            (home.appendingPathComponent(".config/heroic/sideload_apps/library.json"), "Heroic"),
        ]
        var list: [HeroicGame] = []
        var seen = Set<String>()
        for (url, store) in files {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            collect(json, store: store, into: &list, seen: &seen)
        }
        list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        games = list
        note = list.isEmpty
            ? "No Heroic / Legendary installs found (optional)."
            : "\(list.count) Heroic/Epic/GOG title(s)."
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
                list.append(HeroicGame(id: key, name: title, store: store, detail: path.isEmpty ? store : path))
            }
            return
        }
        for value in dict.values {
            collect(value, store: store, into: &list, seen: &seen)
        }
    }

    func launch(_ game: HeroicGame, launchers: LauncherShelf) {
        // Prefer opening Heroic; deep links vary by version.
        if let heroic = launchers.items.first(where: { $0.id == "heroic" }), heroic.isInstalled {
            launchers.open(heroic)
        } else if let url = URL(string: "heroic://library") {
            NSWorkspace.shared.open(url)
        }
    }
}
