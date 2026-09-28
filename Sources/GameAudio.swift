import AppKit
import Foundation

enum GameCue: String {
    case connected, disconnected, lowBattery, buttonBeep
}

enum GameAudio {
    @MainActor
    static func play(_ cue: GameCue, settings: AppSettings) {
        switch cue {
        case .connected, .disconnected:
            guard settings.audioConnectCues else { return }
        case .lowBattery:
            guard settings.audioLowBatteryCue else { return }
        case .buttonBeep:
            guard settings.audioTesterBeeps else { return }
        }
        let name: String
        switch cue {
        case .connected: name = "Glass"
        case .disconnected: name = "Pop"
        case .lowBattery: name = "Basso"
        case .buttonBeep: name = "Tink"
        }
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.volume = cue == .buttonBeep ? 0.25 : 0.5
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
