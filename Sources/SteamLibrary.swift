import AppKit
import Foundation

struct SteamGame: Identifiable, Hashable, Sendable {
    let appID: String
    let name: String
    var id: String { appID }
}

enum SteamVDF {
    static func quotedStrings(in line: String) -> [String] {
        var out: [String] = []
        var current = ""
        var inQuote = false
        for character in line {
            if character == "\"" {
                if inQuote {
                    out.append(current)
                    current = ""
                }
                inQuote.toggle()
            } else if inQuote {
                current.append(character)
            }
        }
        return out
    }

    static func value(_ text: String, key: String) -> String? {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let parts = quotedStrings(in: String(line))
            if parts.count >= 2, parts[0] == key { return parts[1] }
        }
        return nil
    }

    static func paths(in text: String) -> [String] {
        var found: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let parts = quotedStrings(in: String(line))
            if parts.count >= 2, parts[0] == "path" {
                let raw = parts[1].replacingOccurrences(of: "\\\\", with: "/")
                if raw.hasPrefix("/") || raw.hasPrefix("~") { found.append(raw) }
            }
        }
        return found
    }
}

@MainActor
final class SteamShelf: ObservableObject {
    @Published var games: [SteamGame] = []
    @Published var note: String = ""
    @Published var lastScanOK = false

    func refresh() {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let steam = home.appendingPathComponent("Library/Application Support/Steam")
        var roots = [steam]
        let vdf = steam.appendingPathComponent("steamapps/libraryfolders.vdf")
        if let text = try? String(contentsOf: vdf, encoding: .utf8) {
            for path in SteamVDF.paths(in: text) {
                roots.append(URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
            }
        }
        var list: [SteamGame] = []
        var seen = Set<String>()
        for root in roots {
            let apps = root.appendingPathComponent("steamapps")
            guard let files = try? FileManager.default.contentsOfDirectory(at: apps, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.lastPathComponent.hasPrefix("appmanifest_") && file.pathExtension == "acf" {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let stem = file.deletingPathExtension().lastPathComponent
                let fileID = stem.replacingOccurrences(of: "appmanifest_", with: "")
                guard let name = SteamVDF.value(text, key: "name"), !name.isEmpty else { continue }
                let appID = SteamVDF.value(text, key: "appid") ?? fileID
                let flags = Int(SteamVDF.value(text, key: "StateFlags") ?? "") ?? 0
                guard flags & 4 != 0 else { continue } // installed
                if seen.insert(appID).inserted {
                    list.append(SteamGame(appID: appID, name: name))
                }
            }
        }
        list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        games = list
        lastScanOK = true
        if list.isEmpty {
            note = FileManager.default.fileExists(atPath: steam.path)
                ? "No installed Steam titles found (or library not readable)."
                : "Steam library folder not found. Install Steam, then Refresh."
        } else {
            note = "\(list.count) installed Steam title(s)."
        }
    }

    func launch(_ game: SteamGame) {
        if let url = URL(string: "steam://rungameid/\(game.appID)") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openBigPicture() {
        if let url = URL(string: "steam://open/bigpicture") {
            NSWorkspace.shared.open(url)
        }
    }
}
