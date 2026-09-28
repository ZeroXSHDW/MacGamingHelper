import AppKit
import SwiftUI

struct SettingsPage: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var mapper: InputMapper
    @State private var updateInfo: UpdateInfo?
    @State private var checkingUpdate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.largeTitle.weight(.bold))
                    .tracking(-0.4)
                Text("Menu bar, login item, deadzones, light bar preference, and updates.")
                    .foregroundStyle(Theme.mute)

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("General")
                            .font(.headline)
                        Toggle("Show in menu bar", isOn: $settings.showMenuBar)
                            .onChange(of: settings.showMenuBar) { _, _ in
                                MenuBarController.shared.applyVisibility()
                            }
                        Toggle("Gaming Overlay (always-on-top)", isOn: $settings.showOverlay)
                        Toggle("Gaming session active (prevent display sleep)", isOn: $settings.gamingSessionActive)
                        if KeepAwake.shared.isAsserting {
                            Text("Keep-awake assertion is active.")
                                .font(.caption)
                                .foregroundStyle(Theme.good)
                        }
                        Toggle("Start minimized to menu bar", isOn: $settings.startMinimizedToMenuBar)
                        Toggle("Open Pairing coach when no pad is connected", isOn: $settings.openPairingOnEmpty)
                        Toggle("Low-battery alerts (≤20%)", isOn: $settings.lowBatteryAlerts)
                        Toggle("Auto-pause Mapping when app is inactive", isOn: $settings.pauseMappingWhenInactive)
                        Toggle("Focus mode (Controller-first)", isOn: $settings.focusModeController)

                        Divider()
                        Toggle("Launch at login", isOn: Binding(
                            get: { settings.launchAtLoginEnabled },
                            set: { settings.setLaunchAtLogin($0) }
                        ))
                        Text(settings.launchAtLoginNote)
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                        PillButton(title: "Refresh login-item status") { settings.refreshLoginItemState() }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sticks & triggers")
                            .font(.headline)
                        labeledSlider("Stick deadzone", value: $settings.stickDeadzone, range: 0.02...0.45)
                        labeledSlider("Trigger deadzone", value: $settings.triggerDeadzone, range: 0.02...0.40)
                        labeledSlider("Stick / mouse sensitivity", value: $settings.stickSensitivity, range: 0.4...2.5)
                        Text("Deadzone rings appear on the Controller diagram. Sensitivity scales mapping mouse move.")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Light bar preference")
                            .font(.headline)
                        HStack {
                            Text("Preferred tint")
                            Slider(value: $settings.preferredLightHue, in: 0...1)
                            Circle()
                                .fill(Color(hue: settings.preferredLightHue, saturation: 0.85, brightness: 0.95))
                                .frame(width: 22, height: 22)
                        }
                        HStack {
                            PillButton(title: "Apply to pad now", primary: true) {
                                monitor.lightHue = settings.preferredLightHue
                                monitor.applyLightBar()
                            }
                            PillButton(title: "Use on Controller page") {
                                monitor.lightHue = settings.preferredLightHue
                            }
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Updates")
                            .font(.headline)
                        Text("Current version \(Theme.version) · checks GitHub ZeroXSHDW/MacGamingHelper")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                        HStack {
                            PillButton(title: checkingUpdate ? "Checking…" : "Check for updates", primary: true) {
                                checkingUpdate = true
                                Task {
                                    let info = await UpdateChecker.check()
                                    await MainActor.run {
                                        updateInfo = info
                                        checkingUpdate = false
                                    }
                                }
                            }
                            if let info = updateInfo, info.isNewer, let url = info.htmlURL {
                                PillButton(title: "Open releases") { NSWorkspace.shared.open(url) }
                            }
                        }
                        if let info = updateInfo {
                            Text(info.message)
                                .font(.callout)
                                .foregroundStyle(info.isNewer ? Theme.warn : Theme.mute)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Overlay & performance")
                            .font(.headline)
                        Toggle("Show Gaming Overlay", isOn: $settings.showOverlay)
                        Picker("Mode", selection: $settings.overlayMode) {
                            ForEach(OverlayMode.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Picker("Bar position", selection: $settings.overlayEdge) {
                            ForEach(OverlayEdge.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        HStack {
                            Text("Opacity")
                            Slider(value: $settings.overlayOpacity, in: 0.45...1.0)
                            Text(String(format: "%.0f%%", settings.overlayOpacity * 100))
                                .font(.caption.monospaced())
                                .foregroundStyle(Theme.mute)
                                .frame(width: 40)
                        }
                        Toggle("Auto-show on gaming session / Prep Steam", isOn: $settings.overlayAutoShowOnSession)
                        Toggle("Auto-hide when no pad and session off", isOn: $settings.overlayAutoHideIdle)
                        Divider()
                        Text("Metrics")
                            .font(.subheadline.weight(.semibold))
                        Toggle("Controller", isOn: $settings.metricController)
                        Toggle("CPU", isOn: $settings.metricCPU)
                        Toggle("Memory", isOn: $settings.metricMemory)
                        Toggle("GPU (best-effort)", isOn: $settings.metricGPU)
                        Toggle("Panel Hz (not game FPS)", isOn: $settings.metricPanel)
                        Toggle("Frontmost Game CPU %", isOn: $settings.metricGameCPU)
                        Toggle("Ping", isOn: $settings.metricPing)
                        Toggle("Mapping state", isOn: $settings.metricMapping)
                        Toggle("Keep-awake", isOn: $settings.metricAwake)
                        Divider()
                        Toggle("Ping enabled", isOn: $settings.pingEnabled)
                        HStack {
                            Text("Ping host")
                            TextField("1.1.1.1", text: $settings.pingHost)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 220)
                        }
                        Text("Panel shows display refresh — never invents FPS for other apps. GPU uses IOKit when available.")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                        Text("Hotkey: ⌃⌥⌘P toggles overlay · right-click bar for mode/position.")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Audio cues")
                            .font(.headline)
                        Toggle("Connect / disconnect sounds", isOn: $settings.audioConnectCues)
                        Toggle("Low battery sound", isOn: $settings.audioLowBatteryCue)
                        Toggle("Input tester beeps", isOn: $settings.audioTesterBeeps)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Diagnostics")
                            .font(.headline)
                        Text("Copyable support dump: OS, app version, pads, permissions, last rediscover.")
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                        HStack {
                            PillButton(title: "Copy diagnostics", primary: true) {
                                let text = Diagnostics.dump(monitor: monitor, mapper: mapper, settings: settings)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                            }
                            PillButton(title: "Export to Desktop") {
                                _ = Diagnostics.exportToDesktop(monitor: monitor, mapper: mapper, settings: settings)
                            }
                        }
                        .accessibilityLabel("Copy or export diagnostics")
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keyboard shortcuts")
                            .font(.headline)
                        Text("⌘1–⌘8 tabs · ⌘R Rediscover · ⌥⌘M Pause Mapping · ⌃⌥⌘P Overlay · ⌘⌥1–3 profiles")
                            .font(.callout)
                            .foregroundStyle(Theme.mute)
                    }
                }
            }
            .padding(28)
        }
        .background(Theme.heroGradient.opacity(0.2))
        .onAppear { settings.refreshLoginItemState() }
    }

    private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.mute)
            }
            Slider(value: value, in: range)
        }
    }
}
