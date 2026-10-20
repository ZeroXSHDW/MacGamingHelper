import Foundation

/// Small, dependency-free checks for host capabilities the launchers rely on.
enum SystemSupport {
    static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    /// Steam's macOS client is Intel-only, so it needs Rosetta 2 on Apple silicon.
    /// The runtime lives under /Library/Apple once installed.
    static var rosettaAvailable: Bool {
        guard isAppleSilicon else { return true }
        let fm = FileManager.default
        return fm.fileExists(atPath: "/Library/Apple/usr/libexec/oah")
            || fm.fileExists(atPath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime")
    }

    static let rosettaInstallCommand = "softwareupdate --install-rosetta --agree-to-license"

    static var steamLaunchBlockedByRosetta: Bool {
        isAppleSilicon && !rosettaAvailable
    }
}
