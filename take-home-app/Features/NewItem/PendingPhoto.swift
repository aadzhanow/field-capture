//
//  PendingPhoto.swift
//

import UIKit

/// One captured-but-unsaved photo. Holds the compressed source `data` (written
/// to disk on save) plus a small pre-decoded `thumbnail` for the pending grid —
/// never a full-resolution bitmap, so a 25-photo draft stays memory-light
/// (§4.3/§11). Capture order is the array index until save assigns `sortOrder`.
struct PendingPhoto: Identifiable {
    let id: String
    let data: Data
    let thumbnail: UIImage
}
