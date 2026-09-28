import SwiftUI

struct PlayPage: View {
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var mapper: InputMapper
    @EnvironmentObject private var launchers: LauncherShelf
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var steam: SteamShelf
    @EnvironmentObject private var session: GameSession
    @EnvironmentObject private var heroic: HeroicShelf

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ready to play")
                            .font(.largeTitle.weight(.bold))
                            .tracking(-0.4)
                        Text("Session prep, Steam/Heroic libraries, keep-awake, Play HUD.")
                            .foregroundStyle(Theme.mute)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if settings.showPlayHUD { StatusChip(text: "HUD ON", color: Theme.good) }
                        if KeepAwake.shared.isAsserting { StatusChip(text: "AWAKE", color: Theme.accent) }
                    }
                }

                if session.steamInputHint {
                    Card {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warn)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Steam Input likely active").font(.headline)
                                Text("Frontmost: \(session.frontmostName). Pause Mapping so Steam owns the pad.")
                                    .font(.callout).foregroundStyle(Theme.mute)
                            }
                            Spacer()
                            if mapper.enabled && !mapper.pausedByUser {
                                PillButton(title: "Pause Mapping", primary: true) { mapper.togglePauseHotkey() }
                            }
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Session Prep").font(.headline)
                        ForEach(GameSession.prepItems(monitor: monitor, mapper: mapper, launchers: launchers)) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: item.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(item.ok ? Theme.good : Theme.bad)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.callout.weight(.semibold))
                                    Text(item.detail).font(.caption).foregroundStyle(Theme.mute)
                                }
                            }
                        }
                        Toggle("Gaming session active (keep display awake)", isOn: $settings.gamingSessionActive)
                        HStack {
                            PillButton(title: "Prep Steam session", primary: true) {
                                settings.gamingSessionActive = true
                                GameSession.prepSteamSession(mapper: mapper, launchers: launchers)
                            }
                            PillButton(title: settings.showPlayHUD ? "Hide Play HUD" : "Show Play HUD") {
                                settings.showPlayHUD.toggle()
                            }
                            PillButton(title: "Rediscover") { monitor.rediscover() }
                        }
                    }
                }

                // Compat tools
                let tools = CompatTools.detect()
                if tools.contains(where: \.installed) {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Also detected").font(.headline)
                            ForEach(tools.filter(\.installed)) { tool in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tool.name).font(.callout.weight(.semibold))
                                    Text(tool.tip).font(.caption).foregroundStyle(Theme.mute)
                                    if let path = tool.path {
                                        Text(path).font(.caption2.monospaced()).foregroundStyle(Theme.mute).lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }

                steamCard
                heroicCard
            }
            .padding(28)
        }
        .background(Theme.heroGradient.opacity(0.3))
        .onAppear {
            steam.refresh()
            heroic.refresh()
            session.start()
            launchers.refresh()
            settings.syncKeepAwake()
        }
    }

    private var steamCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Steam library").font(.headline)
                    Spacer()
                    PillButton(title: "Refresh") { steam.refresh() }
                    PillButton(title: "Big Picture", primary: true) { SteamShelf.openBigPicture() }
                }
                TextField("Filter games", text: $steam.filter)
                    .textFieldStyle(.roundedBorder)
                Text(steam.note).font(.caption).foregroundStyle(Theme.mute)
                if steam.displayed.isEmpty {
                    Text("No titles to show. Install in Steam, then Refresh.")
                        .foregroundStyle(Theme.mute)
                } else {
                    ForEach(steam.displayed.prefix(50)) { game in
                        HStack {
                            Button {
                                steam.toggleFavourite(game)
                            } label: {
                                Image(systemName: steam.favourites.contains(game.appID) ? "star.fill" : "star")
                                    .foregroundStyle(Theme.warn)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Favourite \(game.name)")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(game.name).font(.callout.weight(.semibold))
                                Text("App \(game.appID)").font(.caption2).foregroundStyle(Theme.mute)
                            }
                            Spacer()
                            PillButton(title: "Launch", primary: true) {
                                if mapper.enabled { mapper.stop() }
                                settings.gamingSessionActive = true
                                steam.launch(game)
                            }
                        }
                    }
                }
            }
        }
    }

    private var heroicCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Heroic / Epic / GOG").font(.headline)
                    Spacer()
                    PillButton(title: "Refresh") { heroic.refresh() }
                }
                Text(heroic.note).font(.caption).foregroundStyle(Theme.mute)
                ForEach(heroic.games.prefix(30)) { game in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(game.name).font(.callout.weight(.semibold))
                            Text("\(game.store) · \(game.detail)").font(.caption2).foregroundStyle(Theme.mute).lineLimit(1)
                        }
                        Spacer()
                        PillButton(title: "Open Heroic") {
                            heroic.launch(game, launchers: launchers)
                        }
                    }
                }
            }
        }
    }
}
