import SwiftUI

enum NavPage: String, CaseIterable, Identifiable, Hashable {
    case controller, mapping, launchers, setup, settings, help
    var id: String { rawValue }
    var title: String {
        switch self {
        case .controller: "Controller"
        case .mapping: "Mapping"
        case .launchers: "Launchers"
        case .setup: "Pairing / Setup"
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
}

struct RootView: View {
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var mapper: InputMapper
    @EnvironmentObject private var settings: AppSettings
    @State private var page: NavPage = .controller
    @State private var showWelcome = false

    var body: some View {
        NavigationSplitView {
            List(NavPage.allCases, selection: Binding(
                get: { page },
                set: { if let v = $0 { page = v } }
            )) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationTitle(Theme.name)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(monitor.selected.connected ? Theme.good : Theme.bad)
                            .frame(width: 8, height: 8)
                        Text(monitor.selected.connected ? monitor.selected.kind.rawValue : "No pad")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    if mapper.enabled {
                        Text("Mapping ON")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.warn)
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
                        Text(banner)
                            .font(.callout.weight(.semibold))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.warn.opacity(0.25))
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
            }
        }
        .onAppear {
            if !settings.didShowWelcome {
                showWelcome = true
            } else if settings.openPairingOnEmpty && !monitor.selected.connected {
                page = .setup
            }
        }
        .onChange(of: monitor.selected.connected) { _, connected in
            if !connected && settings.openPairingOnEmpty && page == .controller {
                // Stay on controller with empty tips; pairing is one click away.
            }
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeSheet(
                onPairing: {
                    settings.didShowWelcome = true
                    showWelcome = false
                    page = .setup
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
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mghRediscover)) { _ in
            monitor.rediscover()
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
            Text("Pair a DualShock 4, then watch the Controller desk light up. If Bluetooth won’t list the pad, use USB-first steps in Pairing / Setup.")
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
            HeroPadArt(connected: false, maxHeight: 140)
                .frame(maxWidth: .infinity)
            HStack {
                PillButton(title: "Open Pairing / Setup", primary: true, action: onPairing)
                PillButton(title: "Start exploring", action: onDismiss)
            }
        }
        .padding(28)
        .frame(width: 480)
    }
}
