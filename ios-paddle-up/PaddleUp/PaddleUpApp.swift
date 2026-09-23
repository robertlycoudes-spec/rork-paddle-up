//
//  PaddleUpApp.swift
//  PaddleUp
//

import SwiftUI

@main
struct PaddleUpApp: App {
    @State private var auth = AuthService()
    @State private var appState = AppState()
    @State private var store: StoreService
    @State private var cloudAuth: CloudAuthService
    @State private var sync: CloudSyncService
    @State private var comp: CompAccessService

    init() {
        let store = StoreService()
        let cloudAuth = CloudAuthService()
        _store = State(initialValue: store)
        _cloudAuth = State(initialValue: cloudAuth)
        _sync = State(initialValue: CloudSyncService(auth: cloudAuth))
        _comp = State(initialValue: CompAccessService(auth: cloudAuth, store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(appState)
                .environment(store)
                .environment(cloudAuth)
                .environment(sync)
                .environment(comp)
        }
    }
}
