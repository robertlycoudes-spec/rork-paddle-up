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
    @State private var cloudAuth: CloudAuthService
    @State private var sync: CloudSyncService

    init() {
        let cloudAuth = CloudAuthService()
        _cloudAuth = State(initialValue: cloudAuth)
        _sync = State(initialValue: CloudSyncService(auth: cloudAuth))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(appState)
                .environment(store)
                .environment(cloudAuth)
                .environment(sync)
        }
    }
}
