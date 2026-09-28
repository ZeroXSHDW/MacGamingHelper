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

    init() {
        // Ensure AppKit app lifecycle for CGEvent posting + window chrome.
        _ = NSApplication.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(monitor)
                .environmentObject(mapper)
                .environmentObject(launchers)
                .frame(minWidth: 920, minHeight: 640)
                .onAppear {
                    monitor.start()
                    launchers.refresh()
                    mapper.bind(monitor: monitor)
                }
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
