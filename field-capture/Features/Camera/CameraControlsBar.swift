//
//  CameraControlsBar.swift
//

import SwiftUI
import UIKit

struct CameraControlsBar: View {
    let capturedCount: Int
    let lastThumbnail: UIImage?
    let canCapture: Bool
    let onShutter: () -> Void
    let onThumbnailTap: () -> Void
    let onDone: () -> Void

    var body: some View {
        ZStack {
            shutterButton

            HStack {
                thumbnailPreview
                Spacer()
                doneButton
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    private var shutterButton: some View {
        Button(action: onShutter) {
            Color.white
                .frame(width: 64, height: 64)
                .clipShape(.circle)
                .overlay {
                    Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(!canCapture)
        .opacity(canCapture ? 1 : 0.4)
    }

    @ViewBuilder
    private var thumbnailPreview: some View {
        if capturedCount > 0 {
            Button(action: onThumbnailTap) {
                Group {
                    if let lastThumbnail {
                        Image(uiImage: lastThumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(.rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(.gray, lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    Text("\(capturedCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.black.opacity(0.65), in: .capsule)
                        .offset(x: 6, y: -6)
                }
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 48, height: 48)
        }
    }

    private var doneButton: some View {
        Button(action: onDone) {
            Text("Done")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .glassEffectIfAvailable(.blue, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(capturedCount == 0)
        .opacity(capturedCount == 0 ? 0.4 : 1)
    }
}
