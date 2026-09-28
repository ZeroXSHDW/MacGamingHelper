import AppKit
import SwiftUI

/// Compact always-on-top gaming HUD: pad, battery, Mapping LIVE/PAUSED, ⌥⌘M hint.
@MainActor
final class PlayHUDController: ObservableObject {
    static let shared = PlayHUDController()

    private var panel: NSPanel?
    private var host: NSHostingView<PlayHUDView>?
    private weak var monitor: ControllerMonitor?
    private weak var mapper: InputMapper?
    private weak var settings: AppSettings?

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
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 88),
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
            panel.center()
            // Park near top-right of main screen
            if let screen = NSScreen.main {
                let f = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(x: f.maxX - 300, y: f.maxY - 120))
            }
            self.panel = panel
            self.host = hosting
        }
        // Refresh root view bindings
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
                        Text("\(p)%")
                            .font(.caption.monospaced().weight(.semibold))
                            .foregroundStyle(batteryColor(p))
                    }
                }
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
        .frame(width: 268, height: 72)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            // Keep HUD content fresh via timer in MenuBar / session
        }
    }

    private func batteryColor(_ p: Int) -> Color {
        if p <= 20 { return Theme.bad }
        if p <= 40 { return Theme.warn }
        return Theme.good
    }
}
