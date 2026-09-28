import AppKit
import Foundation

struct SteamGame: Identifiable, Hashable, Sendable {
    let appID: String
    let name: String
    var lastUpdated: Int
    var sizeOnDisk: Int64
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
                let raw = parts[1]
                    .replacingOccurrences(of: "\\\\", with: "/")
                    .replacingOccurrences(of: "\\", with: "/")
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
    @Published var filter: String = ""
    @Published var favourites: Set<String> = []

    private let favKey = "steam.favourites"

    init() {
        if let arr = UserDefaults.standard.array(forKey: favKey) as? [String] {
            favourites = Set(arr)
        }
    }

    var displayed: [SteamGame] {
        let q = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var list = games
        if !q.isEmpty {
            list = list.filter { $0.name.lowercased().contains(q) || $0.appID.contains(q) }
        }
        return list.sorted { a, b in
            let af = favourites.contains(a.appID)
            let bf = favourites.contains(b.appID)
            if af != bf { return af && !bf }
            if a.lastUpdated != b.lastUpdated { return a.lastUpdated > b.lastUpdated }
            if a.sizeOnDisk != b.sizeOnDisk { return a.sizeOnDisk > b.sizeOnDisk }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    func toggleFavourite(_ game: SteamGame) {
        if favourites.contains(game.appID) {
            favourites.remove(game.appID)
        } else {
            favourites.insert(game.appID)
        }
        UserDefaults.standard.set(Array(favourites), forKey: favKey)
    }

    func refresh() {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let steam = home.appendingPathComponent("Library/Application Support/Steam")
        var roots: [URL] = [steam]
        let vdf = steam.appendingPathComponent("steamapps/libraryfolders.vdf")
        if let text = try? String(contentsOf: vdf, encoding: .utf8) {
            for path in SteamVDF.paths(in: text) {
                let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                if !roots.contains(url) { roots.append(url) }
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
                guard flags & 4 != 0 else { continue }
                let updated = Int(SteamVDF.value(text, key: "LastUpdated") ?? "0") ?? 0
                let size = Int64(SteamVDF.value(text, key: "SizeOnDisk") ?? "0") ?? 0
                if seen.insert(appID).inserted {
                    list.append(SteamGame(appID: appID, name: name, lastUpdated: updated, sizeOnDisk: size))
                }
            }
        }
        games = list
        lastScanOK = true
        let rootsNote = roots.count > 1 ? " across \(roots.count) library folders" : ""
        if list.isEmpty {
            note = FileManager.default.fileExists(atPath: steam.path)
                ? "No installed Steam titles found\(rootsNote)."
                : "Steam library folder not found."
        } else {
            note = "\(list.count) installed title(s)\(rootsNote)."
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
