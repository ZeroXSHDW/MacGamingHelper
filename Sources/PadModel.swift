import Foundation

enum PadKind: String, Equatable {
    case dualShock4 = "DualShock 4"
    case dualSense = "DualSense"
    case xbox = "Xbox"
    case generic = "Gamepad"
    case none = "None"

    var isPlayStation: Bool {
        self == .dualShock4 || self == .dualSense
    }

    var shortLabel: String {
        switch self {
        case .dualShock4: return "DS4"
        case .dualSense: return "DS5"
        case .xbox: return "Xbox"
        case .generic: return "Pad"
        case .none: return "—"
        }
    }

    var face: (a: String, b: String, x: String, y: String) {
        switch self {
        case .dualShock4, .dualSense:
            return ("Cross", "Circle", "Square", "Triangle")
        default:
            return ("A", "B", "X", "Y")
        }
    }
}

enum PadTransport: String, Equatable {
    case usb = "USB"
    case bluetooth = "Bluetooth"
    case unknown = "Unknown"
}

struct ControllerSnapshot: Identifiable, Equatable {
    var id: String
    var title: String
    var vendor: String
    var category: String
    var kind: PadKind
    var battery: String
    var batteryPercent: Int?
    var batteryCharging: Bool
    var connected: Bool
    var buttons: [String]
    var lx: Double
    var ly: Double
    var rx: Double
    var ry: Double
    var lt: Double
    var rt: Double
    var touchpadPressed: Bool
    var touchpadX: Double
    var touchpadY: Double
    var homePressed: Bool
    var lightBarSupported: Bool
    var hapticsSupported: Bool
    var playerIndex: Int
    var transport: PadTransport
    var preferenceKey: String
    var motionAvailable: Bool
    var motionNote: String
    var gravityX: Double
    var gravityY: Double
    var gravityZ: Double
    var pitch: Double
    var yaw: Double
    var roll: Double

    var transportLabel: String { transport.rawValue }

    static let empty = ControllerSnapshot(
        id: "none",
        title: "No controller",
        vendor: "",
        category: "",
        kind: .none,
        battery: "",
        batteryPercent: nil,
        batteryCharging: false,
        connected: false,
        buttons: [],
        lx: 0, ly: 0, rx: 0, ry: 0, lt: 0, rt: 0,
        touchpadPressed: false,
        touchpadX: 0, touchpadY: 0,
        homePressed: false,
        lightBarSupported: false,
        hapticsSupported: false,
        playerIndex: -1,
        transport: .unknown,
        preferenceKey: "",
        motionAvailable: false,
        motionNote: "No controller",
        gravityX: 0, gravityY: 0, gravityZ: 0,
        pitch: 0, yaw: 0, roll: 0
    )
}

enum MappingTarget: String, Codable, CaseIterable, Identifiable {
    case key
    case mouseMove
    case mouseButton
    case scroll
    case none

    var id: String { rawValue }
}

struct MappingBinding: Codable, Equatable, Identifiable {
    var id: String
    var control: String
    var target: MappingTarget
    var keyCode: UInt16?
    var keyName: String?
    var mouseButton: Int?
    var mouseAxis: String?
    var scale: Double

    static func key(_ control: String, code: UInt16, name: String) -> MappingBinding {
        MappingBinding(
            id: control, control: control, target: .key,
            keyCode: code, keyName: name,
            mouseButton: nil, mouseAxis: nil, scale: 1
        )
    }

    static func mouseStick(_ control: String, scale: Double = 12) -> MappingBinding {
        MappingBinding(
            id: control, control: control, target: .mouseMove,
            keyCode: nil, keyName: nil,
            mouseButton: nil, mouseAxis: "xy", scale: scale
        )
    }

    static func mouseBtn(_ control: String, button: Int, name: String) -> MappingBinding {
        MappingBinding(
            id: control, control: control, target: .mouseButton,
            keyCode: nil, keyName: name,
            mouseButton: button, mouseAxis: nil, scale: 1
        )
    }
}

struct MappingMacro: Codable, Equatable {
    var enabled: Bool
    var holdControl: String
    var tapControl: String
    var keyCode: UInt16
    var keyName: String

    static let off = MappingMacro(enabled: false, holdControl: "L1", tapControl: "Square", keyCode: 14, keyName: "E")
}

struct MappingProfile: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var deadzone: Double
    var bindings: [MappingBinding]
    var macro: MappingMacro

    enum CodingKeys: String, CodingKey { case id, name, deadzone, bindings, macro }

    init(id: String, name: String, deadzone: Double, bindings: [MappingBinding], macro: MappingMacro = .off) {
        self.id = id; self.name = name; self.deadzone = deadzone; self.bindings = bindings; self.macro = macro
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        deadzone = try c.decode(Double.self, forKey: .deadzone)
        bindings = try c.decode([MappingBinding].self, forKey: .bindings)
        macro = try c.decodeIfPresent(MappingMacro.self, forKey: .macro) ?? .off
    }

    static let fpsWASD = MappingProfile(
        id: "fps-wasd",
        name: "FPS · WASD + mouse",
        deadzone: 0.12,
        bindings: [
            .key("LeftStickUp", code: 13, name: "W"),
            .key("LeftStickDown", code: 1, name: "S"),
            .key("LeftStickLeft", code: 0, name: "A"),
            .key("LeftStickRight", code: 2, name: "D"),
            .mouseStick("RightStick", scale: 14),
            .key("Cross", code: 49, name: "Space"),
            .key("Circle", code: 14, name: "E"),
            .key("Square", code: 12, name: "Q"),
            .key("Triangle", code: 15, name: "R"),
            .mouseBtn("R2", button: 0, name: "Left Click"),
            .mouseBtn("L2", button: 1, name: "Right Click"),
            .key("L1", code: 12, name: "Q"),
            .key("R1", code: 15, name: "R"),
            .key("Options", code: 53, name: "Esc"),
            .key("Share", code: 48, name: "Tab"),
            .key("Up", code: 126, name: "↑"),
            .key("Down", code: 125, name: "↓"),
            .key("Left", code: 123, name: "←"),
            .key("Right", code: 124, name: "→"),
        ],
        macro: .off
    )

    static let arrowsBrowse = MappingProfile(
        id: "arrows",
        name: "Arrows + Enter",
        deadzone: 0.18,
        bindings: [
            .key("Up", code: 126, name: "↑"),
            .key("Down", code: 125, name: "↓"),
            .key("Left", code: 123, name: "←"),
            .key("Right", code: 124, name: "→"),
            .key("LeftStickUp", code: 126, name: "↑"),
            .key("LeftStickDown", code: 125, name: "↓"),
            .key("LeftStickLeft", code: 123, name: "←"),
            .key("LeftStickRight", code: 124, name: "→"),
            .key("Cross", code: 36, name: "Return"),
            .key("Circle", code: 53, name: "Esc"),
            .key("Options", code: 53, name: "Esc"),
            .key("Share", code: 48, name: "Tab"),
        ],
        macro: .off
    )

    static let presets: [MappingProfile] = [.fpsWASD, .arrowsBrowse]

    func duplicating(name: String) -> MappingProfile {
        MappingProfile(
            id: "custom-\(UUID().uuidString.prefix(8))",
            name: name,
            deadzone: deadzone,
            bindings: bindings,
            macro: macro
        )
    }
}

/// Common key choices for the custom profile editor.
enum KeyChoices {
    static let options: [(name: String, code: UInt16)] = [
        ("A", 0), ("S", 1), ("D", 2), ("F", 3), ("H", 4), ("G", 5), ("Z", 6), ("X", 7),
        ("C", 8), ("V", 9), ("B", 11), ("Q", 12), ("W", 13), ("E", 14), ("R", 15),
        ("Y", 16), ("T", 17), ("1", 18), ("2", 19), ("3", 20), ("4", 21), ("5", 23),
        ("6", 22), ("=", 24), ("9", 25), ("7", 26), ("-", 27), ("8", 28), ("0", 29),
        ("O", 31), ("U", 32), ("I", 34), ("P", 35), ("Return", 36), ("L", 37), ("J", 38),
        ("K", 40), ("Tab", 48), ("Space", 49), ("Esc", 53),
        ("←", 123), ("→", 124), ("↓", 125), ("↑", 126),
    ]
}
