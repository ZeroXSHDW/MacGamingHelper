import Foundation

enum StickCurve: String, CaseIterable, Identifiable, Codable {
    case linear, easeOut, expo
    var id: String { rawValue }
    var title: String {
        switch self {
        case .linear: return "Linear"
        case .easeOut: return "Ease-out"
        case .expo: return "Expo"
        }
    }

    /// Map stick magnitude 0…1 through the curve (after deadzone).
    func apply(_ t: Double) -> Double {
        let x = max(0, min(1, t))
        switch self {
        case .linear: return x
        case .easeOut: return 1 - pow(1 - x, 2)
        case .expo: return pow(x, 2.4)
        }
    }
}

enum StickMath {
    /// Apply deadzone then curve to a bipolar axis, return scaled output -1…1 shaped.
    static func shaped(value: Double, deadzone: Double, curve: StickCurve) -> Double {
        let v = value
        let mag = abs(v)
        if mag <= deadzone { return 0 }
        let norm = (mag - deadzone) / max(0.0001, 1 - deadzone)
        let shaped = curve.apply(norm)
        return (v >= 0 ? 1 : -1) * shaped
    }
}
