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
                        Toggle("Play HUD (always-on-top while gaming)", isOn: $settings.showPlayHUD)
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
                        Text("⌘1–⌘7 tabs · ⌘R Rediscover · ⌥⌘M Pause Mapping · ⌘⌥1–3 profiles")
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
