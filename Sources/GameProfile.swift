import Foundation

/// Per-app gaming profile. When the matching app becomes the frontmost window,
/// Mac Gaming Helper applies its mapping, overlay and keep-awake settings.
struct GameProfile: Codable, Equatable, Identifiable {
    var bundleID: String
    var name: String
    var id: String { bundleID }

    /// Mapping profile to switch to (nil = leave the active one unchanged).
    var mappingProfileID: String?
    var autoEnableMapping: Bool
    var overlayMode: OverlayMode
    var showOverlay: Bool
    var keepAwake: Bool
    /// Pause Mapping while this app is frontmost (e.g. Steam Input games).
    var pauseMapping: Bool

    static func make(bundleID: String, name: String, mappingProfileID: String?) -> GameProfile {
        GameProfile(
            bundleID: bundleID,
            name: name,
            mappingProfileID: mappingProfileID,
            autoEnableMapping: false,
            overlayMode: .performance,
            showOverlay: true,
            keepAwake: false,
            pauseMapping: false
        )
    }
}
