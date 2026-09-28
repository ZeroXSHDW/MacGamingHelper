import SwiftUI

enum NavPage: String, CaseIterable, Identifiable, Hashable {
    case play, controller, tester, mapping, launchers, setup, settings, help
    var id: String { rawValue }
    var title: String {
        switch self {
        case .play: "Play"
        case .controller: "Controller"
        case .tester: "Input Test"
        case .mapping: "Mapping"
        case .launchers: "Launchers"
        case .setup: "Pairing"
        case .settings: "Settings"
        case .help: "Help"
        }
    }
    var symbol: String {
        switch self {
        case .play: "play.circle.fill"
        case .controller: "gamecontroller.fill"
        case .tester: "waveform.path.ecg"
        case .mapping: "keyboard"
        case .launchers: "square.stack.3d.up.fill"
        case .setup: "wrench.and.screwdriver.fill"
        case .settings: "gearshape.fill"
        case .help: "questionmark.circle"
        }
    }
    var shortcutKey: KeyEquivalent {
        switch self {
        case .play: "1"
        case .controller: "2"
        case .tester: "3"
        case .mapping: "4"
        case .launchers: "5"
        case .setup: "6"
        case .settings: "7"
        case .help: "8"
        }
    }
    static var deskSection: [NavPage] { [.play, .controller, .tester, .mapping, .launchers] }
    static var setupSection: [NavPage] { [.setup, .settings, .help] }
}

struct RootView: View {
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var mapper: InputMapper
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var session: GameSession
    @EnvironmentObject private var launchers: LauncherShelf
    @State private var page: NavPage = .play
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
                if session.steamInputHint && mapper.enabled && !mapper.pausedByUser {
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                        Text("Steam/game frontmost — pause Mapping for Steam Input")
                            .font(.callout.weight(.semibold))
                        Spacer()
                        PillButton(title: "Pause", primary: true) { mapper.togglePauseHotkey() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.accent.opacity(0.18))
                }
                Group {
                    switch page {
                    case .play: PlayPage()
                    case .controller: ControllerPage()
                    case .tester: InputTesterPage()
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
            EasyFirstRunSheet(
                onFinished: { goPlay, startGaming in
                    settings.didShowWelcome = true
                    showWelcome = false
                    if goPlay {
                        page = .play
                        settings.lastTab = NavPage.play.rawValue
                    }
                    if startGaming {
                        EasyRun.startGaming(mapper: mapper, launchers: launchers, openSteam: false)
                    }
                },
                onPairing: {
                    settings.didShowWelcome = true
                    showWelcome = false
                    page = .setup
                    settings.lastTab = NavPage.setup.rawValue
                }
            )
            .environmentObject(monitor)
            .environmentObject(mapper)
            .environmentObject(settings)
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
        .onReceive(NotificationCenter.default.publisher(for: .mghProfileSlot)) { note in
            if let idx = note.object as? Int {
                mapper.selectProfileAtIndex(idx)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mghPrepSteam)) { _ in
            GameSession.prepSteamSession(mapper: mapper, launchers: launchers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mghToggleHUD)) { _ in
            GamingOverlayController.shared.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mghToggleOverlayMode)) { _ in
            GamingOverlayController.shared.toggleMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mghStartGaming)) { note in
            let steam = (note.object as? Bool) ?? false
            EasyRun.startGaming(mapper: mapper, launchers: launchers, openSteam: steam)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mghStopGaming)) { _ in
            EasyRun.stopGaming()
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

struct EasyFirstRunSheet: View {
    let onFinished: (_ goPlay: Bool, _ startGaming: Bool) -> Void
    let onPairing: () -> Void
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var mapper: InputMapper
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var perms = PermissionStatusModel()
    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Get ready in 3 steps")
                .font(.title.weight(.bold))
            Text("Step \(step + 1) of 3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)

            Group {
                switch step {
                case 0:
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1 · Permissions").font(.headline)
                        Text("macOS blocks silent grants — open each pane and enable Mac Gaming Helper.")
                            .font(.callout).foregroundStyle(Theme.mute)
                        PermissionStatusRow(
                            title: "Bluetooth",
                            detail: perms.bluetoothLabel,
                            ok: perms.bluetoothOK,
                            actionTitle: "Open",
                            action: { PermissionsHelper.openBluetoothPrivacy() }
                        )
                        PermissionStatusRow(
                            title: "Accessibility",
                            detail: perms.accessibilityOK ? "Granted (Mapping OK)" : "Needed only for Mapping",
                            ok: perms.accessibilityOK,
                            actionTitle: "Open",
                            action: { PermissionsHelper.openAccessibility() }
                        )
                        PermissionStatusRow(
                            title: "Notifications",
                            detail: perms.notificationsLabel,
                            ok: perms.notificationsOK,
                            actionTitle: "Open",
                            action: {
                                PermissionsHelper.requestNotificationAuth()
                                PermissionsHelper.openNotifications()
                            }
                        )
                        PillButton(title: "Open all permission panes") { EasyRun.openAllPermissionPanes() }
                    }
                case 1:
                    VStack(alignment: .leading, spacing: 10) {
                        Text("2 · Pair your controller").font(.headline)
                        Text(monitor.selected.connected
                             ? "Connected: \(monitor.selected.kind.shortLabel) — you’re good."
                             : "Prefer USB Micro-USB + hold PS if Bluetooth won’t list DualShock 4. Then Rediscover.")
                            .font(.callout).foregroundStyle(Theme.mute)
                            .fixedSize(horizontal: false, vertical: true)
                        HeroPadArt(connected: monitor.selected.connected, maxHeight: 120)
                            .frame(maxWidth: .infinity)
                        HStack {
                            PillButton(title: "Open Pairing coach", primary: true, action: onPairing)
                            PillButton(title: "Rediscover") { monitor.rediscover() }
                            PillButton(title: "Bluetooth") { PermissionsHelper.openBluetoothSettings() }
                        }
                    }
                default:
                    VStack(alignment: .leading, spacing: 10) {
                        Text("3 · Start gaming").font(.headline)
                        Text("One tap turns on the Performance Bar (top), keep-awake, and menu bar — then you’re ready to play.")
                            .font(.callout).foregroundStyle(Theme.mute)
                        PillButton(title: "Start gaming", primary: true) {
                            onFinished(true, true)
                        }
                        PillButton(title: "Start gaming + Steam Big Picture") {
                            EasyRun.startGaming(mapper: mapper, launchers: nil, openSteam: true)
                            onFinished(true, false)
                        }
                        PillButton(title: "Skip for now") {
                            onFinished(true, false)
                        }
                    }
                }
            }

            HStack {
                if step > 0 {
                    PillButton(title: "Back") { step -= 1 }
                }
                Spacer()
                if step < 2 {
                    PillButton(title: "Next", primary: true) { step += 1; perms.refresh() }
                }
            }
        }
        .padding(28)
        .frame(width: 520)
        .onAppear { perms.refresh() }
    }
}
