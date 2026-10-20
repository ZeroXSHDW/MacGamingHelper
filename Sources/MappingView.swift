import AppKit
import SwiftUI

struct MappingPage: View {
    @EnvironmentObject private var mapper: InputMapper
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var settings: AppSettings
    @State private var newProfileName = "My profile"
    @State private var editControl: String = "Cross"
    @State private var selectedAppBundle = ""
    @State private var selectedProfileID = ""
    @State private var selectedOverlayMode: OverlayMode = .performance
    @State private var selectedShowOverlay = true
    @State private var selectedKeepAwake = false
    @State private var selectedAutoEnableMapping = false
    @State private var selectedPauseMapping = false

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
                        Text("Optional path for games that ignore a gamepad. Maps the selected pad to keys and mouse. Offline, no accounts.")
                            .foregroundStyle(Theme.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    BundledImage(name: "badge-mapping", maxHeight: 100, cornerRadius: 14)
                        .frame(width: 160)
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Toggle("Enable mapping", isOn: Binding(
                                get: { mapper.enabled },
                                set: { on in
                                    if on { _ = mapper.enableIfTrusted() } else { mapper.stop() }
                                }
                            ))
                            .toggleStyle(.switch)
                            .accessibilityLabel("Enable keyboard and mouse mapping")
                            Spacer()
                            if mapper.enabled {
                                if mapper.isLive { LiveBadge() }
                                else if mapper.pausedByUser { StatusChip(text: "PAUSED", color: Theme.warn) }
                                else { StatusChip(text: "ARMED", color: Theme.accent) }
                            }
                        }
                        Text("⌥⌘M pauses or resumes mapping. Optional auto-pause when the app is inactive (Settings).")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                        Toggle("Touchpad → mouse (click + move)", isOn: $settings.touchpadAsMouse)
                        Toggle("Hair-trigger L2/R2 (low click threshold)", isOn: $settings.hairTrigger)
                        if settings.hairTrigger {
                            HStack {
                                Text("Threshold")
                                Slider(value: $settings.hairTriggerThreshold, in: 0.05...0.35)
                                Text(String(format: "%.2f", settings.hairTriggerThreshold))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(Theme.mute)
                            }
                        }
                        if monitor.selected.motionAvailable {
                            Toggle("Gyro assist mouse (motion exposed)", isOn: $settings.gyroAssistMouse)
                        } else {
                            Text("Gyro assist unavailable — motion not exposed for this pad.")
                                .font(.caption)
                                .foregroundStyle(Theme.mute)
                        }

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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Aim stick → mouse")
                            .font(.headline)
                        Picker("Response curve", selection: $settings.stickCurve) {
                            ForEach(StickCurve.allCases) { c in
                                Text(c.title).tag(c)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Stick response curve")
                        HStack {
                            Text("Aim sensitivity")
                            Slider(value: $settings.aimSensitivity, in: 0.4...2.5)
                            Text(String(format: "%.2f", settings.aimSensitivity))
                                .font(.caption.monospaced())
                                .frame(width: 36)
                        }
                        Toggle("Invert look Y", isOn: $settings.invertLookY)
                        Text("Curves reshape right-stick mouse look after deadzone. Expo = fine aim near center.")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                        Text("FPS tip: lower pointer acceleration in System Settings → Mouse / Trackpad for cleaner aim.")
                            .font(.caption)
                            .foregroundStyle(Theme.warn)
                        PillButton(title: "Open Mouse settings") {
                            let urls = [
                                "x-apple.systempreferences:com.apple.Mouse-Settings.extension",
                                "x-apple.systempreferences:com.apple.preference.mouse",
                            ]
                            for s in urls {
                                if let u = URL(string: s), NSWorkspace.shared.open(u) { return }
                            }
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Combo macros")
                            .font(.headline)
                        Text("Hold a button + tap another to fire a key — for example L1 + Square → E. Add as many slots as you need.")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                        if mapper.profile.macros.isEmpty {
                            Text("No macros. Tap “Add macro” to create one.")
                                .font(.caption)
                                .foregroundStyle(Theme.mute)
                        } else {
                            ForEach(Array(mapper.profile.macros.enumerated()), id: \.offset) { index, _ in
                                macroRow(index)
                            }
                        }
                        HStack(spacing: 10) {
                            PillButton(title: "Add macro", primary: true) { mapper.addMacro() }
                            if !ProfileStore.isPreset(mapper.profile.id) {
                                PillButton(title: "Save profile with macros") { mapper.saveCurrentProfile() }
                            }
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Profiles")
                                .font(.headline)
                            Spacer()
                            PillButton(title: "Import…") { mapper.importProfileFromFile() }
                            PillButton(title: "Export…") { mapper.exportActiveProfile() }
                        }
                        Text("⌘⌥1 / ⌘⌥2 / ⌘⌥3 switch the first three profiles. Export saves a JSON file; Import adds it back.")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
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

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Game profiles (per-app)")
                            .font(.headline)
                        Text("When a saved app becomes the active window, Mac Gaming Helper applies its mapping, overlay and keep-awake settings automatically.")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                        if !mapper.frontmostAppName.isEmpty {
                            Text("Frontmost now: \(mapper.frontmostAppName)")
                                .font(.caption)
                                .foregroundStyle(Theme.ds4Blue)
                        }

                        HStack(spacing: 8) {
                            Picker("App", selection: $selectedAppBundle) {
                                if mapper.runningApps.isEmpty {
                                    Text("No running apps").tag("")
                                } else {
                                    ForEach(mapper.runningApps, id: \.bundleID) { app in
                                        Text(app.name).tag(app.bundleID)
                                    }
                                }
                            }
                            .frame(maxWidth: 220)
                            Picker("Mapping", selection: $selectedProfileID) {
                                Text("No mapping").tag("")
                                ForEach(mapper.profiles) { p in
                                    Text(p.name).tag(p.id)
                                }
                            }
                            .frame(maxWidth: 200)
                        }

                        Picker("Overlay", selection: $selectedOverlayMode) {
                            ForEach(OverlayMode.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Show overlay", isOn: $selectedShowOverlay)
                        Toggle("Keep display awake", isOn: $selectedKeepAwake)
                        Toggle("Auto-enable Mapping", isOn: $selectedAutoEnableMapping)
                        Toggle("Pause Mapping (Steam Input)", isOn: $selectedPauseMapping)

                        HStack(spacing: 10) {
                            PillButton(title: "Save for this app", primary: true) {
                                let name = mapper.runningApps.first(where: { $0.bundleID == selectedAppBundle })?.name ?? selectedAppBundle
                                mapper.rememberGameProfile(
                                    bundleID: selectedAppBundle,
                                    name: name,
                                    mappingProfileID: selectedProfileID.isEmpty ? nil : selectedProfileID,
                                    autoEnableMapping: selectedAutoEnableMapping,
                                    overlayMode: selectedOverlayMode,
                                    showOverlay: selectedShowOverlay,
                                    keepAwake: selectedKeepAwake,
                                    pauseMapping: selectedPauseMapping
                                )
                            }
                            .disabled(selectedAppBundle.isEmpty)
                            if mapper.gameProfile(for: selectedAppBundle) != nil {
                                Text("Editing existing profile")
                                    .font(.caption)
                                    .foregroundStyle(Theme.mute)
                            }
                        }

                        if !mapper.savedGameProfiles.isEmpty {
                            Divider()
                            Text("Saved")
                                .font(.subheadline.weight(.semibold))
                            ForEach(mapper.savedGameProfiles) { gp in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(gp.name.isEmpty ? gp.bundleID : gp.name)
                                            .font(.callout.weight(.semibold))
                                        Text(gp.bundleID)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(Theme.mute)
                                        HStack(spacing: 6) {
                                            if let pid = gp.mappingProfileID {
                                                StatusChip(text: shortProfileName(pid), color: Theme.accent)
                                            }
                                            StatusChip(text: gp.overlayMode == .performance ? "Perf" : "HUD", color: gp.showOverlay ? Theme.good : Theme.mute)
                                            if gp.keepAwake { StatusChip(text: "Awake", color: Theme.accent) }
                                            if gp.autoEnableMapping { StatusChip(text: "Auto-map", color: Theme.good) }
                                            if gp.pauseMapping { StatusChip(text: "Pause", color: Theme.warn) }
                                        }
                                    }
                                    Spacer()
                                    PillButton(title: "Remove", role: .destructive) {
                                        mapper.forgetGameProfile(bundleID: gp.bundleID)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } else {
                            Text("No app profiles yet. Pick a running app, choose its settings, then Save.")
                                .font(.caption)
                                .foregroundStyle(Theme.mute)
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
                        Text("• Bluetooth — pair the DualSense / DualShock 4 in System Settings.")
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
        .onChange(of: selectedAppBundle) { _, _ in loadSelectedProfile() }
    }

    private func loadSelectedProfile() {
        guard !selectedAppBundle.isEmpty, let gp = mapper.gameProfile(for: selectedAppBundle) else {
            selectedProfileID = ""
            selectedOverlayMode = .performance
            selectedShowOverlay = true
            selectedKeepAwake = false
            selectedAutoEnableMapping = false
            selectedPauseMapping = false
            return
        }
        selectedProfileID = gp.mappingProfileID ?? ""
        selectedOverlayMode = gp.overlayMode
        selectedShowOverlay = gp.showOverlay
        selectedKeepAwake = gp.keepAwake
        selectedAutoEnableMapping = gp.autoEnableMapping
        selectedPauseMapping = gp.pauseMapping
    }

    private func shortProfileName(_ id: String) -> String {
        let name = mapper.profiles.first(where: { $0.id == id })?.name ?? id
        return name.count > 18 ? String(name.prefix(17)) + "…" : name
    }

    @ViewBuilder
    private func macroRow(_ index: Int) -> some View {
        HStack(spacing: 6) {
            Toggle("", isOn: Binding(
                get: { mapper.profile.macros[index].enabled },
                set: { mapper.profile.macros[index].enabled = $0 }
            ))
            .labelsHidden()
            Picker("", selection: Binding(
                get: { mapper.profile.macros[index].holdControl },
                set: { mapper.profile.macros[index].holdControl = $0 }
            )) {
                ForEach(["L1", "R1", "L2", "R2"], id: \.self) { Text($0).tag($0) }
            }
            .frame(width: 70)
            Text("+").foregroundStyle(Theme.mute)
            Picker("", selection: Binding(
                get: { mapper.profile.macros[index].tapControl },
                set: { mapper.profile.macros[index].tapControl = $0 }
            )) {
                ForEach(["Square", "Cross", "Circle", "Triangle", "Share", "Options", "Create"], id: \.self) { Text($0).tag($0) }
            }
            .frame(width: 100)
            Text("→").foregroundStyle(Theme.mute)
            Picker("", selection: Binding(
                get: { mapper.profile.macros[index].keyCode },
                set: { code in
                    mapper.profile.macros[index].keyCode = code
                    mapper.profile.macros[index].keyName = KeyChoices.options.first(where: { $0.code == code })?.name ?? "Key"
                }
            )) {
                ForEach(KeyChoices.options, id: \.code) { Text($0.name).tag($0.code) }
            }
            .frame(width: 90)
            Spacer()
            PillButton(title: "Remove", role: .destructive) {
                mapper.removeMacro(at: index)
            }
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
