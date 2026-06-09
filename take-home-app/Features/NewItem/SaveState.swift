//
//  SaveState.swift
//

import Foundation

enum ItemValidationError: Equatable {
    case titleEmpty
    case noPhotos

    var message: String {
        switch self {
        case .titleEmpty: "Enter a title before saving."
        case .noPhotos:   "Add at least one photo before saving."
        }
    }
}

enum SaveState: Equatable {
    case editing(validation: ItemValidationError?)
    case saving
    case saved
    case failed(String)
}
