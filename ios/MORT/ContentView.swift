//
//  ContentView.swift
//  MORT
//
//  Created by Rork on June 29, 2026.
//

import SwiftUI

/// Entry view. The real app lives in `RootView`, driven by `SessionStore`.
struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .environment(SessionStore(services: .mock))
        .environment(\.services, .mock)
}
