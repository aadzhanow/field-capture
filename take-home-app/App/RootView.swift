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
        let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        print("📦 App container")
        print("   Home:        \(NSHomeDirectory())")
        if let appSupport {
            print("   App Support: \(appSupport.path)")
            print("   Database:    \(appSupport.appendingPathComponent(Constants.databaseFileName).path)")
            print("   Images:      \(appSupport.appendingPathComponent(Constants.imagesDirectoryName).path)")
        }
    }
    #endif
}
