//
//  DebugSettings.swift
//

import Foundation

/// First-class debug controls (§3 Debug screen): read by the processing pipeline
/// and bound by the Debug screen, so failure, retry, and the offline path are
/// testable without waiting. `@MainActor` + `@Observable` for the UI toggles; the
/// mock service reads these with an `await` hop from its background context.
///
/// The 8-hour rule is *not* a flag here — "make eligible" back-dates an item's
/// `createdAt` (a DB write, via the repository) so it flows through
/// `ValueObservation` like any other change.
@Observable
@MainActor
final class DebugSettings {
    /// When on, every processing attempt throws `ProcessingError.offline`.
    var simulateOffline = false

    /// One-shot: the next processing attempt fails deterministically, then clears.
    var forceNextFailure = false

    /// Test-and-clear the one-shot forced-failure flag.
    func consumeForcedFailure() -> Bool {
        guard forceNextFailure else { return false }
        forceNextFailure = false
        return true
    }
}
