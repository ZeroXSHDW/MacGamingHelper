import Foundation

struct UpdateInfo: Equatable {
    var latestTag: String
    var isNewer: Bool
    var htmlURL: URL?
    var message: String
}

enum UpdateChecker {
    static let repoAPI = URL(string: "https://api.github.com/repos/ZeroXSHDW/MacGamingHelper/releases/latest")!
    static let tagsAPI = URL(string: "https://api.github.com/repos/ZeroXSHDW/MacGamingHelper/tags")!
    static let releasesPage = URL(string: "https://github.com/ZeroXSHDW/MacGamingHelper/releases")!

    static func currentVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? Theme.version
    }

    /// Compare dotted versions: 2.3.0 > 2.2.0
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let pa = a.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: ".").compactMap { Int($0) }
        let pb = b.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: ".").compactMap { Int($0) }
        let n = max(pa.count, pb.count)
        for i in 0..<n {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    static func check() async -> UpdateInfo {
        let current = currentVersion()
        do {
            var req = URLRequest(url: repoAPI)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 404 {
                // No releases yet — fall back to latest tag.
                return await checkTags(current: current)
            }
            guard (200..<300).contains(status),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return UpdateInfo(latestTag: current, isNewer: false, htmlURL: releasesPage,
                                  message: "Could not read GitHub releases (HTTP \(status)).")
            }
            let tag = (json["tag_name"] as? String) ?? current
            let html = (json["html_url"] as? String).flatMap(URL.init(string:))
            let newer = isVersion(tag, newerThan: current)
            return UpdateInfo(
                latestTag: tag,
                isNewer: newer,
                htmlURL: html ?? releasesPage,
                message: newer
                    ? "Update available: \(tag) (you have \(current))."
                    : "You’re on \(current). Latest release: \(tag)."
            )
        } catch {
            return UpdateInfo(latestTag: current, isNewer: false, htmlURL: releasesPage,
                              message: "Update check failed: \(error.localizedDescription)")
        }
    }

    private static func checkTags(current: String) async -> UpdateInfo {
        do {
            var req = URLRequest(url: tagsAPI)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let name = arr.first?["name"] as? String else {
                return UpdateInfo(latestTag: current, isNewer: false, htmlURL: releasesPage,
                                  message: "No GitHub releases yet. You’re on \(current).")
            }
            let newer = isVersion(name, newerThan: current)
            return UpdateInfo(
                latestTag: name,
                isNewer: newer,
                htmlURL: releasesPage,
                message: newer
                    ? "Newer tag on GitHub: \(name) (you have \(current))."
                    : "You’re on \(current). Latest tag: \(name)."
            )
        } catch {
            return UpdateInfo(latestTag: current, isNewer: false, htmlURL: releasesPage,
                              message: "Tag check failed: \(error.localizedDescription)")
        }
    }
}
