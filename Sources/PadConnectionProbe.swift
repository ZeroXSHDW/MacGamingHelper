import Foundation
import IOKit.hid

/// GameController does not expose whether a pad is wired or wireless on
/// macOS (`isAttachedToDevice` means attached to an iPhone/iPad, not USB).
/// Ask IOKit for the Sony HID device's transport instead, with a short cache
/// so the 30 Hz controller poll does not enumerate HID devices every frame.
enum PadConnectionProbe {
    private static var cached: (transport: PadTransport, at: Date)?

    static func currentSonyTransport() -> PadTransport? {
        if let cached, Date().timeIntervalSince(cached.at) < 2.0 {
            return cached.transport
        }
        let transport = querySonyTransport()
        cached = transport.map { ($0, Date()) }
        return transport
    }

    private static func querySonyTransport() -> PadTransport? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDDeviceUsagePageKey: 0x01,
            kIOHIDDeviceUsageKey: 0x05,
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return nil
        }

        var sawUSB = false
        var sawBluetooth = false
        for device in devices {
            let vendor = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? -1
            let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
            let isSony = vendor == 0x054C
                || name.localizedCaseInsensitiveContains("DualSense")
                || name.localizedCaseInsensitiveContains("DualShock")
                || name.localizedCaseInsensitiveContains("Wireless Controller")
            guard isSony else { continue }

            switch IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? "" {
            case "USB":
                sawUSB = true
            case "Bluetooth", "BluetoothLowEnergy":
                sawBluetooth = true
            default:
                break
            }
        }

        if sawUSB { return .usb }
        if sawBluetooth { return .bluetooth }
        return nil
    }
}
