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
        static let showPlayHUD = "settings.showPlayHUD"
        static let stickCurve = "settings.stickCurve"
        static let aimSensitivity = "settings.aimSensitivity"
        static let invertLookY = "settings.invertLookY"
        static let hairTrigger = "settings.hairTrigger"
        static let hairTriggerThreshold = "settings.hairTriggerThreshold"
        static let gyroAssist = "settings.gyroAssist"
        static let gamingSessionActive = "settings.gamingSessionActive"
        static let audioConnect = "settings.audioConnect"
        static let audioLowBat = "settings.audioLowBat"
        static let audioTester = "settings.audioTester"
        static let hudOriginX = "settings.hudOriginX"
        static let hudOriginY = "settings.hudOriginY"
        static let showOverlay = "settings.showOverlay"
        static let overlayMode = "settings.overlayMode"
        static let overlayEdge = "settings.overlayEdge"
        static let overlayOpacity = "settings.overlayOpacity"
        static let overlayAutoShow = "settings.overlayAutoShow"
        static let overlayAutoHide = "settings.overlayAutoHide"
        static let pingEnabled = "settings.pingEnabled"
        static let pingHost = "settings.pingHost"
        static let metricController = "settings.metricController"
        static let metricCPU = "settings.metricCPU"
        static let metricMemory = "settings.metricMemory"
        static let metricGPU = "settings.metricGPU"
        static let metricPanel = "settings.metricPanel"
        static let metricGameCPU = "settings.metricGameCPU"
        static let metricPing = "settings.metricPing"
        static let metricMapping = "settings.metricMapping"
        static let metricAwake = "settings.metricAwake"
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
    /// Legacy alias — maps to showOverlay (v3.3 unified Gaming Overlay).
    var showPlayHUD: Bool {
        get { showOverlay }
        set { showOverlay = newValue }
    }

    @Published var showOverlay: Bool {
        didSet {
            d.set(showOverlay, forKey: Key.showOverlay)
            d.set(showOverlay, forKey: Key.showPlayHUD) // keep legacy key in sync
            GamingOverlayController.shared.applyVisibility()
            syncKeepAwake()
        }
    }
    @Published var overlayMode: OverlayMode {
        didSet {
            d.set(overlayMode.rawValue, forKey: Key.overlayMode)
            GamingOverlayController.shared.applyVisibility()
        }
    }
    @Published var overlayEdge: OverlayEdge {
        didSet {
            d.set(overlayEdge.rawValue, forKey: Key.overlayEdge)
            GamingOverlayController.shared.applyVisibility()
        }
    }
    @Published var overlayOpacity: Double {
        didSet { d.set(overlayOpacity, forKey: Key.overlayOpacity) }
    }
    @Published var overlayAutoShowOnSession: Bool {
        didSet { d.set(overlayAutoShowOnSession, forKey: Key.overlayAutoShow) }
    }
    @Published var overlayAutoHideIdle: Bool {
        didSet { d.set(overlayAutoHideIdle, forKey: Key.overlayAutoHide) }
    }
    @Published var pingEnabled: Bool {
        didSet { d.set(pingEnabled, forKey: Key.pingEnabled) }
    }
    @Published var pingHost: String {
        didSet { d.set(pingHost, forKey: Key.pingHost) }
    }
    @Published var metricController: Bool { didSet { d.set(metricController, forKey: Key.metricController) } }
    @Published var metricCPU: Bool { didSet { d.set(metricCPU, forKey: Key.metricCPU) } }
    @Published var metricMemory: Bool { didSet { d.set(metricMemory, forKey: Key.metricMemory) } }
    @Published var metricGPU: Bool { didSet { d.set(metricGPU, forKey: Key.metricGPU) } }
    @Published var metricPanel: Bool { didSet { d.set(metricPanel, forKey: Key.metricPanel) } }
    @Published var metricGameCPU: Bool { didSet { d.set(metricGameCPU, forKey: Key.metricGameCPU) } }
    @Published var metricPing: Bool {
        didSet { d.set(metricPing, forKey: Key.metricPing) }
    }
    @Published var metricMapping: Bool { didSet { d.set(metricMapping, forKey: Key.metricMapping) } }
    @Published var metricAwake: Bool { didSet { d.set(metricAwake, forKey: Key.metricAwake) } }

    var effectiveOverlayVisible: Bool { showOverlay }
    @Published var stickCurve: StickCurve {
        didSet { d.set(stickCurve.rawValue, forKey: Key.stickCurve) }
    }
    @Published var aimSensitivity: Double {
        didSet { d.set(aimSensitivity, forKey: Key.aimSensitivity) }
    }
    @Published var invertLookY: Bool {
        didSet { d.set(invertLookY, forKey: Key.invertLookY) }
    }
    @Published var hairTrigger: Bool {
        didSet { d.set(hairTrigger, forKey: Key.hairTrigger) }
    }
    @Published var hairTriggerThreshold: Double {
        didSet { d.set(hairTriggerThreshold, forKey: Key.hairTriggerThreshold) }
    }
    @Published var gyroAssistMouse: Bool {
        didSet { d.set(gyroAssistMouse, forKey: Key.gyroAssist) }
    }
    @Published var gamingSessionActive: Bool {
        didSet {
            d.set(gamingSessionActive, forKey: Key.gamingSessionActive)
            if gamingSessionActive && overlayAutoShowOnSession {
                showOverlay = true
            }
            syncKeepAwake()
            GamingOverlayController.shared.applyVisibility()
        }
    }
    @Published var audioConnectCues: Bool {
        didSet { d.set(audioConnectCues, forKey: Key.audioConnect) }
    }
    @Published var audioLowBatteryCue: Bool {
        didSet { d.set(audioLowBatteryCue, forKey: Key.audioLowBat) }
    }
    @Published var audioTesterBeeps: Bool {
        didSet { d.set(audioTesterBeeps, forKey: Key.audioTester) }
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
        lastTab = d.string(forKey: Key.lastTab) ?? NavPage.play.rawValue
        pauseMappingWhenInactive = d.object(forKey: Key.pauseMappingInactive) as? Bool ?? true
        focusModeController = d.bool(forKey: Key.focusMode)
        preferredPadKey = d.string(forKey: Key.preferredPadKey) ?? ""
        // Overlay: migrate legacy showPlayHUD
        if d.object(forKey: Key.showOverlay) != nil {
            showOverlay = d.bool(forKey: Key.showOverlay)
        } else {
            showOverlay = d.bool(forKey: Key.showPlayHUD)
        }
        if let raw = d.string(forKey: Key.overlayMode), let m = OverlayMode(rawValue: raw) {
            overlayMode = m
        } else {
            overlayMode = .performance
        }
        if let raw = d.string(forKey: Key.overlayEdge), let e = OverlayEdge(rawValue: raw) {
            overlayEdge = e
        } else {
            overlayEdge = .top
        }
        overlayOpacity = d.object(forKey: Key.overlayOpacity) as? Double ?? 0.92
        overlayAutoShowOnSession = d.object(forKey: Key.overlayAutoShow) as? Bool ?? true
        overlayAutoHideIdle = d.bool(forKey: Key.overlayAutoHide)
        pingEnabled = d.object(forKey: Key.pingEnabled) as? Bool ?? true
        pingHost = d.string(forKey: Key.pingHost) ?? "1.1.1.1"
        metricController = d.object(forKey: Key.metricController) as? Bool ?? true
        metricCPU = d.object(forKey: Key.metricCPU) as? Bool ?? true
        metricMemory = d.object(forKey: Key.metricMemory) as? Bool ?? true
        metricGPU = d.object(forKey: Key.metricGPU) as? Bool ?? true
        metricPanel = d.object(forKey: Key.metricPanel) as? Bool ?? true
        metricGameCPU = d.object(forKey: Key.metricGameCPU) as? Bool ?? true
        metricPing = d.object(forKey: Key.metricPing) as? Bool ?? true
        metricMapping = d.object(forKey: Key.metricMapping) as? Bool ?? true
        metricAwake = d.object(forKey: Key.metricAwake) as? Bool ?? true
        if let raw = d.string(forKey: Key.stickCurve), let c = StickCurve(rawValue: raw) {
            stickCurve = c
        } else {
            stickCurve = .easeOut
        }
        aimSensitivity = d.object(forKey: Key.aimSensitivity) as? Double ?? 1.15
        invertLookY = d.bool(forKey: Key.invertLookY)
        hairTrigger = d.object(forKey: Key.hairTrigger) as? Bool ?? true
        hairTriggerThreshold = d.object(forKey: Key.hairTriggerThreshold) as? Double ?? 0.12
        gyroAssistMouse = d.bool(forKey: Key.gyroAssist)
        gamingSessionActive = d.bool(forKey: Key.gamingSessionActive)
        audioConnectCues = d.object(forKey: Key.audioConnect) as? Bool ?? true
        audioLowBatteryCue = d.object(forKey: Key.audioLowBat) as? Bool ?? true
        audioTesterBeeps = d.bool(forKey: Key.audioTester)
        refreshLoginItemState()
        syncKeepAwake()
    }

    func syncKeepAwake() {
        KeepAwake.shared.update(active: showOverlay || gamingSessionActive)
    }

    func hudOrigin() -> CGPoint? {
        guard d.object(forKey: Key.hudOriginX) != nil else { return nil }
        return CGPoint(x: d.double(forKey: Key.hudOriginX), y: d.double(forKey: Key.hudOriginY))
    }

    func saveHUDOrigin(_ p: CGPoint) {
        d.set(p.x, forKey: Key.hudOriginX)
        d.set(p.y, forKey: Key.hudOriginY)
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
