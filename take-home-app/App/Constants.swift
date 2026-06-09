//
//  Constants.swift
//

import Foundation

enum Constants {
    static let maxDerivativeBytes = 700_000
    static let eligibilityWindow: TimeInterval = 8 * 60 * 60
    
    static let databaseFileName = "daero.sqlite"
    static let imagesDirectoryName = "Images"
    static let originalsDirectoryName = "originals"
    static let derivativesDirectoryName = "derivatives"
}
