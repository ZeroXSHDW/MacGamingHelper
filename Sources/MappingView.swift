import SwiftUI

struct MappingPage: View {
    @EnvironmentObject private var mapper: InputMapper
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var settings: AppSettings
    @State private var newProfileName = "My profile"
    @State private var editControl: String = "Cross"

    private let editableControls = [
        "Cross", "Circle", "Square", "Triangle",
        "L1", "R1", "L2", "R2", "Share", "Options",
        "Up", "Down", "Left", "Right",
        "LeftStickUp", "LeftStickDown", "LeftStickLeft", "LeftStickRight",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keyboard & mouse mapping")
                            .font(.largeTitle.weight(.bold))
                            .tracking(-0.4)
                        Text("Optional path for games that ignore DualShock 4. Maps the selected pad to keys and mouse. Offline, no accounts.")
                            .foregroundStyle(Theme.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    BundledImage(name: "badge-mapping", maxHeight: 100, cornerRadius: 14)
                        .frame(width: 160)
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable mapping", isOn: Binding(
                            get: { mapper.enabled },
                            set: { on in
                                if on { _ = mapper.enableIfTrusted() } else { mapper.stop() }
                            }
                        ))
                        .toggleStyle(.switch)

                        Toggle("Touchpad → mouse (click + move)", isOn: $settings.touchpadAsMouse)

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
                                if mapper.enabled && !mapper.accessibilityTrusted { mapper.stop() }
                            }
                        }

                        if !mapper.accessibilityTrusted {
                            Text("Path: System Settings → Privacy & Security → Accessibility → enable Mac Gaming Helper → Recheck.")
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
                        ForEach(mapper.profiles) { preset in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name).font(.callout.weight(.semibold))
                                    Text("\(preset.bindings.count) bindings · deadzone \(String(format: "%.2f", preset.deadzone))\(ProfileStore.isPreset(preset.id) ? "" : " · custom")")
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
                        HStack {
                            TextField("New profile name", text: $newProfileName)
                                .textFieldStyle(.roundedBorder)
                            PillButton(title: "Duplicate active", primary: true) {
                                let name = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                                mapper.duplicateAsCustom(named: name.isEmpty ? "Custom" : name)
                            }
                            if !ProfileStore.isPreset(mapper.profile.id) {
                                PillButton(title: "Save") { mapper.saveCurrentProfile() }
                                PillButton(title: "Delete", role: .destructive) { mapper.deleteCurrentIfCustom() }
                            }
                        }
                    }
                }

                if !ProfileStore.isPreset(mapper.profile.id) {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Edit “\(mapper.profile.name)”")
                                .font(.headline)
                            HStack {
                                Picker("Control", selection: $editControl) {
                                    ForEach(editableControls, id: \.self) { Text($0).tag($0) }
                                }
                                .frame(maxWidth: 220)
                                Picker("Key", selection: Binding(
                                    get: {
                                        mapper.profile.bindings.first(where: { $0.control == editControl && $0.target == .key })?.keyCode ?? UInt16(49)
                                    },
                                    set: { code in
                                        let name = KeyChoices.options.first(where: { $0.code == code })?.name ?? "Key"
                                        mapper.updateBindingKey(control: editControl, code: code, name: name)
                                    }
                                )) {
                                    ForEach(KeyChoices.options, id: \.code) { opt in
                                        Text(opt.name).tag(opt.code)
                                    }
                                }
                                .frame(maxWidth: 160)
                                PillButton(title: "Save profile", primary: true) { mapper.saveCurrentProfile() }
                            }
                            Text("Changes apply immediately while this custom profile is active. Save writes JSON to Application Support.")
                                .font(.caption)
                                .foregroundStyle(Theme.mute)
                        }
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
        .background(Theme.heroGradient.opacity(0.2))
        .onAppear { mapper.reloadProfiles() }
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
