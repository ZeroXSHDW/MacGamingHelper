import SwiftUI

/// Gaming-first session prep + Steam quick-launch.
struct PlayPage: View {
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var mapper: InputMapper
    @EnvironmentObject private var launchers: LauncherShelf
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var steam: SteamShelf
    @EnvironmentObject private var session: GameSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ready to play")
                            .font(.largeTitle.weight(.bold))
                            .tracking(-0.4)
                        Text("Session prep for DualShock 4 on Mac — Steam Input vs Mapping, battery, quick launch.")
                            .foregroundStyle(Theme.mute)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if settings.showPlayHUD {
                        StatusChip(text: "HUD ON", color: Theme.good)
                    }
                }

                if session.steamInputHint {
                    Card {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.warn)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Steam Input likely active")
                                    .font(.headline)
                                Text("Frontmost: \(session.frontmostName). Mapping paused is recommended so Steam owns the pad.")
                                    .font(.callout)
                                    .foregroundStyle(Theme.mute)
                            }
                            Spacer()
                            if mapper.enabled && !mapper.pausedByUser {
                                PillButton(title: "Pause Mapping", primary: true) {
                                    mapper.togglePauseHotkey()
                                }
                            }
                        }
                    }
                    .accessibilityLabel("Steam Input likely active warning")
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Session Prep checklist")
                            .font(.headline)
                        ForEach(GameSession.prepItems(monitor: monitor, mapper: mapper, launchers: launchers)) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: item.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(item.ok ? Theme.good : Theme.bad)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.callout.weight(.semibold))
                                    Text(item.detail).font(.caption).foregroundStyle(Theme.mute)
                                }
                            }
                            .accessibilityLabel("\(item.title): \(item.ok ? "OK" : "Needs attention"). \(item.detail)")
                        }
                        HStack {
                            PillButton(title: "Prep Steam session", primary: true) {
                                GameSession.prepSteamSession(mapper: mapper, launchers: launchers)
                            }
                            .accessibilityLabel("Turn mapping off and open Steam Big Picture")
                            PillButton(title: settings.showPlayHUD ? "Hide Play HUD" : "Show Play HUD") {
                                settings.showPlayHUD.toggle()
                            }
                            PillButton(title: "Rediscover") { monitor.rediscover() }
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Steam library")
                                .font(.headline)
                            Spacer()
                            PillButton(title: "Refresh") { steam.refresh() }
                            PillButton(title: "Big Picture", primary: true) { SteamShelf.openBigPicture() }
                        }
                        Text(steam.note)
                            .font(.caption)
                            .foregroundStyle(Theme.mute)
                        if steam.games.isEmpty {
                            Text("Install games in Steam, then Refresh. Or open Steam to browse.")
                                .foregroundStyle(Theme.mute)
                            if launchers.items.first(where: { $0.id == "steam" })?.isInstalled == true {
                                PillButton(title: "Open Steam") {
                                    if let s = launchers.items.first(where: { $0.id == "steam" }) {
                                        launchers.open(s)
                                    }
                                }
                            }
                        } else {
                            ForEach(steam.games.prefix(40)) { game in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(game.name).font(.callout.weight(.semibold))
                                        Text("App \(game.appID)").font(.caption2).foregroundStyle(Theme.mute)
                                    }
                                    Spacer()
                                    PillButton(title: "Launch", primary: true) {
                                        if mapper.enabled { mapper.stop() }
                                        steam.launch(game)
                                    }
                                    .accessibilityLabel("Launch \(game.name)")
                                }
                                .padding(.vertical, 2)
                            }
                            if steam.games.count > 40 {
                                Text("Showing 40 of \(steam.games.count). Use Steam for the full library.")
                                    .font(.caption)
                                    .foregroundStyle(Theme.mute)
                            }
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quick tips")
                            .font(.headline)
                        Text("• Steam / Big Picture: Mapping OFF — Steam Input owns DualShock 4.")
                        Text("• Non-gamepad Mac titles: Mapping ON with FPS profile + aim curve.")
                        Text("• ⌥⌘M pause mapping · ⌘⌥1/2/3 switch profiles · Play HUD stays on top while gaming.")
                    }
                    .font(.callout)
                }
            }
            .padding(28)
        }
        .background(Theme.heroGradient.opacity(0.3))
        .onAppear {
            steam.refresh()
            session.start()
            launchers.refresh()
        }
    }
}
