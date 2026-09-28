import AppKit
import SwiftUI

/// Compact always-on-top gaming HUD: pad, battery, profile, Mapping LIVE/PAUSED.
@MainActor
final class PlayHUDController: ObservableObject {
    static let shared = PlayHUDController()

    private var panel: NSPanel?
    private var host: NSHostingView<PlayHUDView>?
    private weak var monitor: ControllerMonitor?
    private weak var mapper: InputMapper?
    private weak var settings: AppSettings?
    private var moveObserver: NSObjectProtocol?

    func bind(monitor: ControllerMonitor, mapper: InputMapper, settings: AppSettings) {
        self.monitor = monitor
        self.mapper = mapper
        self.settings = settings
        applyVisibility()
    }

    func applyVisibility() {
        guard let settings else { return }
        if settings.showPlayHUD {
            show()
        } else {
            hide()
        }
        settings.syncKeepAwake()
    }

    func toggle() {
        settings?.showPlayHUD.toggle()
        applyVisibility()
    }

    private func show() {
        guard let monitor, let mapper, let settings else { return }
        if panel == nil {
            let view = PlayHUDView(monitor: monitor, mapper: mapper, settings: settings)
            let hosting = NSHostingView(rootView: view)
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = "Play HUD"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isMovableByWindowBackground = true
            panel.hidesOnDeactivate = false
            panel.contentView = hosting
            if let origin = settings.hudOrigin() {
                panel.setFrameOrigin(origin)
            } else if let screen = NSScreen.main {
                let f = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(x: f.maxX - 320, y: f.maxY - 130))
            }
            moveObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: panel,
                queue: .main
            ) { [weak self] note in
                guard let win = note.object as? NSWindow else { return }
                Task { @MainActor in
                    self?.settings?.saveHUDOrigin(win.frame.origin)
                }
            }
            self.panel = panel
            self.host = hosting
        }
        host?.rootView = PlayHUDView(monitor: monitor, mapper: mapper, settings: settings)
        panel?.orderFrontRegardless()
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    func refresh() {
        guard let monitor, let mapper, let settings, settings.showPlayHUD else { return }
        host?.rootView = PlayHUDView(monitor: monitor, mapper: mapper, settings: settings)
    }
}

struct PlayHUDView: View {
    @ObservedObject var monitor: ControllerMonitor
    @ObservedObject var mapper: InputMapper
    @ObservedObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(monitor.selected.connected ? Theme.good : Theme.bad)
                        .frame(width: 8, height: 8)
                    Text(monitor.selected.connected ? monitor.selected.kind.shortLabel : "No pad")
                        .font(.callout.weight(.bold))
                    if let p = monitor.selected.batteryPercent {
                        Button {
                            if !monitor.selected.connected {
                                NotificationCenter.default.post(name: .mghGoPage, object: NavPage.setup.rawValue)
                                MenuBarController.shared.openMainWindow()
                            }
                        } label: {
                            Text("\(p)%")
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(batteryColor(p))
                        }
                        .buttonStyle(.plain)
                        .help(monitor.selected.connected ? "Battery" : "Open Pairing")
                    } else if !monitor.selected.connected {
                        Button("Pair…") {
                            NotificationCenter.default.post(name: .mghGoPage, object: NavPage.setup.rawValue)
                            MenuBarController.shared.openMainWindow()
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.warn)
                    }
                }
                Text(mapper.profile.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.mute)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if mapper.enabled {
                        if mapper.isLive { LiveBadge() }
                        else if mapper.pausedByUser { StatusChip(text: "PAUSED", color: Theme.warn) }
                        else { StatusChip(text: "ARMED", color: Theme.accent) }
                    } else {
                        StatusChip(text: "MAP OFF", color: Theme.mute)
                    }
                    Text("⌥⌘M")
                        .font(.caption2.monospaced())
                        .foregroundStyle(Theme.mute)
                }
            }
            Spacer()
            Button {
                MenuBarController.shared.openMainWindow()
            } label: {
                Image(systemName: "macwindow")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Show main window")
            .accessibilityLabel("Show main window")
        }
        .padding(12)
        .frame(width: 288, height: 86)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func batteryColor(_ p: Int) -> Color {
        if p <= 20 { return Theme.bad }
        if p <= 40 { return Theme.warn }
        return Theme.good
    }
}
