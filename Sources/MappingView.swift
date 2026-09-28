import SwiftUI

struct MappingPage: View {
    @EnvironmentObject private var mapper: InputMapper
    @EnvironmentObject private var monitor: ControllerMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Keyboard & mouse mapping")
                    .font(.largeTitle.weight(.semibold))
                Text("Optional path for games that ignore DualShock 4. Maps the selected pad to keys and mouse. Offline, no accounts.")
                    .foregroundStyle(Theme.mute)

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable mapping", isOn: Binding(
                            get: { mapper.enabled },
                            set: { on in
                                if on {
                                    _ = mapper.enableIfTrusted()
                                } else {
                                    mapper.stop()
                                }
                            }
                        ))
                        .toggleStyle(.switch)

                        HStack {
                            Circle()
                                .fill(mapper.accessibilityTrusted ? Theme.good : Theme.warn)
                                .frame(width: 8, height: 8)
                            Text(mapper.accessibilityTrusted
                                 ? "Accessibility granted — Mapping can post keys / mouse"
                                 : "Accessibility required. Deny safely leaves Mapping off.")
                                .font(.callout)
                            Spacer()
                            PillButton(title: "Open Accessibility") { mapper.openAccessibilitySettings() }
                            PillButton(title: "Recheck") {
                                mapper.refreshTrust()
                                if mapper.enabled && !mapper.accessibilityTrusted {
                                    mapper.stop()
                                }
                            }
                        }

                        if !mapper.accessibilityTrusted {
                            Text("Path: System Settings → Privacy & Security → Accessibility → enable Mac Gaming Helper → Recheck. Until then Mapping stays disabled.")
                                .font(.caption)
                                .foregroundStyle(Theme.warn)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(mapper.lastAction)
                            .font(.callout.monospaced())
                            .foregroundStyle(Theme.ds4Blue)

                        if monitor.selected.connected {
                            Text("Driving: \(monitor.selected.title)")
                                .font(.caption)
                                .foregroundStyle(Theme.mute)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Profiles")
                            .font(.headline)
                        ForEach(MappingProfile.presets) { preset in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name).font(.callout.weight(.semibold))
                                    Text("\(preset.bindings.count) bindings · deadzone \(String(format: "%.2f", preset.deadzone))")
                                        .font(.caption)
                                        .foregroundStyle(Theme.mute)
                                }
                                Spacer()
                                if mapper.profile.id == preset.id {
                                    Text("Active")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.accent)
                                }
                                PillButton(title: "Use", primary: mapper.profile.id != preset.id) {
                                    mapper.selectPreset(preset)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Divider()
                        Text("Stick → key threshold")
                        Slider(value: $mapper.stickThreshold, in: 0.15...0.75)
                        Text(String(format: "%.2f", mapper.stickThreshold))
                            .font(.caption.monospaced())
                            .foregroundStyle(Theme.mute)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active bindings — \(mapper.profile.name)")
                            .font(.headline)
                        ForEach(mapper.profile.bindings) { b in
                            HStack {
                                Text(b.control)
                                    .font(.callout.monospaced())
                                    .frame(width: 140, alignment: .leading)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(Theme.mute)
                                Text(label(for: b))
                                    .font(.callout)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Permissions")
                            .font(.headline)
                        Text("• Bluetooth — pair the DualShock 4 in System Settings.")
                        Text("• Accessibility — required only when keyboard/mouse mapping is enabled (this app posts CGEvents).")
                        Text("• Input Monitoring — usually not required for Game Controller readouts; grant if macOS prompts.")
                        Text("Steam Input is still preferred for Steam games; use mapping for non-gamepad titles.")
                            .foregroundStyle(Theme.mute)
                    }
                    .font(.callout)
                }
            }
            .padding(28)
        }
    }

    private func label(for b: MappingBinding) -> String {
        switch b.target {
        case .key: return b.keyName ?? "Key \(b.keyCode ?? 0)"
        case .mouseMove: return "Mouse move ×\(String(format: "%.0f", b.scale))"
        case .mouseButton: return b.keyName ?? "Mouse button"
        case .scroll: return "Scroll"
        case .none: return "—"
        }
    }
}
