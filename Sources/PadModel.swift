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

    var face: (a: String, b: String, x: String, y: String) {
        switch self {
        case .dualShock4, .dualSense:
            return ("Cross", "Circle", "Square", "Triangle")
        default:
            return ("A", "B", "X", "Y")
        }
    }
}

struct ControllerSnapshot: Identifiable, Equatable {
    var id: String
    var title: String
    var vendor: String
    var category: String
    var kind: PadKind
    var battery: String
    var connected: Bool
    var buttons: [String]
    var lx: Double
    var ly: Double
    var rx: Double
    var ry: Double
    var lt: Double
    var rt: Double
    var touchpadPressed: Bool
    var homePressed: Bool
    var lightBarSupported: Bool
    var playerIndex: Int

    static let empty = ControllerSnapshot(
        id: "none",
        title: "No controller",
        vendor: "",
        category: "",
        kind: .none,
        battery: "",
        connected: false,
        buttons: [],
        lx: 0, ly: 0, rx: 0, ry: 0, lt: 0, rt: 0,
        touchpadPressed: false,
        homePressed: false,
        lightBarSupported: false,
        playerIndex: -1
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
    var control: String          // e.g. "Cross", "L1", "LeftStick", "RightStick", "L2"
    var target: MappingTarget
    var keyCode: UInt16?         // CGKeyCode
    var keyName: String?
    var mouseButton: Int?        // 0 left, 1 right, 2 other
    var mouseAxis: String?       // "x", "y", or "xy" for stick→mouse
    var scale: Double            // mouse sensitivity or trigger threshold

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

struct MappingProfile: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var deadzone: Double
    var bindings: [MappingBinding]

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
        ]
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
        ]
    )

    static let presets: [MappingProfile] = [.fpsWASD, .arrowsBrowse]
}
