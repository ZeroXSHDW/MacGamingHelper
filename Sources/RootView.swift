import SwiftUI

enum NavPage: String, CaseIterable, Identifiable, Hashable {
    case controller, mapping, launchers, setup, help
    var id: String { rawValue }
    var title: String {
        switch self {
        case .controller: "Controller"
        case .mapping: "Mapping"
        case .launchers: "Launchers"
        case .setup: "Pairing / Setup"
        case .help: "Help"
        }
    }
    var symbol: String {
        switch self {
        case .controller: "gamecontroller.fill"
        case .mapping: "keyboard"
        case .launchers: "square.stack.3d.up.fill"
        case .setup: "wrench.and.screwdriver.fill"
        case .help: "questionmark.circle"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var mapper: InputMapper
    @State private var page: NavPage = .controller

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
            switch page {
            case .controller: ControllerPage()
            case .mapping: MappingPage()
            case .launchers: LaunchersPage()
            case .setup: SetupPage()
            case .help: HelpPage()
            }
        }
    }
}
