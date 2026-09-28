import AppKit
import ApplicationServices
import Foundation
import UserNotifications

/// Opens System Settings privacy panes (TCC cannot be granted silently).
enum PermissionsHelper {
    @discardableResult
    static func openURLs(_ candidates: [String]) -> Bool {
        for s in candidates {
            if let u = URL(string: s), NSWorkspace.shared.open(u) { return true }
        }
        // Fallback: open Privacy & Security root
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            return NSWorkspace.shared.open(u)
        }
        return false
    }

    static func openBluetoothPrivacy() {
        openURLs([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Bluetooth",
            "x-apple.systempreferences:com.apple.BluetoothSettings",
            "x-apple.systempreferences:com.apple.preference.bluetooth",
        ])
    }

    static func openBluetoothSettings() {
        openURLs([
            "x-apple.systempreferences:com.apple.BluetoothSettings",
            "x-apple.systempreferences:com.apple.preference.bluetooth",
            "x-apple.systempreferences:com.apple.settings.Bluetooth",
        ])
    }

    static func openAccessibility() {
        openURLs([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        ])
    }

    static func openNotifications() {
        openURLs([
            "x-apple.systempreferences:com.apple.preference.notifications",
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.settings.Notifications",
        ])
    }

    static func openAutomation() {
        openURLs([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Automation",
        ])
    }

    static func openLocalNetwork() {
        openURLs([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocalNetwork",
        ])
    }

    static func openPrivacyRoot() {
        openURLs([
            "x-apple.systempreferences:com.apple.preference.security",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
        ])
    }

    static var accessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestNotificationAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// One-liner checklist for README / shell.
    static var humanChecklist: String {
        """
        Enable for Mac Gaming Helper in System Settings:
        1. Privacy & Security → Bluetooth — ON (pad discovery)
        2. Privacy & Security → Accessibility — ON (only if using Mapping)
        3. Notifications → Mac Gaming Helper — allow (low-battery alerts)
        4. Privacy & Security → Local Network — ON if ping metric is blocked (optional)
        5. Privacy & Security → Automation — allow Steam / System Settings if prompted
        Overlay: menu bar → Show Performance Bar, or press ⌃⌥⌘P
        """
    }
}
