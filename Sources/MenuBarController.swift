import AppKit
import SwiftUI

/// Compact menu-bar status: pad connected + battery; click opens main window.
@MainActor
final class MenuBarController: ObservableObject {
    static let shared = MenuBarController()

    private var item: NSStatusItem?
    private weak var monitor: ControllerMonitor?
    private weak var settings: AppSettings?
    private var timer: Timer?

    func bind(monitor: ControllerMonitor, settings: AppSettings) {
        self.monitor = monitor
        self.settings = settings
        applyVisibility()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshTitle() }
        }
    }

    func applyVisibility() {
        guard let settings else { return }
        if settings.showMenuBar {
            if item == nil {
                let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                status.button?.image = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "Mac Gaming Helper")
                status.button?.imagePosition = .imageLeading
                status.button?.action = #selector(statusClicked(_:))
                status.button?.target = self
                status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
                item = status
                rebuildMenu()
            }
            refreshTitle()
        } else {
            if let item {
                NSStatusBar.system.removeStatusItem(item)
                self.item = nil
            }
        }
    }

    func refreshTitle() {
        guard let item, let monitor else { return }
        let snap = monitor.selected
        if snap.connected {
            let bat = snap.batteryPercent.map { " \($0)%" } ?? ""
            item.button?.title = " \(snap.kind.shortLabel)\(bat)"
            item.button?.toolTip = "\(snap.title) · \(snap.transportLabel) · \(snap.battery)"
        } else {
            item.button?.title = " —"
            item.button?.toolTip = "No controller · click to open Mac Gaming Helper"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Mac Gaming Helper", action: #selector(openMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Rediscover Controllers", action: #selector(rediscover), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        for entry in menu.items {
            entry.target = self
        }
        item?.menu = menu
    }

    @objc private func statusClicked(_ sender: Any?) {
        // Left click with menu assigned opens menu; also bring window forward.
        openMainWindow()
    }

    @objc func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
        if NSApp.windows.isEmpty {
            // Trigger a new window via SwiftUI if needed.
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func rediscover() {
        monitor?.rediscover()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
