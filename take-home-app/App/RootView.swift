//
//  RootView.swift
//

import SwiftUI

struct RootView: View {
    let diContainer: DIContainer

    var body: some View {
        GalleryView(diContainer: diContainer)
            .task {
                #if DEBUG
                printContainerPaths()
                #endif
                await diContainer.recoveryService.recover()
            }
    }

    #if DEBUG
    private func printContainerPaths() {
        let documents = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        print("📦 App container")
        print("Home: \(NSHomeDirectory())")
        if let documents {
            print("Documents: \(documents.path)")
            print("Database: \(documents.appendingPathComponent(Constants.databaseFileName).path)")
            print("Images: \(documents.appendingPathComponent(Constants.imagesDirectoryName).path)")
        }
    }
    #endif
}
