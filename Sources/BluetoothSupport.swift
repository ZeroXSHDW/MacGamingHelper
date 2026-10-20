import Foundation
import IOBluetooth

/// macOS Bluetooth facts for the controller page. GameController knows a pad
/// is connected, but not whether macOS has it paired for wireless use.
struct BluetoothPadStatus: Equatable {
    var powerOn: Bool
    var pairedNames: [String]
    var connectedNames: [String]
    var checkedAt: Date

    var playStationPairedName: String? {
        pairedNames.first(where: Self.isPlayStationName)
    }

    var playStationConnectedName: String? {
        connectedNames.first(where: Self.isPlayStationName)
    }

    var hasPlayStationPair: Bool { playStationPairedName != nil }
    var hasPlayStationConnection: Bool { playStationConnectedName != nil }

    static func isPlayStationName(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("dualsense")
            || n.contains("dualshock")
            || n.contains("wireless controller")
            || n.contains("playstation")
    }
}

enum BluetoothSupport {
    /// Uses the public IOBluetooth host/device API. Paired devices are read
    /// only; nothing is connected or modified.
    static func snapshot() -> BluetoothPadStatus {
        guard let host = IOBluetoothHostController.default() else {
            return BluetoothPadStatus(
                powerOn: false,
                pairedNames: [],
                connectedNames: [],
                checkedAt: Date()
            )
        }
        let powerOn = host.powerState.rawValue == 1
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        let pairedNames = paired.compactMap { $0.name }
        let connectedNames = paired.filter { $0.isConnected() }.compactMap { $0.name }
        return BluetoothPadStatus(
            powerOn: powerOn,
            pairedNames: pairedNames,
            connectedNames: connectedNames,
            checkedAt: Date()
        )
    }
}

@MainActor
final class BluetoothReadinessModel: ObservableObject {
    @Published private(set) var status: BluetoothPadStatus?
    @Published private(set) var checking = false

    func refresh() {
        guard !checking else { return }
        checking = true
        status = BluetoothSupport.snapshot()
        checking = false
    }
}
