//
//  DebugSettings.swift
//

import Foundation

@Observable
@MainActor
final class DebugSettings {
    var simulateOffline = false
    var forceNextFailure = false

    func consumeForcedFailure() -> Bool {
        guard forceNextFailure else { return false }
        forceNextFailure = false
        return true
    }
}
