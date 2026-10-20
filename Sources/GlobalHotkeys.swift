import AppKit
import Carbon.HIToolbox

/// System-wide hotkeys so the two most important gaming actions keep working
/// while a game is frontmost. SwiftUI menu shortcuts only fire when Mac Gaming
/// Helper itself is focused, which is useless mid-game.
final class GlobalHotkeys {
    static let shared = GlobalHotkeys()

    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    private enum Action: UInt32 {
        case toggleMapping = 1
        case toggleOverlay = 2
        case profile1 = 3
        case profile2 = 4
        case profile3 = 5
    }

    func install() {
        guard refs.isEmpty else { return }

        register(.toggleMapping, key: UInt32(kVK_ANSI_M), modifiers: UInt32(optionKey | cmdKey))
        register(.toggleOverlay, key: UInt32(kVK_ANSI_P), modifiers: UInt32(controlKey | optionKey | cmdKey))
        register(.profile1, key: UInt32(kVK_ANSI_1), modifiers: UInt32(optionKey | cmdKey))
        register(.profile2, key: UInt32(kVK_ANSI_2), modifiers: UInt32(optionKey | cmdKey))
        register(.profile3, key: UInt32(kVK_ANSI_3), modifiers: UInt32(optionKey | cmdKey))

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard err == noErr else { return err }
                switch hkID.id {
                case Action.toggleMapping.rawValue:
                    NotificationCenter.default.post(name: .mghToggleMappingPause, object: nil)
                case Action.toggleOverlay.rawValue:
                    NotificationCenter.default.post(name: .mghToggleHUD, object: nil)
                case Action.profile1.rawValue:
                    NotificationCenter.default.post(name: .mghProfileSlot, object: 0)
                case Action.profile2.rawValue:
                    NotificationCenter.default.post(name: .mghProfileSlot, object: 1)
                case Action.profile3.rawValue:
                    NotificationCenter.default.post(name: .mghProfileSlot, object: 2)
                default:
                    break
                }
                return noErr
            },
            1,
            &spec,
            nil,
            &handler
        )
    }

    private func register(_ action: Action, key: UInt32, modifiers: UInt32) {
        var ref: EventHotKeyRef?
        // "MGH1" signature so our hot keys are distinguishable.
        let id = EventHotKeyID(signature: OSType(0x4D47_4831), id: action.rawValue)
        let status = RegisterEventHotKey(key, modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs.append(ref)
        }
    }
}
