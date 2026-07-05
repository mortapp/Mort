//
//  MORTApp.swift
//  MORT
//
//  Created by Rork on June 29, 2026.
//

import SwiftUI

@main
struct MORTApp: App {
    @State private var session = SessionStore(services: .mock)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(\.services, .mock)
        }
    }
}

