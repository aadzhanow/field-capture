//
//  FieldCaptureApp.swift
//

import SwiftUI

@main
struct FieldCaptureApp: App {
    @State private var diContainer = DIContainer()

    var body: some Scene {
        WindowGroup {
            RootView(diContainer: diContainer)
        }
    }
}
