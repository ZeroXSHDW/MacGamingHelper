import Foundation
import GameController

enum SelfTest {
    @MainActor
    static func run() -> Int32 {
        var failed = false
        func check(_ name: String, _ ok: Bool, _ detail: String) {
            print("\(ok ? "OK" : "FAIL") \(name): \(detail)")
            if !ok { failed = true }
        }

        check("theme-version", Theme.version.hasPrefix("3.15"), Theme.version)
        check(
            "nav-pages",
            NavPage.allCases.map(\.rawValue) == ["play", "controller", "tester", "mapping", "launchers", "setup", "settings", "help"],
            NavPage.allCases.map(\.rawValue).joined(separator: ",")
        )
        check("nav-tester", NavPage.deskSection.contains(.tester), "tester in desk")

        check("curve-expo", StickCurve.expo.apply(0.5) < 0.5, "soft center")
        check("shaped-dz", StickMath.shaped(value: 0.05, deadzone: 0.1, curve: .linear) == 0, "inside dz")

        // Controller infrastructure (no physical pad required).
        ControllerMonitor.configureGameController()
        check("controller-background", GCController.shouldMonitorBackgroundEvents, "background input enabled")
        // GameController enumerates on the run loop; give a just-plugged USB
        // pad a moment so --self-test reports the truth.
        var livePads = GCController.controllers()
        if livePads.isEmpty {
            let deadline = Date().addingTimeInterval(1.0)
            while Date() < deadline && livePads.isEmpty {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                livePads = GCController.controllers()
            }
        }
        check("controller-scan", true, "\(livePads.count) connected")
        if let pad = livePads.first {
            check("controller-live", true,
                  "\(pad.vendorName ?? "?") · \(pad.productCategory) · \(pad.extendedGamepad is GCDualSenseGamepad ? "adaptive" : "standard")")
        }
        check("pad-kinds", PadKind.dualSense.isPlayStation && PadKind.dualShock4.isPlayStation && !PadKind.xbox.isPlayStation, "PlayStation detection")
        check("pad-face", PadKind.dualSense.face.a == "Cross" && PadKind.dualSense.face.y == "Triangle", "PlayStation labels")
        check("pad-empty-adaptive", !ControllerSnapshot.empty.adaptiveTriggersSupported, "off without a pad")

        let checkItems = PadCheckModel.items(for: .dualSense)
        check(
            "pad-check-items",
            checkItems.count >= 19 && checkItems.contains { $0.id == "touchpad" } && checkItems.contains { $0.id == "create" },
            "\(checkItems.count) controls"
        )
        var checkSnap = ControllerSnapshot.empty
        checkSnap.connected = true
        checkSnap.kind = .dualSense
        checkSnap.buttons = ["Cross", "L1", "Up"]
        checkSnap.lx = 1
        checkSnap.lt = 0.8
        checkSnap.touchpadPressed = true
        check(
            "pad-check-detect",
            PadCheckModel.matches("faceA", snap: checkSnap)
                && PadCheckModel.matches("leftStick", snap: checkSnap)
                && PadCheckModel.matches("l2", snap: checkSnap)
                && PadCheckModel.matches("dpadUp", snap: checkSnap)
                && PadCheckModel.matches("touchpad", snap: checkSnap),
            "sticks, face, trigger, d-pad, touchpad"
        )
        let checklist = PadCheckModel(kind: .dualSense)
        checklist.ingest(checkSnap)
        check(
            "pad-check-report",
            checklist.doneCount >= 5 && checklist.report(for: checkSnap).contains("Result: INCOMPLETE"),
            "\(checklist.doneCount)/\(checklist.total) recorded"
        )
        var fullSnap = ControllerSnapshot.empty
        fullSnap.id = "selftest-pad"
        fullSnap.connected = true
        fullSnap.kind = .dualSense
        fullSnap.buttons = [
            "Cross", "Circle", "Square", "Triangle",
            "L1", "R1", "L2", "R2",
            "Up", "Down", "Left", "Right",
            "L3", "R3", "Options", "Create", "Touchpad",
        ]
        fullSnap.lx = 1
        fullSnap.rx = 1
        fullSnap.lt = 1
        fullSnap.rt = 1
        fullSnap.touchpadPressed = true
        let fullModel = PadCheckModel(kind: .dualSense)
        fullModel.ingest(fullSnap)
        check(
            "pad-check-complete",
            fullModel.isComplete && fullModel.report(for: fullSnap).contains("Result: PASS"),
            "\(fullModel.doneCount)/\(fullModel.total)"
        )
        check(
            "bt-name",
            BluetoothPadStatus.isPlayStationName("DualSense Wireless Controller")
                && BluetoothPadStatus.isPlayStationName("Wireless Controller")
                && BluetoothPadStatus.isPlayStationName("DualShock 4")
                && !BluetoothPadStatus.isPlayStationName("Magic Keyboard"),
            "PlayStation Bluetooth names"
        )
        let probeMapper = InputMapper()
        check(
            "app-profiles-running",
            !probeMapper.runningApps.isEmpty && probeMapper.runningApps.allSatisfy { !$0.bundleID.isEmpty && !$0.name.isEmpty },
            "\(probeMapper.runningApps.count) running apps"
        )
        if let data = ProfileStore.exportData(.fpsWASD),
           let back = try? JSONDecoder().decode(MappingProfile.self, from: data) {
            check(
                "profile-export",
                back.id == "fps-wasd" && back.bindings.count == MappingProfile.fpsWASD.bindings.count,
                "profile JSON round-trip"
            )
        } else {
            check("profile-export", false, "profile JSON round-trip")
        }
        check(
            "heroic-deeplink",
            HeroicShelf.deepLinkURL(for: "Fortnite")?.absoluteString == "heroic://launch/Fortnite",
            "heroic deep link"
        )
        check(
            "power-parse",
            SystemPower.parsePowerMode("powermode 0").mode == .normal
                && SystemPower.parsePowerMode("powermode 1").mode == .lowPower
                && SystemPower.parsePowerMode("powermode 2").mode == .highPower
                && SystemPower.parsePowerMode("lowpowermode 1").mode == .lowPower,
            "power mode parsing"
        )
        let thermal = SystemPower.thermal()
        check(
            "thermal-label",
            ["NOM", "FAIR", "HOT", "CRIT", "—"].contains(thermal.label),
            thermal.label
        )
        let gp = GameProfile.make(bundleID: "com.example.game", name: "Example", mappingProfileID: "fps-wasd")
        if let gpData = try? JSONEncoder().encode(gp),
           let gpBack = try? JSONDecoder().decode(GameProfile.self, from: gpData) {
            check(
                "game-profile-codable",
                gpBack.bundleID == "com.example.game" && gpBack.overlayMode == .performance && gpBack.id == "com.example.game",
                "game profile JSON round-trip"
            )
        } else {
            check("game-profile-codable", false, "game profile JSON round-trip")
        }

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
        check("macro-default-off", profile.macros.first?.enabled == false, "off")
        profile.macros[0].enabled = true
        profile.macros[0].holdControl = "L1"
        profile.macros[0].tapControl = "Square"
        check("macro-on", profile.macros[0].enabled && profile.macros[0].holdControl == "L1", "L1+Square")
        profile.macros.append(MappingMacro(enabled: true, holdControl: "R1", tapControl: "Circle", keyCode: 14, keyName: "E"))
        check("macro-multi", profile.macros.count == 2, "\(profile.macros.count) slots")

        // Encode/decode without macro key
        let legacy = """
        {"id":"x","name":"X","deadzone":0.1,"bindings":[]}
        """.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(MappingProfile.self, from: legacy)
        check("macro-legacy-decode", decoded?.macros.first?.enabled == false, "legacy ok")

        // Legacy single 'macro' key still decodes into one slot
        let legacySingle = """
        {"id":"x","name":"X","deadzone":0.1,"bindings":[],"macro":{"enabled":true,"holdControl":"L1","tapControl":"Square","keyCode":14,"keyName":"E"}}
        """.data(using: .utf8)!
        let decodedSingle = try? JSONDecoder().decode(MappingProfile.self, from: legacySingle)
        check("macro-legacy-single", decodedSingle?.macros.count == 1 && decodedSingle?.macros[0].holdControl == "L1", "legacy single → array")

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

        // Launcher detection (3.4.2): real bundles only, official Heroic name.
        check("heroic-catalog-name",
              LauncherShelf.catalog.first { $0.id == "heroic" }?.applications.contains("Heroic-Games-Launcher.app") == true,
              "official vendor name covered")
        check("app-bundle-valid", AppFinder.isValidBundle(Bundle.main.bundleURL), "own bundle recognised")
        check("app-bundle-invalid", !AppFinder.isValidBundle(URL(fileURLWithPath: "/tmp/not-an-app.app")), "fake bundle rejected")
        let htmlApp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mgh-fake-\(UUID().uuidString).app")
        try? "<!DOCTYPE html><html>failed download</html>".write(to: htmlApp, atomically: true, encoding: .utf8)
        check("app-bundle-html-rejected", !AppFinder.isValidBundle(htmlApp), "HTML saved as .app rejected")
        try? FileManager.default.removeItem(at: htmlApp)
        check("heroic-manifests", HeroicShelf.manifestPaths().contains { $0.0.path.contains("store_cache/legendary_install_info.json") }, "\(HeroicShelf.manifestPaths().count) paths")

        let shelf = LauncherShelf()
        shelf.refresh()
        check("launchers-valid", shelf.items.allSatisfy { item in
            guard let url = item.appURL else { return true }
            return AppFinder.isValidBundle(url)
        }, "detected launchers are real bundles")
        if let steam = shelf.items.first(where: { $0.id == "steam" }) {
            check("steam-status", true,
                  steam.isInstalled ? "Steam detected" : (steam.isBroken ? "failed download" : "not installed (optional)"))
        }
        check("rosetta-status", true,
              SystemSupport.rosettaAvailable ? "available" : "missing — Steam needs Rosetta 2")

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


                // Session state machine (settings + keep-awake only — no NSPanel in --self-test)
        let s = AppSettings.shared
        let wasOverlay = s.showOverlay
        let wasSession = s.gamingSessionActive
        s.overlayMode = .performance
        s.gamingSessionActive = true
        s.showOverlay = true
        KeepAwake.shared.update(active: true)
        check("session-start-active", s.gamingSessionActive, "active")
        check("session-start-overlay", s.showOverlay, "overlay")
        check("session-start-mode", s.overlayMode == .performance, s.overlayMode.rawValue)
        check("session-awake-on", KeepAwake.shared.isAsserting, "asserting")
        // Idempotent flag set
        s.gamingSessionActive = true
        s.showOverlay = true
        check("session-idempotent", s.gamingSessionActive && s.showOverlay, "still on")
        s.gamingSessionActive = false
        s.showOverlay = false
        KeepAwake.shared.update(active: false)
        check("session-stop-active", !s.gamingSessionActive, "cleared")
        check("session-stop-overlay", !s.showOverlay, "overlay off")
        check("session-stop-awake", !KeepAwake.shared.isAsserting, "awake off")
        s.showOverlay = wasOverlay
        s.gamingSessionActive = wasSession

        let mapper = InputMapper()
        mapper.enabled = true
        mapper.pausedByUser = false
        mapper.pauseForSteamSession()
        check("map-pause-sticky", mapper.pausedByUser && mapper.enabled, "paused sticky")
        mapper.pauseForSteamSession()
        check("map-pause-idempotent", mapper.pausedByUser, "still paused")

        let g2 = PerfSampler.shared.sampleOnce()
        if let gp = g2.gpuPercent {
            check("gpu-finite-2", gp.isFinite && gp >= 0 && gp <= 100, String(format: "%.1f", gp))
        } else {
            check("gpu-nil-ok", true, g2.gpuNote)
        }

print(failed ? "self-test failed" : "self-test ok")
        return failed ? 1 : 0
    }
}
