import AppKit
import SwiftUI

/// Compact menu-bar status: pad connected + battery; gaming shortcuts.
@MainActor
final class MenuBarController: ObservableObject {
    static let shared = MenuBarController()

    private var item: NSStatusItem?
    private weak var monitor: ControllerMonitor?
    private weak var settings: AppSettings?
    private weak var mapper: InputMapper?
    private weak var launchers: LauncherShelf?
    private var timer: Timer?

    func bind(monitor: ControllerMonitor, settings: AppSettings, mapper: InputMapper? = nil, launchers: LauncherShelf? = nil) {
        self.monitor = monitor
        self.settings = settings
        if let mapper { self.mapper = mapper }
        if let launchers { self.launchers = launchers }
        applyVisibility()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshTitle()
                GamingOverlayController.shared.refresh()
            }
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
            }
            rebuildMenu()
            refreshTitle()
        } else if let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    func refreshTitle() {
        guard let item, let monitor else { return }
        let snap = monitor.selected
        if snap.connected {
            let bat = snap.batteryPercent.map { " \($0)%" } ?? ""
            item.button?.title = " \(snap.kind.shortLabel)\(bat)"
            item.button?.toolTip = "\(snap.title) · \(snap.transportLabel) · \(snap.battery)"
            if let p = snap.batteryPercent {
                item.button?.contentTintColor = batteryNSColor(p)
            } else {
                item.button?.contentTintColor = nil
            }
        } else {
            item.button?.title = " —"
            item.button?.toolTip = "No controller · click to open Mac Gaming Helper"
            item.button?.contentTintColor = nil
        }
    }

    private func batteryNSColor(_ p: Int) -> NSColor {
        if p <= 20 { return NSColor(calibratedRed: 0.9, green: 0.3, blue: 0.3, alpha: 1) }
        if p <= 40 { return NSColor(calibratedRed: 0.95, green: 0.7, blue: 0.2, alpha: 1) }
        return NSColor(calibratedRed: 0.2, green: 0.75, blue: 0.4, alpha: 1)
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        func add(_ title: String, _ sel: Selector, _ key: String = "") {
            let i = menu.addItem(withTitle: title, action: sel, keyEquivalent: key)
            i.target = self
        }
        add("Open Mac Gaming Helper", #selector(openMainWindow))
        add("Rediscover Controllers", #selector(rediscover))
        menu.addItem(.separator())
        let gaming = settings?.gamingSessionActive == true || settings?.showOverlay == true
        add(gaming ? "Stop gaming session" : "Start gaming", #selector(toggleGaming))
        add("Start gaming + Steam Big Picture", #selector(startGamingSteam))
        menu.addItem(.separator())
        add("Prep Steam session", #selector(prepSteam))
        let ov = settings?.showOverlay == true
        let mode = settings?.overlayMode == .performance ? "Performance Bar" : "Compact HUD"
        add(ov ? "Hide Overlay (\(mode))" : "Show Performance Bar", #selector(toggleHUD))
        if ov {
            add(settings?.overlayMode == .performance ? "Switch to Compact HUD" : "Switch to Performance Bar", #selector(toggleMode))
        }
        add("Pause / Resume Mapping", #selector(toggleMapping))
        menu.addItem(.separator())
        add("Quit", #selector(quitApp), "q")
        item?.menu = menu
    }

    @objc private func statusClicked(_ sender: Any?) {
        openMainWindow()
    }

    @objc func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where !(window is NSPanel) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func rediscover() { monitor?.rediscover() }
    @objc private func prepSteam() {
        if let mapper, let launchers {
            GameSession.prepSteamSession(mapper: mapper, launchers: launchers)
        } else {
            SteamShelf.openBigPicture()
        }
    }
    @objc private func toggleHUD() {
        GamingOverlayController.shared.toggle()
        rebuildMenu()
    }
    @objc private func toggleMode() {
        GamingOverlayController.shared.toggleMode()
        rebuildMenu()
    }
    @objc private func toggleMapping() { mapper?.togglePauseHotkey() }
    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func toggleGaming() {
        if settings?.gamingSessionActive == true || settings?.showOverlay == true {
            EasyRun.stopGaming()
        } else {
            EasyRun.startGaming(mapper: mapper, launchers: launchers, openSteam: false)
        }
        rebuildMenu()
    }

    @objc private func startGamingSteam() {
        EasyRun.startGaming(mapper: mapper, launchers: launchers, openSteam: true)
        rebuildMenu()
    }

    func rebuildMenuPublic() { rebuildMenu() }
}
