//
//  StateContainer.swift
//

import SwiftUI

/// What a screen should draw right now. Transient, per-screen, never persisted.
enum ViewState<Content> {
    case loading
    case loaded(Content)
    case empty
    case error(String)
}

struct StateContainer<Value, Loaded: View, Empty: View>: View {
    let state: ViewState<Value>
    var retry: (() -> Void)?
    @ViewBuilder var loaded: (Value) -> Loaded
    @ViewBuilder var empty: () -> Empty

    init(
        _ state: ViewState<Value>,
        retry: (() -> Void)? = nil,
        @ViewBuilder loaded: @escaping (Value) -> Loaded,
        @ViewBuilder empty: @escaping () -> Empty
    ) {
        self.state = state
        self.retry = retry
        self.loaded = loaded
        self.empty = empty
    }

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            empty()
        case .loaded(let value):
            loaded(value)
        case .error(let message):
            ErrorStateView(message: message, retry: retry)
        }
    }
}

struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry {
                Button("Try Again", action: retry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
