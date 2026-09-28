import AppKit
import SwiftUI

@main
enum MacGamingHelperMain {
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            let code = MainActor.assumeIsolated { SelfTest.run() }
            fflush(stdout)
            exit(code)
        }
        MacGamingHelperApp.main()
    }
}

struct MacGamingHelperApp: App {
    @StateObject private var monitor = ControllerMonitor()
    @StateObject private var mapper = InputMapper()
    @StateObject private var launchers = LauncherShelf()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var steam = SteamShelf()
    @StateObject private var session = GameSession()
    @StateObject private var heroic = HeroicShelf()

    init() {
        _ = NSApplication.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(monitor)
                .environmentObject(mapper)
                .environmentObject(launchers)
                .environmentObject(settings)
                .environmentObject(steam)
                .environmentObject(session)
                .environmentObject(heroic)
                .frame(minWidth: settings.focusModeController ? 720 : 960,
                       minHeight: settings.focusModeController ? 560 : 640)
                .onAppear {
                    monitor.attach(settings: settings)
                    monitor.start()
                    launchers.refresh()
                    mapper.bind(monitor: monitor, settings: settings)
                    MenuBarController.shared.bind(monitor: monitor, settings: settings, mapper: mapper, launchers: launchers)
                    MenuBarController.shared.applyVisibility()
                    GamingOverlayController.shared.bind(monitor: monitor, mapper: mapper, settings: settings)
                    session.start()
                    steam.refresh()
                    heroic.refresh()
                    NotificationCenter.default.addObserver(
                        forName: NSApplication.willTerminateNotification,
                        object: nil,
                        queue: .main
                    ) { _ in
                        Task { @MainActor in KeepAwake.shared.update(active: false) }
                    }
                    if settings.startMinimizedToMenuBar {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            for w in NSApp.windows where !(w is NSPanel) { w.orderOut(nil) }
                        }
                    }
                }
        }
        .defaultSize(width: 1120, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Go") {
                ForEach(NavPage.allCases) { item in
                    Button(item.title) {
                        NotificationCenter.default.post(name: .mghGoPage, object: item.rawValue)
                    }
                    .keyboardShortcut(item.shortcutKey, modifiers: .command)
                }
                Divider()
                Button("Rediscover Controllers") {
                    NotificationCenter.default.post(name: .mghRediscover, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
                Button("Pause / Resume Mapping") {
                    NotificationCenter.default.post(name: .mghToggleMappingPause, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
                Divider()
                Button("Mapping Profile 1") {
                    NotificationCenter.default.post(name: .mghProfileSlot, object: 0)
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
                Button("Mapping Profile 2") {
                    NotificationCenter.default.post(name: .mghProfileSlot, object: 1)
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
                Button("Mapping Profile 3") {
                    NotificationCenter.default.post(name: .mghProfileSlot, object: 2)
                }
                .keyboardShortcut("3", modifiers: [.command, .option])
                Divider()
                Button("Prep Steam Session") {
                    NotificationCenter.default.post(name: .mghPrepSteam, object: nil)
                }
                Button("Toggle Gaming Overlay") {
                    NotificationCenter.default.post(name: .mghToggleHUD, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.control, .option, .command])
                Button("Overlay: Compact / Performance") {
                    NotificationCenter.default.post(name: .mghToggleOverlayMode, object: nil)
                }
            }
        }
    }
}

extension Notification.Name {
    static let mghGoPage = Notification.Name("mghGoPage")
    static let mghRediscover = Notification.Name("mghRediscover")
    static let mghToggleMappingPause = Notification.Name("mghToggleMappingPause")
    static let mghProfileSlot = Notification.Name("mghProfileSlot")
    static let mghPrepSteam = Notification.Name("mghPrepSteam")
    static let mghToggleHUD = Notification.Name("mghToggleHUD")
    static let mghToggleOverlayMode = Notification.Name("mghToggleOverlayMode")
}

