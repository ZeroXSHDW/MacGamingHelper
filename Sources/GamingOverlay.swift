import AppKit
import SwiftUI

enum OverlayMode: String, CaseIterable, Identifiable {
    case compact
    case performance
    var id: String { rawValue }
    var title: String {
        switch self {
        case .compact: return "Compact HUD"
        case .performance: return "Performance Bar"
        }
    }
}

enum OverlayEdge: String, CaseIterable, Identifiable {
    case top, bottom
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Unified always-on-top gaming overlay: Compact HUD or full Performance Bar.
@MainActor
final class GamingOverlayController: ObservableObject {
    static let shared = GamingOverlayController()

    private var panel: NSPanel?
    private var host: NSHostingView<AnyView>?
    private weak var monitor: ControllerMonitor?
    private weak var mapper: InputMapper?
    private weak var settings: AppSettings?
    private var refreshTimer: Timer?

    func bind(monitor: ControllerMonitor, mapper: InputMapper, settings: AppSettings) {
        self.monitor = monitor
        self.mapper = mapper
        self.settings = settings
        applyVisibility()
    }

    func applyVisibility() {
        guard let settings else { return }
        let want = settings.effectiveOverlayVisible
        if want {
            show()
            PerfSampler.shared.start(pingHost: settings.pingHost, pingEnabled: settings.pingEnabled && settings.metricPing)
            PerfSampler.shared.updatePingConfig(host: settings.pingHost, enabled: settings.pingEnabled && settings.metricPing)
            startRefresh()
        } else {
            hide()
            PerfSampler.shared.stop()
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        settings.syncKeepAwake()
        evaluateAutoHide()
    }

    func toggle() {
        guard let settings else { return }
        settings.showOverlay.toggle()
        applyVisibility()
    }

    func toggleMode() {
        guard let settings else { return }
        settings.overlayMode = settings.overlayMode == .compact ? .performance : .compact
        applyVisibility()
    }

    func refresh() {
        guard let settings, settings.effectiveOverlayVisible else { return }
        rebuildRoot()
        evaluateAutoHide()
    }

    private func startRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.rebuildRoot() }
        }
    }

    private func evaluateAutoHide() {
        guard let settings, let monitor else { return }
        guard settings.overlayAutoHideIdle else { return }
        guard settings.showOverlay else { return }
        // Auto-hide only when explicitly idle: no pad + no gaming session
        if !monitor.selected.connected && !settings.gamingSessionActive {
            // Keep showOverlay true but hide panel visually? Spec says auto-hide option.
            // Hide panel without clearing preference so reconnect / session re-shows.
            panel?.orderOut(nil)
            PerfSampler.shared.stop()
        } else if settings.effectiveOverlayVisible {
            panel?.orderFrontRegardless()
            PerfSampler.shared.start(pingHost: settings.pingHost, pingEnabled: settings.pingEnabled && settings.metricPing)
        }
    }

    private func show() {
        guard monitor != nil, mapper != nil, let settings else { return }
        if panel == nil {
            let hosting = NSHostingView(rootView: AnyView(EmptyView()))
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 56),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isMovableByWindowBackground = settings.overlayMode == .compact
            panel.hidesOnDeactivate = false
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.contentView = hosting
            self.panel = panel
            self.host = hosting

            // Right-click context menu
            let menu = NSMenu()
            menu.addItem(withTitle: "Open Mac Gaming Helper", action: #selector(openMain), keyEquivalent: "")
            menu.addItem(withTitle: "Compact HUD", action: #selector(setCompact), keyEquivalent: "")
            menu.addItem(withTitle: "Performance Bar", action: #selector(setPerf), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Position Top", action: #selector(setTop), keyEquivalent: "")
            menu.addItem(withTitle: "Position Bottom", action: #selector(setBottom), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Hide Overlay", action: #selector(hideOverlay), keyEquivalent: "")
            for item in menu.items { item.target = self }
            panel.contentView?.menu = menu
        }
        rebuildRoot()
        layoutPanel()
        panel?.orderFrontRegardless()
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    private func rebuildRoot() {
        guard let monitor, let mapper, let settings else { return }
        let view: AnyView
        if settings.overlayMode == .performance {
            view = AnyView(PerformanceBarView(monitor: monitor, mapper: mapper, settings: settings, perf: PerfSampler.shared))
        } else {
            view = AnyView(CompactHUDView(monitor: monitor, mapper: mapper, settings: settings))
        }
        host?.rootView = view
        layoutPanel()
    }

    private func layoutPanel() {
        guard let panel, let settings, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        if settings.overlayMode == .performance {
            let width = frame.width * 0.92
            let height: CGFloat = 44
            let x = frame.midX - width / 2
            let y: CGFloat = settings.overlayEdge == .top
                ? frame.maxY - height - 6
                : frame.minY + 6
            panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
            panel.isMovableByWindowBackground = false
        } else {
            let size = NSSize(width: 300, height: 96)
            if let origin = settings.hudOrigin() {
                panel.setFrame(NSRect(origin: origin, size: size), display: true)
            } else {
                let origin = NSPoint(x: frame.maxX - 320, y: frame.maxY - 130)
                panel.setFrame(NSRect(origin: origin, size: size), display: true)
            }
            panel.isMovableByWindowBackground = true
        }
    }

    @objc private func openMain() { MenuBarController.shared.openMainWindow() }
    @objc private func setCompact() {
        settings?.overlayMode = .compact
        applyVisibility()
    }
    @objc private func setPerf() {
        settings?.overlayMode = .performance
        applyVisibility()
    }
    @objc private func setTop() {
        settings?.overlayEdge = .top
        layoutPanel()
    }
    @objc private func setBottom() {
        settings?.overlayEdge = .bottom
        layoutPanel()
    }
    @objc private func hideOverlay() {
        settings?.showOverlay = false
        applyVisibility()
    }
}

// Backward-compatible name used by older call sites.
typealias PlayHUDController = GamingOverlayController

// MARK: - Compact HUD

struct CompactHUDView: View {
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
                    batteryChip
                }
                Text(mapper.profile.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.mute)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    mappingChip
                    if KeepAwake.shared.isAsserting {
                        StatusChip(text: "AWAKE", color: Theme.accent)
                    }
                    Text("⌥⌘M")
                        .font(.caption2.monospaced())
                        .foregroundStyle(Theme.mute)
                }
            }
            Spacer()
            Button {
                settings.overlayMode = .performance
            } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Switch to Performance Bar")
            Button {
                MenuBarController.shared.openMainWindow()
            } label: {
                Image(systemName: "macwindow")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Show main window")
        }
        .padding(12)
        .frame(width: 288, height: 86)
        .background(.ultraThinMaterial.opacity(settings.overlayOpacity), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onDisappear { }
        .gesture(
            DragGesture()
                .onEnded { _ in
                    // Position saved via panel move observer alternative: poll frame
                }
        )
        .onAppear {
            // Persist compact origin when user drags (panel movable)
            NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: nil,
                queue: .main
            ) { note in
                guard let win = note.object as? NSWindow, win.isFloatingPanel else { return }
                Task { @MainActor in
                    if AppSettings.shared.overlayMode == .compact {
                        AppSettings.shared.saveHUDOrigin(win.frame.origin)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var batteryChip: some View {
        if let p = monitor.selected.batteryPercent {
            Button {
                if !monitor.selected.connected {
                    NotificationCenter.default.post(name: .mghGoPage, object: NavPage.setup.rawValue)
                    MenuBarController.shared.openMainWindow()
                }
            } label: {
                Text("\(p)%")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(OverlayStyle.battery(p))
            }
            .buttonStyle(.plain)
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

    @ViewBuilder
    private var mappingChip: some View {
        if mapper.enabled {
            if mapper.isLive { LiveBadge() }
            else if mapper.pausedByUser { StatusChip(text: "PAUSED", color: Theme.warn) }
            else { StatusChip(text: "ARMED", color: Theme.accent) }
        } else {
            StatusChip(text: "MAP OFF", color: Theme.mute)
        }
    }
}

// MARK: - Performance Bar

struct PerformanceBarView: View {
    @ObservedObject var monitor: ControllerMonitor
    @ObservedObject var mapper: InputMapper
    @ObservedObject var settings: AppSettings
    @ObservedObject var perf: PerfSampler

    var body: some View {
        HStack(spacing: 8) {
            if settings.metricController {
                MetricCapsule(
                    icon: "gamecontroller.fill",
                    title: monitor.selected.connected ? shortPadName : "Pad",
                    value: padValue,
                    color: monitor.selected.connected ? OverlayStyle.battery(monitor.selected.batteryPercent ?? 100) : Theme.bad,
                    help: monitor.selected.connected
                        ? "\(monitor.selected.title) · \(monitor.selected.battery)"
                        : "Controller disconnected — click to open Pairing"
                ) {
                    if !monitor.selected.connected {
                        NotificationCenter.default.post(name: .mghGoPage, object: NavPage.setup.rawValue)
                        MenuBarController.shared.openMainWindow()
                    } else {
                        MenuBarController.shared.openMainWindow()
                    }
                }
            }
            if settings.metricCPU {
                MetricCapsule(
                    icon: "cpu",
                    title: "CPU",
                    value: perf.snap.cpuPercent.map { String(format: "%.0f%%", $0) } ?? "—",
                    color: OverlayStyle.load(perf.snap.cpuPercent),
                    help: "Overall CPU via host_processor_info"
                ) { MenuBarController.shared.openMainWindow() }
            }
            if settings.metricMemory {
                MetricCapsule(
                    icon: "memorychip",
                    title: "MEM",
                    value: memValue,
                    color: OverlayStyle.load(perf.snap.memoryPressurePercent),
                    help: "Active+wired+compressed / physical"
                ) { MenuBarController.shared.openMainWindow() }
            }
            if settings.metricGPU {
                MetricCapsule(
                    icon: "cube",
                    title: "GPU",
                    value: gpuValue,
                    color: perf.snap.gpuAvailable ? OverlayStyle.load(perf.snap.gpuPercent) : Theme.mute,
                    help: perf.snap.gpuAvailable ? perf.snap.gpuNote : "GPU — needs permission/unavailable"
                ) { MenuBarController.shared.openMainWindow() }
            }
            if settings.metricPanel {
                MetricCapsule(
                    icon: "display",
                    title: "Panel",
                    value: perf.snap.panelHz.map { "\($0)Hz" } ?? "—",
                    color: Theme.accent,
                    help: "Display refresh rate — not game FPS (macOS cannot read arbitrary game FPS without injection)"
                ) { MenuBarController.shared.openMainWindow() }
            }
            if settings.metricGameCPU {
                MetricCapsule(
                    icon: "app.badge",
                    title: "Game",
                    value: gameValue,
                    color: Theme.accent,
                    help: "Frontmost app CPU % (not FPS): \(perf.snap.frontmostName.isEmpty ? "—" : perf.snap.frontmostName)"
                ) { MenuBarController.shared.openMainWindow() }
            }
            if settings.metricPing && settings.pingEnabled {
                MetricCapsule(
                    icon: "network",
                    title: "Ping",
                    value: perf.snap.pingMs.map { String(format: "%.0fms", $0) } ?? (perf.snap.pingOK ? "—" : "…"),
                    color: OverlayStyle.ping(perf.snap.pingMs),
                    help: "Latency to \(settings.pingHost)"
                ) { MenuBarController.shared.openMainWindow() }
            }
            if settings.metricMapping {
                MetricCapsule(
                    icon: "keyboard",
                    title: "Map",
                    value: mapValue,
                    color: mapColor,
                    help: "⌥⌘M pause/resume · \(mapper.profile.name)"
                ) { MenuBarController.shared.openMainWindow() }
            }
            if settings.metricAwake && KeepAwake.shared.isAsserting {
                MetricCapsule(
                    icon: "cup.and.saucer.fill",
                    title: "Awake",
                    value: "ON",
                    color: Theme.good,
                    help: "Display sleep prevented"
                ) { MenuBarController.shared.openMainWindow() }
            }
            Spacer(minLength: 0)
            Button {
                settings.overlayMode = .compact
            } label: {
                Image(systemName: "rectangle.compress.vertical")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.mute)
            }
            .buttonStyle(.plain)
            .help("Compact HUD")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial.opacity(settings.overlayOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .onTapGesture { MenuBarController.shared.openMainWindow() }
    }

    private var shortPadName: String {
        let t = monitor.selected.kind.shortLabel
        return t.count > 8 ? String(t.prefix(7)) : t
    }

    private var padValue: String {
        if !monitor.selected.connected { return "OFF" }
        if let p = monitor.selected.batteryPercent { return "\(p)%" }
        return "ON"
    }

    private var memValue: String {
        if let p = perf.snap.memoryPressurePercent {
            return String(format: "%.0f%%", p)
        }
        if let g = perf.snap.memoryUsedGB {
            return String(format: "%.1fG", g)
        }
        return "—"
    }

    private var gpuValue: String {
        if let p = perf.snap.gpuPercent { return String(format: "%.0f%%", p) }
        return "—"
    }

    private var gameValue: String {
        if let c = perf.snap.frontmostCPU { return String(format: "%.0f%%", c) }
        return "—"
    }

    private var mapValue: String {
        if !mapper.enabled { return "OFF" }
        if mapper.isLive { return "LIVE" }
        if mapper.pausedByUser { return "PAUSE" }
        return "ARM"
    }

    private var mapColor: Color {
        if !mapper.enabled { return Theme.mute }
        if mapper.isLive { return Theme.good }
        if mapper.pausedByUser { return Theme.warn }
        return Theme.accent
    }
}

struct MetricCapsule: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.mute)
                Text(value)
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

enum OverlayStyle {
    static func battery(_ p: Int) -> Color {
        if p <= 20 { return Theme.bad }
        if p <= 40 { return Theme.warn }
        return Theme.good
    }
    static func load(_ v: Double?) -> Color {
        guard let v else { return Theme.mute }
        if v >= 85 { return Theme.bad }
        if v >= 60 { return Theme.warn }
        return Theme.good
    }
    static func ping(_ ms: Double?) -> Color {
        guard let ms else { return Theme.mute }
        if ms < 50 { return Theme.good }
        if ms < 100 { return Theme.warn }
        return Theme.bad
    }
}
