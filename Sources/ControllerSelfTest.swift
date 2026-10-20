import Foundation
import GameController

/// `MacGamingHelper --controller-test` prints what the real app sees:
/// kind, transport, battery, player slot, light/haptics/adaptive support.
/// It waits up to four seconds for a just-plugged USB pad to enumerate.
enum ControllerSelfTest {
    @MainActor
    static func run() -> Int32 {
        ControllerMonitor.configureGameController()
        let monitor = ControllerMonitor()
        monitor.start()

        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline && monitor.snapshots.isEmpty {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        let snaps = monitor.snapshots
        print("controller-test: \(snaps.count) connected")
        let bt = BluetoothSupport.snapshot()
        print("bluetooth: power=\(bt.powerOn ? "on" : "off") paired=\(bt.pairedNames.isEmpty ? "none" : bt.pairedNames.joined(separator: ", ")) connected=\(bt.connectedNames.isEmpty ? "none" : bt.connectedNames.joined(separator: ", "))")
        for snap in snaps {
            print("  \(snap.title)")
            print("  kind=\(snap.kind.rawValue) transport=\(snap.transportLabel) battery=\(snap.battery) player=\(snap.playerIndex)")
            print("  light=\(snap.lightBarSupported) haptics=\(snap.hapticsSupported) adaptive=\(snap.adaptiveTriggersSupported) motion=\(snap.motionAvailable)")
            print("  buttons=\(snap.buttons.isEmpty ? "none" : snap.buttons.joined(separator: ","))")
            print("  sticks L=(\(String(format: "%.2f", snap.lx)),\(String(format: "%.2f", snap.ly))) R=(\(String(format: "%.2f", snap.rx)),\(String(format: "%.2f", snap.ry))) triggers L2=\(String(format: "%.2f", snap.lt)) R2=\(String(format: "%.2f", snap.rt))")
        }

        if CommandLine.arguments.contains("--watch") {
            print("watch: press Cross, Circle, L2 and move the left stick (up to 5 minutes)…")
            var lastButtons = Set<String>()
            var sawCross = false
            var sawCircle = false
            var sawL2 = false
            var sawLeft = false
            let end = Date().addingTimeInterval(300)
            while Date() < end {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                guard let snap = monitor.snapshots.first else { continue }
                let now = Set(snap.buttons)
                let pressed = now.subtracting(lastButtons)
                if !pressed.isEmpty {
                    print("press: \(pressed.sorted().joined(separator: ", "))")
                }
                if now.contains("Cross") { sawCross = true }
                if now.contains("Circle") { sawCircle = true }
                if snap.lt > 0.5 || now.contains("L2") { sawL2 = true }
                if abs(snap.lx) > 0.5 || abs(snap.ly) > 0.5 { sawLeft = true }
                lastButtons = now
                if sawCross && sawCircle && sawL2 && sawLeft {
                    print("watch: verified Cross, Circle, L2, left stick")
                    return 0
                }
            }
            print("watch: incomplete — Cross=\(sawCross) Circle=\(sawCircle) L2=\(sawL2) leftStick=\(sawLeft)")
        }
        return snaps.isEmpty ? 1 : 0
    }
}
