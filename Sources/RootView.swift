import SwiftUI

enum NavPage: String, CaseIterable, Identifiable, Hashable {
    case controller, mapping, launchers, setup, settings, help
    var id: String { rawValue }
    var title: String {
        switch self {
        case .controller: "Controller"
        case .mapping: "Mapping"
        case .launchers: "Launchers"
        case .setup: "Pairing"
        case .settings: "Settings"
        case .help: "Help"
        }
    }
    var symbol: String {
        switch self {
        case .controller: "gamecontroller.fill"
        case .mapping: "keyboard"
        case .launchers: "square.stack.3d.up.fill"
        case .setup: "wrench.and.screwdriver.fill"
        case .settings: "gearshape.fill"
        case .help: "questionmark.circle"
        }
    }
    var shortcutKey: KeyEquivalent {
        switch self {
        case .controller: "1"
        case .mapping: "2"
        case .launchers: "3"
        case .setup: "4"
        case .settings: "5"
        case .help: "6"
        }
    }
    static var deskSection: [NavPage] { [.controller, .mapping, .launchers] }
    static var setupSection: [NavPage] { [.setup, .settings, .help] }
}

struct RootView: View {
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var mapper: InputMapper
    @EnvironmentObject private var settings: AppSettings
    @State private var page: NavPage = .controller
    @State private var showWelcome = false

    private var windowTitle: String {
        let s = monitor.selected
        if s.connected {
            let bat = s.batteryPercent.map { " · \($0)%" } ?? ""
            return "\(s.kind.shortLabel)\(bat) — \(Theme.name)"
        }
        return Theme.name
    }

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { page },
                set: { if let v = $0 { page = v; settings.lastTab = v.rawValue } }
            )) {
                Section("Desk") {
                    ForEach(NavPage.deskSection) { item in
                        Label(item.title, systemImage: item.symbol)
                            .tag(item)
                            .accessibilityLabel(item.title)
                    }
                }
                Section("Setup") {
                    ForEach(NavPage.setupSection) { item in
                        Label(item.title, systemImage: item.symbol)
                            .tag(item)
                            .accessibilityLabel(item.title)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
            .navigationTitle(Theme.name)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(monitor.selected.connected ? Theme.good : Theme.bad)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(monitor.selected.connected ? monitor.selected.kind.rawValue : "No pad")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(monitor.selected.connected
                        ? "Controller connected: \(monitor.selected.kind.rawValue), \(monitor.selected.battery)"
                        : "No controller connected")
                    if mapper.enabled {
                        HStack(spacing: 6) {
                            if mapper.isLive { LiveBadge() }
                            else if mapper.pausedByUser {
                                StatusChip(text: "PAUSED", color: Theme.warn)
                            } else {
                                StatusChip(text: "ARMED", color: Theme.accent)
                            }
                        }
                    }
                    Text("v\(Theme.version)")
                        .font(.caption2)
                        .foregroundStyle(Theme.mute)
                }
                .padding(12)
            }
        } detail: {
            VStack(spacing: 0) {
                if let banner = monitor.lowBatteryBanner {
                    HStack {
                        Image(systemName: "battery.25")
                            .accessibilityHidden(true)
                        Text(banner)
                            .font(.callout.weight(.semibold))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.warn.opacity(0.25))
                    .accessibilityLabel(banner)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Group {
                    switch page {
                    case .controller: ControllerPage()
                    case .mapping: MappingPage()
                    case .launchers: LaunchersPage()
                    case .setup: SetupPage()
                    case .settings: SettingsPage()
                    case .help: HelpPage()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(windowTitle)
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            if let saved = NavPage(rawValue: settings.lastTab) {
                page = saved
            }
            if !settings.didShowWelcome {
                showWelcome = true
            } else if settings.openPairingOnEmpty && !monitor.selected.connected && page == .controller {
                // keep controller empty tips; pairing one click away
            }
            applyFocusMode()
        }
        .onChange(of: settings.focusModeController) { _, _ in applyFocusMode() }
        .onChange(of: page) { _, new in
            settings.lastTab = new.rawValue
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeSheet(
                onPairing: {
                    settings.didShowWelcome = true
                    showWelcome = false
                    page = .setup
                    settings.lastTab = NavPage.setup.rawValue
                },
                onDismiss: {
                    settings.didShowWelcome = true
                    showWelcome = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .mghGoPage)) { note in
            if let raw = note.object as? String, let dest = NavPage(rawValue: raw) {
                page = dest
                settings.lastTab = dest.rawValue
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mghRediscover)) { _ in
            monitor.rediscover()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mghToggleMappingPause)) { _ in
            mapper.togglePauseHotkey()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: monitor.selected.connected)
        .animation(.easeInOut(duration: 0.25), value: monitor.lowBatteryBanner)
    }

    private func applyFocusMode() {
        // Soft hint via min frame; full window resize is best-effort.
        if settings.focusModeController {
            page = .controller
        }
    }
}

struct WelcomeSheet: View {
    let onPairing: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Mac Gaming Helper")
                .font(.title.weight(.bold))
            Text("Pair a DualShock 4, then watch the Controller desk light up. If Bluetooth won’t list the pad, use USB-first steps in Pairing.")
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
            HeroPadArt(connected: false, maxHeight: 140)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Stylized DualShock silhouette illustration")
            HStack {
                PillButton(title: "Open Pairing", primary: true, action: onPairing)
                PillButton(title: "Start exploring", action: onDismiss)
            }
        }
        .padding(28)
        .frame(width: 480)
        .accessibilityElement(children: .contain)
    }
}
