import AppKit
import Foundation
import SwiftUI

/// One control in the guided Pad Check. The checklist is sticky: once a
/// control is seen, it stays checked until the user resets the check or
/// connects a different pad.
struct PadCheckItem: Identifiable, Equatable {
    let id: String
    let title: String
    let hint: String
    var done: Bool = false
}

@MainActor
final class PadCheckModel: ObservableObject {
    @Published private(set) var items: [PadCheckItem]
    @Published private(set) var completedAt: Date?
    @Published private(set) var lastDetected: String = ""
    @Published private(set) var padTitle: String = ""

    private var lastPadID = ""

    init(kind: PadKind) {
        items = Self.items(for: kind)
    }

    var doneCount: Int { items.filter { $0.done }.count }
    var total: Int { items.count }
    var isComplete: Bool { !items.isEmpty && items.allSatisfy { $0.done } }

    static func items(for kind: PadKind) -> [PadCheckItem] {
        let face = kind.face
        var list: [PadCheckItem] = [
            .init(id: "leftStick", title: "Left stick", hint: "Push any direction"),
            .init(id: "rightStick", title: "Right stick", hint: "Push any direction"),
            .init(id: "faceA", title: face.a, hint: "Face button"),
            .init(id: "faceB", title: face.b, hint: "Face button"),
            .init(id: "faceX", title: face.x, hint: "Face button"),
            .init(id: "faceY", title: face.y, hint: "Face button"),
            .init(id: "l1", title: "L1", hint: "Left bumper"),
            .init(id: "r1", title: "R1", hint: "Right bumper"),
            .init(id: "l2", title: "L2", hint: "Left trigger"),
            .init(id: "r2", title: "R2", hint: "Right trigger"),
            .init(id: "dpadUp", title: "D-pad Up", hint: "Directional pad"),
            .init(id: "dpadDown", title: "D-pad Down", hint: "Directional pad"),
            .init(id: "dpadLeft", title: "D-pad Left", hint: "Directional pad"),
            .init(id: "dpadRight", title: "D-pad Right", hint: "Directional pad"),
            .init(id: "l3", title: "L3", hint: "Press left stick"),
            .init(id: "r3", title: "R3", hint: "Press right stick"),
        ]
        if kind.isPlayStation {
            list.append(.init(id: "touchpad", title: "Touchpad", hint: "Click the touchpad"))
        }
        list.append(.init(id: "options", title: kind.isPlayStation ? "Options" : "Menu", hint: "Menu button"))
        list.append(.init(
            id: "create",
            title: kind == .dualSense ? "Create" : (kind == .dualShock4 ? "Share" : "View"),
            hint: "View / share button"
        ))
        return list
    }

    func reset(for kind: PadKind) {
        items = Self.items(for: kind)
        completedAt = nil
        lastDetected = ""
        lastPadID = ""
        padTitle = ""
    }

    func ingest(_ snap: ControllerSnapshot) {
        guard snap.connected else {
            if !lastPadID.isEmpty {
                reset(for: snap.kind)
            }
            padTitle = ""
            return
        }

        if snap.id != lastPadID {
            lastPadID = snap.id
            items = Self.items(for: snap.kind)
            completedAt = nil
            lastDetected = ""
        }
        padTitle = snap.title

        var changed = false
        for index in items.indices where !items[index].done {
            if Self.matches(items[index].id, snap: snap) {
                items[index].done = true
                lastDetected = items[index].title
                changed = true
            }
        }
        if changed, isComplete, completedAt == nil {
            completedAt = Date()
        }
    }

    static func matches(_ id: String, snap: ControllerSnapshot) -> Bool {
        let buttons = Set(snap.buttons)
        switch id {
        case "leftStick":
            return hypot(snap.lx, snap.ly) > 0.40
        case "rightStick":
            return hypot(snap.rx, snap.ry) > 0.40
        case "faceA":
            return buttons.contains(snap.kind.face.a)
        case "faceB":
            return buttons.contains(snap.kind.face.b)
        case "faceX":
            return buttons.contains(snap.kind.face.x)
        case "faceY":
            return buttons.contains(snap.kind.face.y)
        case "l1":
            return buttons.contains("L1")
        case "r1":
            return buttons.contains("R1")
        case "l2":
            return snap.lt > 0.50 || buttons.contains("L2")
        case "r2":
            return snap.rt > 0.50 || buttons.contains("R2")
        case "dpadUp":
            return buttons.contains("Up") || buttons.contains("D-pad Up")
        case "dpadDown":
            return buttons.contains("Down") || buttons.contains("D-pad Down")
        case "dpadLeft":
            return buttons.contains("Left") || buttons.contains("D-pad Left")
        case "dpadRight":
            return buttons.contains("Right") || buttons.contains("D-pad Right")
        case "l3":
            return buttons.contains("L3")
        case "r3":
            return buttons.contains("R3")
        case "touchpad":
            return snap.touchpadPressed || buttons.contains("Touchpad")
        case "options":
            return buttons.contains("Options") || buttons.contains("Menu")
        case "create":
            return buttons.contains("Create") || buttons.contains("Share") || buttons.contains("View")
        default:
            return false
        }
    }

    func report(for snap: ControllerSnapshot) -> String {
        let missing = items.filter { !$0.done }.map { $0.title }
        let result = isComplete ? "PASS" : "INCOMPLETE"
        return """
        Mac Gaming Helper — Pad Check
        Pad: \(snap.title)
        Kind: \(snap.kind.rawValue)
        Transport: \(snap.transportLabel)
        Battery: \(snap.battery)
        Player: \(snap.playerIndex >= 0 ? "P\(snap.playerIndex + 1)" : "unset")
        Result: \(result) — \(doneCount)/\(total) controls verified
        Missing: \(missing.isEmpty ? "none" : missing.joined(separator: ", "))
        Checked: \(Date().formatted(date: .abbreviated, time: .standard))
        """
    }
}

struct ControllerCheckSheet: View {
    @ObservedObject var monitor: ControllerMonitor
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PadCheckModel(kind: .dualSense)
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ProgressView(value: Double(model.doneCount), total: Double(max(model.total, 1)))
                .tint(model.isComplete ? Theme.good : Theme.accent)

            if !monitor.selected.connected {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Controller disconnected").font(.headline)
                        Text("Reconnect USB or Bluetooth, then press a button to continue the check.")
                            .font(.callout)
                            .foregroundStyle(Theme.mute)
                    }
                }
                Spacer()
            } else {
                if model.isComplete {
                    completeBanner
                }
                grid
            }

            footer
        }
        .padding(24)
        .frame(width: 680, height: 660)
        .onAppear {
            model.reset(for: monitor.selected.kind)
            model.ingest(monitor.selected)
        }
        .onChange(of: monitor.selected) { _, snap in
            model.ingest(snap)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pad Check")
                    .font(.largeTitle.weight(.bold))
                Text("Press each control once. It checks off automatically — no timers.")
                    .foregroundStyle(Theme.mute)
                if !model.padTitle.isEmpty {
                    Text(model.padTitle)
                        .font(.caption)
                        .foregroundStyle(Theme.mute)
                }
            }
            Spacer()
            StatusChip(
                text: "\(model.doneCount)/\(model.total)",
                color: model.isComplete ? Theme.good : Theme.accent
            )
        }
    }

    private var completeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(Theme.good)
            VStack(alignment: .leading, spacing: 2) {
                Text("All controls verified")
                    .font(.headline)
                Text("Your pad is ready. Copy the report if you want a record.")
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.good.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                ForEach(model.items) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.done ? Theme.good : Theme.mute)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.callout.weight(.semibold))
                            Text(item.hint)
                                .font(.caption2)
                                .foregroundStyle(Theme.mute)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(
                        item.done ? Theme.good.opacity(0.12) : Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .animation(.easeOut(duration: 0.15), value: item.done)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.title), \(item.done ? "verified" : "not yet verified")")
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            PillButton(title: "Reset check") {
                model.reset(for: monitor.selected.kind)
                model.ingest(monitor.selected)
            }
            PillButton(title: copied ? "Copied" : "Copy report") {
                copyReport()
            }
            .disabled(!monitor.selected.connected)
            Spacer()
            if !model.lastDetected.isEmpty {
                Text("Last: \(model.lastDetected)")
                    .font(.caption)
                    .foregroundStyle(Theme.mute)
            }
            PillButton(title: "Done", primary: true) { dismiss() }
        }
    }

    private func copyReport() {
        let report = model.report(for: monitor.selected)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}
