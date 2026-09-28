import Foundation

/// Lightweight offline checks (no Bluetooth / Accessibility required).
/// Run: built binary with `--self-test`, or `scripts/self-test.sh`.
enum SelfTest {
    @MainActor
    static func run() -> Int32 {
        var failed = false
        func check(_ name: String, _ ok: Bool, _ detail: String) {
            print("\(ok ? "OK" : "FAIL") \(name): \(detail)")
            if !ok { failed = true }
        }

        check("theme-name", Theme.name == "Mac Gaming Helper", Theme.name)
        check("theme-version", Theme.version.hasPrefix("2."), Theme.version)
        check(
            "nav-pages",
            NavPage.allCases.map(\.rawValue) == ["controller", "mapping", "launchers", "setup", "help"],
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
        check(
            "ds4-face",
            PadKind.dualShock4.face.a == "Cross" && PadKind.dualShock4.face.b == "Circle",
            "\(PadKind.dualShock4.face)"
        )
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

        print(failed ? "self-test failed" : "self-test ok")
        return failed ? 1 : 0
    }
}
