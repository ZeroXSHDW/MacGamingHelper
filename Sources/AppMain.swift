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
                .frame(minWidth: 920, minHeight: 640)
                .onAppear {
                    monitor.attach(settings: settings)
                    monitor.start()
                    launchers.refresh()
                    mapper.bind(monitor: monitor, settings: settings)
                    MenuBarController.shared.bind(monitor: monitor, settings: settings)
                    MenuBarController.shared.applyVisibility()
                    if settings.startMinimizedToMenuBar {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            for w in NSApp.windows { w.orderOut(nil) }
                        }
                    }
                }
        }
        .defaultSize(width: 1100, height: 720)
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
            }
        }
    }
}

extension Notification.Name {
    static let mghGoPage = Notification.Name("mghGoPage")
    static let mghRediscover = Notification.Name("mghRediscover")
}

/// Tiny bridge so RootView can receive menu shortcuts.
