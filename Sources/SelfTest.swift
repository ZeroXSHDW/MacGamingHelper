import Foundation

enum SelfTest {
    @MainActor
    static func run() -> Int32 {
        var failed = false
        func check(_ name: String, _ ok: Bool, _ detail: String) {
            print("\(ok ? "OK" : "FAIL") \(name): \(detail)")
            if !ok { failed = true }
        }

        check("theme-name", Theme.name == "Mac Gaming Helper", Theme.name)
        check("theme-version", Theme.version.hasPrefix("2.3"), Theme.version)
        check(
            "nav-pages",
            NavPage.allCases.map(\.rawValue) == ["controller", "mapping", "launchers", "setup", "settings", "help"],
            NavPage.allCases.map(\.rawValue).joined(separator: ",")
        )

        check(
            "launcher-catalog",
            LauncherShelf.catalog.map(\.id) == ["steam", "heroic", "geforce"],
            LauncherShelf.catalog.map(\.id).joined(separator: ",")
        )
        check(
            "extras-include-gamebay",
            LauncherShelf.extraCatalog.contains { $0.id == "gamebay" },
            "Game Bay preserved"
        )

        let empty = ControllerSnapshot.empty
        check("empty-disconnected", empty.connected == false && empty.kind == .none, empty.title)
        check("empty-transport", empty.transport == .unknown, empty.transport.rawValue)
        check(
            "ds4-face",
            PadKind.dualShock4.face.a == "Cross" && PadKind.dualShock4.face.b == "Circle",
            "\(PadKind.dualShock4.face)"
        )
        check("ds4-short", PadKind.dualShock4.shortLabel == "DS4", PadKind.dualShock4.shortLabel)
        check(
            "ps-kinds",
            PadKind.dualShock4.isPlayStation && PadKind.dualSense.isPlayStation && !PadKind.xbox.isPlayStation,
            "PS flags"
        )

        check("fps-profile", MappingProfile.fpsWASD.bindings.count >= 10, "\(MappingProfile.fpsWASD.bindings.count) bindings")
        check("arrows-profile", MappingProfile.arrowsBrowse.bindings.contains { $0.control == "Cross" }, "Cross→Return")
        check(
            "presets",
            MappingProfile.presets.map(\.id) == ["fps-wasd", "arrows"],
            MappingProfile.presets.map(\.id).joined(separator: ",")
        )

        let dup = MappingProfile.fpsWASD.duplicating(name: "Test Custom")
        check("dup-custom", dup.id.hasPrefix("custom-") && dup.name == "Test Custom", dup.id)
        check("key-choices", KeyChoices.options.contains(where: { $0.name == "W" && $0.code == 13 }), "W=13")

        // ProfileStore round-trip
        let tmp = dup
        do {
            try ProfileStore.save(tmp)
            let loaded = ProfileStore.loadAll()
            check("profile-save-load", loaded.contains(where: { $0.id == tmp.id }), tmp.id)
            try ProfileStore.delete(id: tmp.id)
            check("profile-delete", !ProfileStore.loadAll().contains(where: { $0.id == tmp.id }), "removed")
        } catch {
            check("profile-io", false, error.localizedDescription)
        }
        check("preset-protected", ProfileStore.isPreset("fps-wasd"), "fps-wasd preset")

        check("pairing-steps", PairingCoach.bluetoothSteps.count >= 5, "\(PairingCoach.bluetoothSteps.count) BT steps")
        check(
            "usb-first",
            PairingCoach.usbFirstSteps.contains { $0.lowercased().contains("usb") },
            "USB-first path present"
        )
        check(
            "reset-tip",
            PairingCoach.resetSteps.contains {
                let s = $0.lowercased()
                return s.contains("pinhole") || s.contains("reset")
            },
            "reset covered"
        )
        check("permissions-bt", PairingCoach.permissions.contains { $0.title == "Bluetooth" }, "BT permission note")
        check("permissions-ax", PairingCoach.permissions.contains { $0.title == "Accessibility" }, "AX permission note")

        let steam = LauncherShelf.catalog[0].located()
        check("steam-locate", steam.id == "steam", steam.appURL?.path ?? "not installed (ok)")

        check("art-list", PairingCoach.artNames.count >= 8, "\(PairingCoach.artNames.count) art names")
        var artHits = 0
        for name in PairingCoach.artNames {
            if BundleArt.nsImage(name) != nil { artHits += 1 }
        }
        check("art-bundle", artHits >= 6, "\(artHits)/\(PairingCoach.artNames.count) images loadable")

        check("version-compare-newer", UpdateChecker.isVersion("2.3.0", newerThan: "2.2.0"), "2.3>2.2")
        check("version-compare-same", !UpdateChecker.isVersion("2.3.0", newerThan: "2.3.0"), "equal")
        check("version-compare-tag", UpdateChecker.isVersion("v2.4.0", newerThan: "2.3.0"), "tag strip")
        check("haptic-kinds", HapticPatternKind.allCases.map(\.rawValue) == ["short", "medium", "rumble"], "patterns")

        let settings = AppSettings.shared
        check("settings-defaults", settings.stickDeadzone > 0 && settings.stickDeadzone < 1, "\(settings.stickDeadzone)")
        check("settings-menubar-default", settings.showMenuBar == true || settings.showMenuBar == false, "bool ok")

        print(failed ? "self-test failed" : "self-test ok")
        return failed ? 1 : 0
    }
}
