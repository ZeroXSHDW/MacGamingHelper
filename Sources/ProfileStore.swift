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

    /// JSON used by Export (no file written here).
    static func exportData(_ profile: MappingProfile) -> Data? {
        try? JSONEncoder().encode(profile)
    }

    /// Decode a profile from Import, give it a fresh name if requested, and
    /// ensure its id never collides with a preset or an existing custom file.
    static func importProfile(from data: Data, asName name: String?) -> MappingProfile? {
        guard var profile = try? JSONDecoder().decode(MappingProfile.self, from: data) else {
            return nil
        }
        if let name, !name.isEmpty {
            profile.name = name
        }
        if isPreset(profile.id) {
            profile.id = "custom-\(UUID().uuidString.prefix(8))"
        }
        if FileManager.default.fileExists(atPath: fileURL(for: profile.id).path) {
            profile.id = "\(profile.id)-\(UUID().uuidString.prefix(6))"
        }
        try? save(profile)
        return profile
    }
}
