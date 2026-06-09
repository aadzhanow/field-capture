//
//  RootView.swift
//

import SwiftUI

struct RootView: View {
    let diContainer: DIContainer

    var body: some View {
        ItemListView(diContainer: diContainer)
            .task {
                #if DEBUG
                logContainerPaths()
                #endif
                await diContainer.recoveryService.recover()
            }
    }

    #if DEBUG
    private func logContainerPaths() {
        let documents = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        Log.appDebug("📦 App container — Home: \(NSHomeDirectory())")
        if let documents {
            Log.appDebug("Documents: \(documents.path)")
            Log.appDebug("Database: \(documents.appendingPathComponent(Constants.databaseFileName).path)")
            Log.appDebug("Images: \(documents.appendingPathComponent(Constants.imagesDirectoryName).path)")
        }
    }
    #endif
}
