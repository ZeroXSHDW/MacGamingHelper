import AppKit
import Foundation
import ServiceManagement
import SwiftUI

/// Persisted preferences (UserDefaults + SMAppService for login item).
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let d = UserDefaults.standard
    private enum Key {
        static let showMenuBar = "settings.showMenuBar"
        static let launchAtLogin = "settings.launchAtLogin"
        static let startMinimized = "settings.startMinimized"
        static let openPairingOnEmpty = "settings.openPairingOnEmpty"
        static let lightHue = "settings.lightHue"
        static let stickDeadzone = "settings.stickDeadzone"
        static let triggerDeadzone = "settings.triggerDeadzone"
        static let stickSensitivity = "settings.stickSensitivity"
        static let touchpadMouse = "settings.touchpadMouse"
        static let lowBatteryAlerts = "settings.lowBatteryAlerts"
        static let didWelcome = "settings.didWelcome"
        static let activeProfileID = "settings.activeProfileID"
        static let lastTab = "settings.lastTab"
        static let pauseMappingInactive = "settings.pauseMappingInactive"
        static let focusMode = "settings.focusMode"
        static let preferredPadKey = "settings.preferredPadKey"
    }

    @Published var showMenuBar: Bool {
        didSet { d.set(showMenuBar, forKey: Key.showMenuBar) }
    }
    @Published var startMinimizedToMenuBar: Bool {
        didSet { d.set(startMinimizedToMenuBar, forKey: Key.startMinimized) }
    }
    @Published var openPairingOnEmpty: Bool {
        didSet { d.set(openPairingOnEmpty, forKey: Key.openPairingOnEmpty) }
    }
    @Published var preferredLightHue: Double {
        didSet { d.set(preferredLightHue, forKey: Key.lightHue) }
    }
    @Published var stickDeadzone: Double {
        didSet { d.set(stickDeadzone, forKey: Key.stickDeadzone) }
    }
    @Published var triggerDeadzone: Double {
        didSet { d.set(triggerDeadzone, forKey: Key.triggerDeadzone) }
    }
    @Published var stickSensitivity: Double {
        didSet { d.set(stickSensitivity, forKey: Key.stickSensitivity) }
    }
    @Published var touchpadAsMouse: Bool {
        didSet { d.set(touchpadAsMouse, forKey: Key.touchpadMouse) }
    }
    @Published var lowBatteryAlerts: Bool {
        didSet { d.set(lowBatteryAlerts, forKey: Key.lowBatteryAlerts) }
    }
    @Published var didShowWelcome: Bool {
        didSet { d.set(didShowWelcome, forKey: Key.didWelcome) }
    }
    @Published var activeProfileID: String {
        didSet { d.set(activeProfileID, forKey: Key.activeProfileID) }
    }
    @Published var lastTab: String {
        didSet { d.set(lastTab, forKey: Key.lastTab) }
    }
    @Published var pauseMappingWhenInactive: Bool {
        didSet { d.set(pauseMappingWhenInactive, forKey: Key.pauseMappingInactive) }
    }
    @Published var focusModeController: Bool {
        didSet { d.set(focusModeController, forKey: Key.focusMode) }
    }
    @Published var preferredPadKey: String {
        didSet { d.set(preferredPadKey, forKey: Key.preferredPadKey) }
    }
    @Published var launchAtLoginEnabled: Bool = false
    @Published var launchAtLoginNote: String = ""

    private init() {
        showMenuBar = d.object(forKey: Key.showMenuBar) as? Bool ?? true
        startMinimizedToMenuBar = d.bool(forKey: Key.startMinimized)
        openPairingOnEmpty = d.object(forKey: Key.openPairingOnEmpty) as? Bool ?? true
        preferredLightHue = d.object(forKey: Key.lightHue) as? Double ?? 0.55
        stickDeadzone = d.object(forKey: Key.stickDeadzone) as? Double ?? 0.12
        triggerDeadzone = d.object(forKey: Key.triggerDeadzone) as? Double ?? 0.08
        stickSensitivity = d.object(forKey: Key.stickSensitivity) as? Double ?? 1.0
        touchpadAsMouse = d.object(forKey: Key.touchpadMouse) as? Bool ?? false
        lowBatteryAlerts = d.object(forKey: Key.lowBatteryAlerts) as? Bool ?? true
        didShowWelcome = d.bool(forKey: Key.didWelcome)
        activeProfileID = d.string(forKey: Key.activeProfileID) ?? MappingProfile.fpsWASD.id
        lastTab = d.string(forKey: Key.lastTab) ?? NavPage.controller.rawValue
        pauseMappingWhenInactive = d.object(forKey: Key.pauseMappingInactive) as? Bool ?? true
        focusModeController = d.bool(forKey: Key.focusMode)
        preferredPadKey = d.string(forKey: Key.preferredPadKey) ?? ""
        refreshLoginItemState()
    }

    func refreshLoginItemState() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = (status == .enabled)
        switch status {
        case .enabled: launchAtLoginNote = "Opens at login."
        case .notRegistered: launchAtLoginNote = "Not registered for login."
        case .notFound: launchAtLoginNote = "Login item not found (ad-hoc builds may need re-register after move)."
        case .requiresApproval: launchAtLoginNote = "Waiting for approval in System Settings → Login Items."
        @unknown default: launchAtLoginNote = "Unknown login-item status."
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginNote = error.localizedDescription
        }
        refreshLoginItemState()
    }

    static var supportDirectory: URL { AppPaths.supportDirectory }
}
