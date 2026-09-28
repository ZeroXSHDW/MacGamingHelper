import SwiftUI

/// Live press log + stick trails to verify every DualShock control before a match.
@MainActor
final class InputTesterModel: ObservableObject {
    struct Event: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let at: Date
    }

    @Published var events: [Event] = []
    @Published var lastFlash: String = ""
    private var lastButtons: Set<String> = []

    func ingest(_ snap: ControllerSnapshot, settings: AppSettings) {
        guard snap.connected else {
            lastButtons = []
            return
        }
        let now = Set(snap.buttons)
        let pressed = now.subtracting(lastButtons)
        for name in pressed.sorted() {
            events.insert(Event(label: name, at: Date()), at: 0)
            lastFlash = name
            GameAudio.play(.buttonBeep, settings: settings)
        }
        if events.count > 40 { events = Array(events.prefix(40)) }
        lastButtons = now
    }

    func clear() {
        events = []
        lastFlash = ""
        lastButtons = []
    }
}

struct InputTesterPage: View {
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var model = InputTesterModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Live Input Tester")
                            .font(.largeTitle.weight(.bold))
                        Text("Mash every DualShock control before a match. Stick trails + recent press log.")
                            .foregroundStyle(Theme.mute)
                    }
                    Spacer()
                    PillButton(title: "Clear", primary: true) { model.clear() }
                }

                if monitor.selected.connected {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 160)
                        Text(model.lastFlash.isEmpty ? "Waiting for a press…" : model.lastFlash)
                            .font(.system(size: model.lastFlash.isEmpty ? 22 : 48, weight: .bold, design: .rounded))
                            .foregroundStyle(model.lastFlash.isEmpty ? Theme.mute : Theme.ds4Blue)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: model.lastFlash)
                    }
                    .accessibilityLabel(model.lastFlash.isEmpty ? "Waiting for button press" : "Last pressed \(model.lastFlash)")

                    DualShockDiagram(snap: monitor.selected)
                        .accessibilityLabel("Live pad diagram")

                    HStack(spacing: 24) {
                        trail(title: "Left", x: monitor.selected.lx, y: monitor.selected.ly)
                        trail(title: "Right", x: monitor.selected.rx, y: monitor.selected.ry)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(format: "L2 %.2f   R2 %.2f", monitor.selected.lt, monitor.selected.rt))
                                .font(.caption.monospaced())
                            Toggle("Beep on press", isOn: $settings.audioTesterBeeps)
                                .toggleStyle(.switch)
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recent presses")
                                .font(.headline)
                            if model.events.isEmpty {
                                Text("No presses yet.").foregroundStyle(Theme.mute)
                            } else {
                                ForEach(model.events) { ev in
                                    HStack {
                                        Text(ev.label).font(.callout.monospaced().weight(.semibold))
                                        Spacer()
                                        Text(ev.at, style: .time).font(.caption2).foregroundStyle(Theme.mute)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Card {
                        Text("Connect a DualShock 4, then press buttons here to verify the pad.")
                            .foregroundStyle(Theme.mute)
                    }
                    HeroPadArt(connected: false, maxHeight: 160)
                }
            }
            .padding(28)
        }
        .background(Theme.heroGradient.opacity(0.25))
        .onChange(of: monitor.selected) { _, snap in
            model.ingest(snap, settings: settings)
        }
        .onAppear {
            model.ingest(monitor.selected, settings: settings)
        }
    }

    private func trail(title: String, x: Double, y: Double) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption.weight(.semibold))
            ZStack {
                Circle().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 2).frame(width: 90, height: 90)
                Circle().fill(Theme.ds4Blue).frame(width: 12, height: 12)
                    .offset(x: CGFloat(x) * 34, y: CGFloat(-y) * 34)
                    .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.8), value: x)
            }
            Text(String(format: "%+.2f,%+.2f", x, y)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.mute)
        }
    }
}
