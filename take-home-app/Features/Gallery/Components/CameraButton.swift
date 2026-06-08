//
//  CameraButton.swift
//

import SwiftUI

struct CameraButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "camera")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .glassEffectIfAvailable(.blue, in: .circle)
        }
    }
}
