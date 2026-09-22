//
//  PaddleUpApp.swift
//  PaddleUp
//

import SwiftUI

@main
struct PaddleUpApp: App {
    @State private var auth = AuthService()
    @State private var appState = AppState()
    @State private var store = StoreService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(appState)
                .environment(store)
        }
    }
}
