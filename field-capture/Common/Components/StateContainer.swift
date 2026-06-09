//
//  StateContainer.swift
//

import SwiftUI

enum ViewState<Content> {
    case loading
    case loaded(Content)
    case empty
    case error(String)
}

struct StateContainer<Value, Loaded: View, Empty: View, Loading: View>: View {
    let state: ViewState<Value>
    var retry: (() -> Void)?
    @ViewBuilder var loaded: (Value) -> Loaded
    @ViewBuilder var empty: () -> Empty
    @ViewBuilder var loading: () -> Loading

    init(
        _ state: ViewState<Value>,
        retry: (() -> Void)? = nil,
        @ViewBuilder loaded: @escaping (Value) -> Loaded,
        @ViewBuilder empty: @escaping () -> Empty,
        @ViewBuilder loading: @escaping () -> Loading
    ) {
        self.state = state
        self.retry = retry
        self.loaded = loaded
        self.empty = empty
        self.loading = loading
    }

    var body: some View {
        switch state {
        case .loading:
            loading()
        case .empty:
            empty()
        case .loaded(let value):
            loaded(value)
        case .error(let message):
            ErrorStateView(message: message, retry: retry)
        }
    }
}

// Default loading view (a centered spinner) when no custom one is supplied.
extension StateContainer where Loading == DefaultLoadingView {
    init(
        _ state: ViewState<Value>,
        retry: (() -> Void)? = nil,
        @ViewBuilder loaded: @escaping (Value) -> Loaded,
        @ViewBuilder empty: @escaping () -> Empty
    ) {
        self.init(state, retry: retry, loaded: loaded, empty: empty, loading: { DefaultLoadingView() })
    }
}

struct DefaultLoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
