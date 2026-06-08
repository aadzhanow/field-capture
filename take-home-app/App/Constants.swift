//
//  Constants.swift
//

import Foundation

enum Constants {
    /// Hard per-file ceiling for every generated derivative (§5).
    static let maxDerivativeBytes = 700_000

    /// An item becomes age-eligible at `createdAt + 8h` (§6).
    static let eligibilityWindow: TimeInterval = 8 * 60 * 60

    static let databaseFileName = "daero.sqlite"
    static let imagesDirectoryName = "Images"
    static let originalsDirectoryName = "originals"
    static let derivativesDirectoryName = "derivatives"
}
