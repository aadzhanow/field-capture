//
//  RootView.swift
//

import SwiftUI

struct RootView: View {
    let diContainer: DIContainer

    var body: some View {
        GalleryView(diContainer: diContainer)
            .task {
                // Reconcile and resume anything left unfinished by a prior run.
                await diContainer.recoveryService.recover()
            }
    }
}
