import Foundation
import IOKit.pwr_mgt

/// Prevent display/system sleep while a gaming session is active (Play HUD or explicit toggle).
@MainActor
final class KeepAwake: ObservableObject {
    static let shared = KeepAwake()

    @Published private(set) var isAsserting = false
    private var assertionID: IOPMAssertionID = 0

    func update(active: Bool) {
        if active {
            acquire()
        } else {
            release()
        }
    }

    private func acquire() {
        guard !isAsserting else { return }
        let reason = "Mac Gaming Helper gaming session" as CFString
        let type = kIOPMAssertionTypeNoDisplaySleep as CFString
        let status = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        isAsserting = (status == kIOReturnSuccess)
        if !isAsserting {
            assertionID = 0
        }
    }

    private func release() {
        guard isAsserting, assertionID != 0 else {
            isAsserting = false
            assertionID = 0
            return
        }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isAsserting = false
    }

    deinit {
        // Best-effort; MainActor deinit may not run release — AppMain will clear on quit.
    }
}
