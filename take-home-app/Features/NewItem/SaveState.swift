//
//  SaveState.swift
//

import Foundation

/// Why a save is blocked at the editing stage. Kept distinct from a local-save
/// failure (§3): validation is user-correctable inline; a `failed` save is a
/// disk/DB write error.
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

/// View state for the New Item screen. Saving is a discrete action (not a content
/// load), so it gets its own enum rather than `ViewState<Content>`. Validation
/// errors and local-save failures are deliberately separate cases.
enum SaveState: Equatable {
    case editing(validation: ItemValidationError?)
    case saving
    case saved
    case failed(String)
}
