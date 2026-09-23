//
//  RootView.swift
//  PaddleUp
//
//  Top-level routing: splash → onboarding → main tabs.
//

import SwiftUI

@MainActor
@Observable
final class PracticeRouter {
    /// Non-nil while a practice session is running full-screen.
    var activeConfiguration: PracticeConfiguration?
    /// Set when a session finishes, to present its summary.
    var completedSessionID: UUID?
    /// Set to route the player to a specific drill from anywhere.
    var pendingDrillID: String?
    var showsPaywall = false

    func startPractice(_ configuration: PracticeConfiguration) {
        activeConfiguration = configuration
    }
}

nonisolated struct PracticeConfiguration: Identifiable, Sendable, Equatable {
    let id = UUID()
    var shot: ShotType
    var mode: SessionMode
    var drillID: String?
    var length: SessionLength

    var drill: Drill? { drillID.flatMap(DrillLibrary.drill(id:)) }
}

struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AppState.self) private var appState
    @Environment(StoreService.self) private var store
    @Environment(CloudAuthService.self) private var cloudAuth
    @Environment(CloudSyncService.self) private var sync
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingSplash = true

    var body: some View {
        ZStack {
            if appState.profile.hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }

            if showingSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.profile.hasCompletedOnboarding)
        .preferredColorScheme(.dark)
        .task {
            let account = auth.ensureLocalAccount()
            appState.load(accountID: account.id, email: account.email,
                          displayName: account.displayName)
            sync.attach(appState)
            async let splash: Void = { try? await Task.sleep(for: .milliseconds(1100)) }()
            await cloudAuth.checkAuth()
            await sync.syncNow()
            await splash
            withAnimation(.easeInOut(duration: 0.45)) { showingSplash = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                appState.flush()
            } else if !showingSplash {
                Task {
                    await store.refreshEntitlements()
                    await sync.syncNow()
                }
            }
        }
        .onChange(of: cloudAuth.isSignedIn) { _, signedIn in
            if signedIn {
                Task { await sync.syncNow() }
            } else {
                sync.signedOut()
            }
        }
    }
}

struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            PUBackground().ignoresSafeArea()
            VStack(spacing: 18) {
                PUBallGlyph(size: 62)
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)
                VStack(spacing: 6) {
                    Text("Paddle Up")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(PUColor.textPrimary)
                    Text("Practice better  ·  Play higher")
                        .font(PUFont.micro)
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(PUColor.textTertiary)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appeared = true }
        }
    }
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(StoreService.self) private var store
    @State private var router = PracticeRouter()
    @State private var selection: Tab = .home

    enum Tab: Hashable { case home, practice, progress, profile }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(selection: $selection)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            PracticeTabView()
                .tabItem { Label("Practice", systemImage: "figure.strengthtraining.traditional") }
                .tag(Tab.practice)

            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                .tag(Tab.progress)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(Tab.profile)
        }
        .tint(PUColor.lime)
        .environment(router)
        .fullScreenCover(item: Binding(
            get: { router.activeConfiguration },
            set: { router.activeConfiguration = $0 }
        )) { configuration in
            PracticeSetupFlow(configuration: configuration)
        }
        .sheet(isPresented: Binding(
            get: { router.completedSessionID != nil },
            set: { if !$0 { router.completedSessionID = nil } }
        )) {
            if let id = router.completedSessionID, let session = appState.session(id: id) {
                NavigationStack {
                    SessionSummaryView(session: session, isModal: true)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { router.showsPaywall },
            set: { router.showsPaywall = $0 }
        )) {
            PaywallView()
        }
        .sheet(isPresented: Binding(
            get: { router.pendingDrillID != nil },
            set: { if !$0 { router.pendingDrillID = nil } }
        )) {
            if let id = router.pendingDrillID, let drill = DrillLibrary.drill(id: id) {
                NavigationStack {
                    DrillDetailView(drill: drill)
                }
            }
        }
        .onAppear {
            Haptics.enabled = appState.settings.hapticFeedback
            UITabBar.appearance().unselectedItemTintColor = UIColor(PUColor.textSecondary)
        }
    }
}
