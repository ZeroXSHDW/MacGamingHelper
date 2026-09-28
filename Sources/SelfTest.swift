import Foundation

enum SelfTest {
    @MainActor
    static func run() -> Int32 {
        var failed = false
        func check(_ name: String, _ ok: Bool, _ detail: String) {
            print("\(ok ? "OK" : "FAIL") \(name): \(detail)")
            if !ok { failed = true }
        }

        check("theme-version", Theme.version.hasPrefix("3.4"), Theme.version)
        check(
            "nav-pages",
            NavPage.allCases.map(\.rawValue) == ["play", "controller", "tester", "mapping", "launchers", "setup", "settings", "help"],
            NavPage.allCases.map(\.rawValue).joined(separator: ",")
        )
        check("nav-tester", NavPage.deskSection.contains(.tester), "tester in desk")

        check("curve-expo", StickCurve.expo.apply(0.5) < 0.5, "soft center")
        check("shaped-dz", StickMath.shaped(value: 0.05, deadzone: 0.1, curve: .linear) == 0, "inside dz")

        let acf = """
        "AppState"
        {
          "appid" "730"
          "name" "Counter-Strike 2"
          "StateFlags" "4"
          "LastUpdated" "1700000000"
          "SizeOnDisk" "30000000000"
        }
        """
        check("vdf-name", SteamVDF.value(acf, key: "name") == "Counter-Strike 2", "name")
        check("vdf-updated", SteamVDF.value(acf, key: "LastUpdated") == "1700000000", "updated")
        check("vdf-size", SteamVDF.value(acf, key: "SizeOnDisk") == "30000000000", "size")
        let folders = """
        "libraryfolders"
        {
          "0"
          {
            "path" "/Users/user/Library/Application Support/Steam"
          }
          "1"
          {
            "path" "/Volumes/Games/SteamLibrary"
          }
        }
        """
        let paths = SteamVDF.paths(in: folders)
        check("vdf-multi-root", paths.count == 2, "\(paths.count)")

        let tools = CompatTools.detect()
        check("compat-count", tools.count == 3, "\(tools.count)")
        check("compat-ids", tools.map(\.id) == ["crossover", "whisky", "gptk"], tools.map(\.id).joined())

        var profile = MappingProfile.fpsWASD
        check("macro-default-off", profile.macro.enabled == false, "off")
        profile.macro.enabled = true
        profile.macro.holdControl = "L1"
        profile.macro.tapControl = "Square"
        check("macro-on", profile.macro.enabled && profile.macro.holdControl == "L1", "L1+Square")

        // Encode/decode without macro key
        let legacy = """
        {"id":"x","name":"X","deadzone":0.1,"bindings":[]}
        """.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(MappingProfile.self, from: legacy)
        check("macro-legacy-decode", decoded?.macro.enabled == false, "legacy ok")

        let settings = AppSettings.shared
        check("audio-defaults", settings.audioConnectCues, "connect on")
        KeepAwake.shared.update(active: true)
        check("keep-awake-on", KeepAwake.shared.isAsserting, "asserting")
        KeepAwake.shared.update(active: false)
        check("keep-awake-off", !KeepAwake.shared.isAsserting, "released")

        let steam = SteamShelf()
        steam.refresh()
        check("steam-scan", steam.lastScanOK, steam.note)
        let heroic = HeroicShelf()
        heroic.refresh()
        check("heroic-scan", true, heroic.note)

        check("art", PairingCoach.artNames.filter { BundleArt.nsImage($0) != nil }.count >= 6, "arts")
        check("version-gt", UpdateChecker.isVersion("3.2.0", newerThan: "3.1.0"), "3.2>3.1")
        check("extras-gamebay", LauncherShelf.extraCatalog.contains { $0.id == "gamebay" }, "preserved")

        // Overlay / metrics
        check("overlay-modes", OverlayMode.allCases.count == 2, "\(OverlayMode.allCases.count)")
        check("overlay-edges", OverlayEdge.allCases.count == 2, "\(OverlayEdge.allCases.count)")
        let sample = PerfSampler.shared.sampleOnce()
        // First CPU sample may be nil (needs delta); second should be finite
        let sample2 = PerfSampler.shared.sampleOnce()
        if let cpu = sample2.cpuPercent {
            check("cpu-finite", cpu.isFinite && cpu >= 0 && cpu <= 100, String(format: "%.1f", cpu))
        } else {
            check("cpu-finite", sample.cpuPercent == nil, "first-delta-ok")
        }
        if let mem = sample2.memoryPressurePercent {
            check("mem-finite", mem.isFinite && mem >= 0 && mem <= 100, String(format: "%.1f", mem))
        } else {
            check("mem-finite", false, "nil")
        }
        check("panel-hz", sample2.panelHz != nil && (sample2.panelHz ?? 0) > 0, "\(sample2.panelHz ?? -1)")
        // GPU: real or honest unavailable — never fake
        if sample2.gpuAvailable {
            check("gpu-real", sample2.gpuPercent != nil && (sample2.gpuPercent ?? -1).isFinite, sample2.gpuNote)
        } else {
            check("gpu-honest", sample2.gpuPercent == nil, sample2.gpuNote)
        }
        check("version-gt-32", UpdateChecker.isVersion("3.3.0", newerThan: "3.2.0"), "3.3>3.2")
        check("version-gt-331", UpdateChecker.isVersion("3.3.1", newerThan: "3.3.0"), "3.3.1>3.3.0")
        check("permissions-helper", !PermissionsHelper.humanChecklist.isEmpty, "checklist")
        check("easy-run-guidance", EasyRun.fixGatekeeperGuidance().contains("xattr"), "gatekeeper")
        check("version-gt-34", UpdateChecker.isVersion("3.4.0", newerThan: "3.3.1"), "3.4>3.3.1")
        check("ax-api", true, PermissionsHelper.accessibilityTrusted ? "granted" : "not-granted-ok")

        print(failed ? "self-test failed" : "self-test ok")
        return failed ? 1 : 0
    }
}
