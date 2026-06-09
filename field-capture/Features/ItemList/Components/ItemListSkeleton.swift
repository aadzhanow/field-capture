//
//  ItemListSkeleton.swift
//

import SwiftUI

struct ItemListSkeleton: View {
    var body: some View {
        List {
            ForEach(0..<6, id: \.self) { _ in
                SkeletonRow()
            }
        }
        .shimmering()
        .allowsHitTesting(false)
    }
}

private struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            bar(width: 64, height: 64, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 6) {
                bar(width: 160, height: 14)
                bar(width: 120, height: 10)
                bar(width: 92, height: 18)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func bar(width: CGFloat, height: CGFloat, cornerRadius: CGFloat? = nil) -> some View {
        Color(.systemGray5)
            .frame(width: width, height: height)
            .clipShape(cornerRadius.map { AnyShape(.rect(cornerRadius: $0)) } ?? AnyShape(.capsule))
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var animating = false

    func body(content: Content) -> some View {
        content
            .opacity(animating ? 0.4 : 1)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: animating)
            .onAppear { animating = true }
    }
}

private extension View {
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}
