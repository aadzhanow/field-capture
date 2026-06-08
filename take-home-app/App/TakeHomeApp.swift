//
//  TakeHomeApp.swift
//

import SwiftUI

@main
struct TakeHomeApp: App {
    @State private var diContainer = DIContainer()

    var body: some Scene {
        WindowGroup {
            RootView(diContainer: diContainer)
        }
    }
}
