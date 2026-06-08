//
//  RootView.swift
//

import SwiftUI

struct RootView: View {
    let diContainer: DIContainer

    var body: some View {
        GalleryView(diContainer: diContainer)
    }
}
