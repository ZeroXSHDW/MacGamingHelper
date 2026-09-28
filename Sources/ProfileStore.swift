import Foundation

enum AppPaths {
    static var supportDirectory: URL {
        let url = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/MacGamingHelper", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

/// Save / load custom mapping profiles as JSON under Application Support.
enum ProfileStore {
    static var directory: URL {
        let url = AppPaths.supportDirectory.appendingPathComponent("Profiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func fileURL(for id: String) -> URL {
        directory.appendingPathComponent("\(id).json")
    }

    static func loadAll() -> [MappingProfile] {
        var list = MappingProfile.presets
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return list
        }
        for url in files where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let profile = try? JSONDecoder().decode(MappingProfile.self, from: data) else { continue }
            if let idx = list.firstIndex(where: { $0.id == profile.id }) {
                list[idx] = profile
            } else {
                list.append(profile)
            }
        }
        return list
    }

    static func save(_ profile: MappingProfile) throws {
        let data = try JSONEncoder().encode(profile)
        try data.write(to: fileURL(for: profile.id), options: .atomic)
    }

    static func delete(id: String) throws {
        guard !MappingProfile.presets.contains(where: { $0.id == id }) else { return }
        let url = fileURL(for: id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    static func isPreset(_ id: String) -> Bool {
        MappingProfile.presets.contains { $0.id == id }
    }
}
