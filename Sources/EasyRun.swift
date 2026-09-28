import AppKit
import SwiftUI
import Foundation
import UserNotifications

/// One-tap “Start gaming” / “Stop gaming” orchestration.
@MainActor
enum EasyRun {
    static func startGaming(
        mapper: InputMapper?,
        launchers: LauncherShelf? = nil,
        openSteam: Bool = false,
        pauseMappingForSteam: Bool = true,
        goPlayPage: Bool = true
    ) {
        let settings = AppSettings.shared
        settings.showMenuBar = true
        settings.showOverlay = true
        settings.overlayMode = .performance
        settings.overlayEdge = .top
        settings.gamingSessionActive = true
        settings.metricController = true
        settings.metricCPU = true
        settings.metricMemory = true
        settings.metricGPU = true
        settings.metricPanel = true
        settings.metricPing = true
        settings.metricMapping = true
        settings.metricAwake = true
        settings.pingEnabled = true

        if pauseMappingForSteam, let mapper, mapper.enabled, !mapper.pausedByUser {
            mapper.togglePauseHotkey()
        }

        MenuBarController.shared.applyVisibility()
        GamingOverlayController.shared.applyVisibility()
        settings.syncKeepAwake()

        if goPlayPage {
            NotificationCenter.default.post(name: .mghGoPage, object: NavPage.play.rawValue)
        }
        MenuBarController.shared.openMainWindow()
        MenuBarController.shared.rebuildMenuPublic()

        if openSteam {
            if let mapper, let launchers {
                GameSession.prepSteamSession(mapper: mapper, launchers: launchers)
            } else {
                SteamShelf.openBigPicture()
            }
        }
    }

    static func stopGaming() {
        let settings = AppSettings.shared
        settings.gamingSessionActive = false
        // Keep overlay preference but allow hide for “stop session” clarity
        settings.showOverlay = false
        settings.syncKeepAwake()
        GamingOverlayController.shared.applyVisibility()
        MenuBarController.shared.rebuildMenuPublic()
    }

    static var isGamingSession: Bool {
        AppSettings.shared.gamingSessionActive || AppSettings.shared.showOverlay
    }

    /// Gatekeeper fix guidance (cannot remove quarantine from sandbox without user).
    static func fixGatekeeperGuidance() -> String {
        """
        If macOS says Mac Gaming Helper “can’t be opened”:

        1. Right-click the app in /Applications → Open → Open
        2. Or run in Terminal:
           xattr -cr "/Applications/Mac Gaming Helper.app"
           open -a "Mac Gaming Helper"
        3. Or double-click: scripts/fix-gatekeeper.sh after install

        Ad-hoc builds are not notarized — Right-click → Open is normal the first time.
        """
    }

    static func copyGatekeeperCommand() {
        let cmd = "xattr -cr \"/Applications/Mac Gaming Helper.app\" && open -a \"Mac Gaming Helper\""
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
    }

    static func openAllPermissionPanes() {
        PermissionsHelper.openBluetoothPrivacy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            PermissionsHelper.openAccessibility()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            PermissionsHelper.openNotifications()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            PermissionsHelper.openLocalNetwork()
        }
    }
}

/// Live permission status lights for Settings / first-run.
@MainActor
final class PermissionStatusModel: ObservableObject {
    @Published var accessibilityOK = false
    @Published var notificationsOK = false
    @Published var notificationsLabel = "Checking…"
    @Published var bluetoothLabel = "Open Settings to confirm"
    @Published var bluetoothOK: Bool? = nil // unknown

    func refresh() {
        accessibilityOK = PermissionsHelper.accessibilityTrusted
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.notificationsOK = true
                    self.notificationsLabel = "Allowed"
                case .denied:
                    self.notificationsOK = false
                    self.notificationsLabel = "Denied"
                case .notDetermined:
                    self.notificationsOK = false
                    self.notificationsLabel = "Not asked yet"
                @unknown default:
                    self.notificationsOK = false
                    self.notificationsLabel = "Unknown"
                }
            }
        }
    }
}

struct PermissionStatusRow: View {
    let title: String
    let detail: String
    let ok: Bool?
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(Theme.mute)
            }
            Spacer()
            PillButton(title: actionTitle, action: action)
        }
    }

    private var color: Color {
        switch ok {
        case true: return Theme.good
        case false: return Theme.bad
        case nil: return Theme.warn
        }
    }
}
