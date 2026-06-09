//
//  View+Ext.swift
//

import SwiftUI

extension View {
    @ViewBuilder
    func glassEffectIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self.background(.regularMaterial, in: .capsule)
        }
    }
}

extension View {
    @ViewBuilder
    func glassEffectIfAvailable(tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint))
        } else {
            self
                .background(tint, in: .capsule)
                .background(.regularMaterial, in: .capsule)
        }
    }
}

extension View {
    @ViewBuilder
    func glassEffectIfAvailable<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }
}

extension View {
    @ViewBuilder
    func glassEffectIfAvailable<S: Shape>(_ tint: Color, in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint), in: shape)
        } else {
            self
                .background(tint, in: shape)
                .background(.regularMaterial, in: shape)
        }
    }
}
