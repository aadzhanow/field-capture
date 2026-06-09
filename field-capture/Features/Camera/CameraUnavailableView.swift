//
//  CameraUnavailableView.swift
//

import SwiftUI
import UIKit

struct CameraUnavailableView: View {
    let icon: String
    let title: String
    let message: String
    let showSettings: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
            Text(title).font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 12) {
                Button("Back") { dismiss() }
                    .buttonStyle(.borderedProminent)
                if showSettings {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .tint(.blue)
            .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .padding(40)
    }
}
