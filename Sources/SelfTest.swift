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
        check("theme-version", Theme.version.hasPrefix("3."), Theme.version)
        check(
            "nav-pages",
            NavPage.allCases.map(\.rawValue) == ["controller", "mapping", "launchers", "setup", "settings", "help"],
            NavPage.allCases.map(\.rawValue).joined(separator: ",")
        )
        check("nav-sections", NavPage.deskSection.count == 3 && NavPage.setupSection.count == 3, "desk/setup")

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
        check("empty-motion", empty.motionAvailable == false, empty.motionNote)
        check("ds4-short", PadKind.dualShock4.shortLabel == "DS4", PadKind.dualShock4.shortLabel)
        check(
            "ps-kinds",
            PadKind.dualShock4.isPlayStation && PadKind.dualSense.isPlayStation && !PadKind.xbox.isPlayStation,
            "PS flags"
        )

        check("fps-profile", MappingProfile.fpsWASD.bindings.count >= 10, "\(MappingProfile.fpsWASD.bindings.count) bindings")
        check("arrows-profile", MappingProfile.arrowsBrowse.bindings.contains { $0.control == "Cross" }, "Cross→Return")
        let dup = MappingProfile.fpsWASD.duplicating(name: "Test Custom")
        check("dup-custom", dup.id.hasPrefix("custom-") && dup.name == "Test Custom", dup.id)
        do {
            try ProfileStore.save(dup)
            check("profile-save-load", ProfileStore.loadAll().contains(where: { $0.id == dup.id }), dup.id)
            try ProfileStore.delete(id: dup.id)
            check("profile-delete", !ProfileStore.loadAll().contains(where: { $0.id == dup.id }), "removed")
        } catch {
            check("profile-io", false, error.localizedDescription)
        }

        check("pairing-steps", PairingCoach.bluetoothSteps.count >= 5, "\(PairingCoach.bluetoothSteps.count) BT steps")
        check("usb-first", PairingCoach.usbFirstSteps.contains { $0.lowercased().contains("usb") }, "USB-first")
        check("art-list", PairingCoach.artNames.count >= 8, "\(PairingCoach.artNames.count)")
        var artHits = 0
        for name in PairingCoach.artNames {
            if BundleArt.nsImage(name) != nil { artHits += 1 }
        }
        check("art-bundle", artHits >= 6, "\(artHits)/\(PairingCoach.artNames.count)")

        check("version-compare-newer", UpdateChecker.isVersion("3.0.0", newerThan: "2.3.0"), "3>2.3")
        check("haptic-kinds", HapticPatternKind.allCases.count == 3, "\(HapticPatternKind.allCases.count)")

        let settings = AppSettings.shared
        check("settings-deadzone", settings.stickDeadzone > 0, "\(settings.stickDeadzone)")
        check("settings-last-tab", !settings.lastTab.isEmpty, settings.lastTab)
        check("settings-pause-inactive", settings.pauseMappingWhenInactive == true || settings.pauseMappingWhenInactive == false, "bool")

        // Diagnostics dump shape
        let mon = ControllerMonitor()
        let map = InputMapper()
        map.bind(monitor: mon, settings: settings)
        let dump = Diagnostics.dump(monitor: mon, mapper: map, settings: settings)
        check("diag-has-version", dump.contains("3.0.0") || dump.contains(Theme.version), "version in dump")
        check("diag-has-permissions", dump.contains("Accessibility"), "AX section")
        check("diag-has-controllers", dump.contains("Controllers"), "pads section")

        check("steam-locate", LauncherShelf.catalog[0].located().id == "steam", "steam")

        print(failed ? "self-test failed" : "self-test ok")
        return failed ? 1 : 0
    }
}
