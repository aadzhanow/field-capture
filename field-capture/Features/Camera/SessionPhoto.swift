//
//  SessionPhoto.swift
//

import UIKit

/// One photo captured during a camera session. Holds the compressed `data`
/// (shared by copy-on-write with the pending item) plus a small strip thumbnail.
struct SessionPhoto: Identifiable {
    let id: String
    let data: Data
    var thumbnail: UIImage?
}
