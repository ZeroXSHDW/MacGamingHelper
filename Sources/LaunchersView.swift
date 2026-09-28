import SwiftUI

struct LaunchersPage: View {
    @EnvironmentObject private var launchers: LauncherShelf

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Launchers")
                    .font(.largeTitle.weight(.semibold))
                Text("Same job as Game Bay’s Play page: open the tools that already run games on this Mac.")
                    .foregroundStyle(Theme.mute)

                ForEach(launchers.items) { item in
                    launcherCard(item, primary: true)
                }

                Text("Also on this Mac")
                    .font(.title3.weight(.semibold))
                    .padding(.top, 8)

                ForEach(launchers.extras) { item in
                    launcherCard(item, primary: false)
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Cloud fallbacks")
                            .font(.headline)
                        Text("Modern Call of Duty’s Ricochet anti-cheat will not run locally through Steam, Heroic, Whisky, CrossOver, GPTK, or a VM. Use GeForce NOW or Xbox Cloud with the DualShock 4.")
                            .foregroundStyle(Theme.mute)
                        HStack {
                            PillButton(title: "Xbox Cloud Gaming", primary: true) { launchers.openXboxCloud() }
                            if let gfn = launchers.items.first(where: { $0.id == "geforce" }), gfn.isInstalled {
                                PillButton(title: "Open GeForce NOW") { launchers.open(gfn) }
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .onAppear { launchers.refresh() }
    }

    private func launcherCard(_ item: Launcher, primary: Bool) -> some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: item.symbol)
                    .font(.title2)
                    .foregroundStyle(item.isInstalled ? Theme.accent : Theme.mute)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.name).font(.headline)
                        Spacer()
                        Text(item.isInstalled ? "Installed" : "Not found")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(item.isInstalled ? Theme.good : Theme.warn)
                    }
                    Text(item.blurb)
                        .font(.callout)
                        .foregroundStyle(Theme.mute)
                        .fixedSize(horizontal: false, vertical: true)
                    if item.isInstalled {
                        HStack {
                            PillButton(title: "Open", primary: primary) { launchers.open(item) }
                            if item.id == "steam" {
                                PillButton(title: "Big Picture") { launchers.openSteamBigPicture() }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct HelpPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Help")
                    .font(.largeTitle.weight(.semibold))

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What this app is")
                            .font(.headline)
                        Text(Theme.relationNote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DualShock 4 features")
                            .font(.headline)
                        Text("• Connect / disconnect via Game Controller (GCController), with Rediscover for wireless scan")
                        Text("• Prefers DualShock 4 when several pads are present; DualSense also fully supported")
                        Text("• Live buttons, sticks, L2/R2 triggers, Share / Options / PS / touchpad")
                        Text("• Visual DualShock layout that lights up with presses")
                        Text("• Battery readout when the pad reports it")
                        Text("• Light-bar tint when GCDeviceLight is available; haptic pulse test")
                        Text("• Optional keyboard / mouse mapping profiles (FPS WASD, Arrows)")
                        Text("• Pairing / Setup coach: USB-first rescue, reset pinhole, Steam vs Mapping, permissions")
                        Text("• Launcher shortcuts for Steam, Heroic, GeForce NOW, and detected extras")
                        Text("• Offline self-test: MacGamingHelper --self-test")
                    }
                    .font(.callout)
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to run")
                            .font(.headline)
                        Text("Open ~/Applications/Mac Gaming Helper.app — or rebuild with scripts/install.sh.")
                        Text("Clone build: see README (scripts/install.sh).")
                        Text("Game Bay (unchanged): ~/Projects/game-bay and ~/Applications/Game Bay.app")
                    }
                    .font(.callout)
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permissions checklist")
                            .font(.headline)
                        Text("1. Bluetooth — System Settings → Bluetooth → pair Wireless Controller (DS4).")
                        Text("2. Accessibility — only if you turn Mapping on (Privacy & Security → Accessibility).")
                        Text("3. Input Monitoring — grant if macOS asks while reading HID; Game Controller usually needs neither for status alone.")
                        Text("If the pad flashes but never appears: use Pairing / Setup → USB-first steps.")
                        Text("No account sign-in is required for controller status or local mapping.")
                    }
                    .font(.callout)
                }
            }
            .padding(28)
        }
    }
}
