import Foundation

enum SelfTest {
    @MainActor
    static func run() -> Int32 {
        var failed = false
        func check(_ name: String, _ ok: Bool, _ detail: String) {
            print("\(ok ? "OK" : "FAIL") \(name): \(detail)")
            if !ok { failed = true }
        }

        check("theme-version", Theme.version.hasPrefix("3.1"), Theme.version)
        check(
            "nav-pages",
            NavPage.allCases.map(\.rawValue) == ["play", "controller", "mapping", "launchers", "setup", "settings", "help"],
            NavPage.allCases.map(\.rawValue).joined(separator: ",")
        )
        check("nav-desk", NavPage.deskSection.first == .play, "play first")

        check("curve-linear", StickCurve.linear.apply(0.5) == 0.5, "\(StickCurve.linear.apply(0.5))")
        check("curve-ease", StickCurve.easeOut.apply(0) == 0 && StickCurve.easeOut.apply(1) == 1, "ease ends")
        check("curve-expo", StickCurve.expo.apply(0.5) < 0.5, "expo soft center")
        let shaped = StickMath.shaped(value: 0.5, deadzone: 0.1, curve: .linear)
        check("shaped-dz", shaped > 0 && shaped < 1, "\(shaped)")
        check("shaped-inside-dz", StickMath.shaped(value: 0.05, deadzone: 0.1, curve: .linear) == 0, "zero")

        // Steam VDF fixtures
        let acf = """
        "AppState"
        {
          "appid" "730"
          "name" "Counter-Strike 2"
          "StateFlags" "4"
        }
        """
        check("vdf-name", SteamVDF.value(acf, key: "name") == "Counter-Strike 2", SteamVDF.value(acf, key: "name") ?? "nil")
        check("vdf-flags-installed", (Int(SteamVDF.value(acf, key: "StateFlags") ?? "") ?? 0) & 4 != 0, "flag 4")
        let absent = acf.replacingOccurrences(of: "\"4\"", with: "\"2\"")
        check("vdf-flags-absent", (Int(SteamVDF.value(absent, key: "StateFlags") ?? "") ?? 0) & 4 == 0, "flag 2")
        let folders = """
        "libraryfolders"
        {
          "0"
          {
            "path" "/Users/user/Library/Application Support/Steam"
          }
        }
        """
        check("vdf-path", SteamVDF.paths(in: folders).contains { $0.contains("Steam") }, SteamVDF.paths(in: folders).joined(separator: "|"))

        let settings = AppSettings.shared
        check("aim-sens", settings.aimSensitivity > 0, "\(settings.aimSensitivity)")
        check("hair-default", settings.hairTriggerThreshold > 0, "\(settings.hairTriggerThreshold)")

        let mon = ControllerMonitor()
        let map = InputMapper()
        map.bind(monitor: mon, settings: settings)
        let shelf = LauncherShelf()
        shelf.refresh()
        let items = GameSession.prepItems(monitor: mon, mapper: map, launchers: shelf)
        check("prep-count", items.count >= 4, "\(items.count)")
        check("prep-pad-fail", items.contains { $0.id == "pad" && $0.ok == false }, "no pad expected")

        check("extras-gamebay", LauncherShelf.extraCatalog.contains { $0.id == "gamebay" }, "preserved")
        check("art-bundle", PairingCoach.artNames.filter { BundleArt.nsImage($0) != nil }.count >= 6, "arts")
        check("version-gt-3", UpdateChecker.isVersion("3.1.0", newerThan: "3.0.0"), "3.1>3.0")

        // Live steam scan (best-effort)
        let steam = SteamShelf()
        steam.refresh()
        check("steam-scan", steam.lastScanOK, steam.note)

        print(failed ? "self-test failed" : "self-test ok")
        return failed ? 1 : 0
    }
}
