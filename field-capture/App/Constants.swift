//
//  Constants.swift
//

import Foundation

nonisolated enum Constants {
    static let maxDerivativeBytes = 700_000
    static let eligibilityWindow: TimeInterval = 8 * 60 * 60
    static let maxPhotosPerItem = 25
    
    static let databaseFileName = "field-capture.sqlite"
    static let imagesDirectoryName = "images"
    static let originalsDirectoryName = "originals"
    static let derivativesDirectoryName = "derivatives"
}
