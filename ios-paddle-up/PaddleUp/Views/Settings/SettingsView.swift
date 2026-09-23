//
//  SettingsView.swift
//  PaddleUp
//

import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(StoreService.self) private var store
    @Environment(CloudAuthService.self) private var cloudAuth
    @Environment(CloudSyncService.self) private var sync
    @Environment(CompAccessService.self) private var comp
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeveloperTuning = false
    @State private var showingManageSubscriptions = false
    @State private var showingOfferCodeSheet = false
    @State private var restoreMessage: String?
    @State private var compCode: String = ""
    @State private var compResult: CompAccessService.RedeemResult?
    @FocusState private var compFieldFocused: Bool

    var body: some View {
        List {
            subscriptionSection
            redeemSection
            cloudSection
            coachingSection
            practiceSection
            playerSection
            privacySection
            accountSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .puScreenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showingDeveloperTuning) { RubricTuningView() }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .onChange(of: showingManageSubscriptions) { _, isShowing in
            if !isShowing { Task { await store.refreshEntitlements() } }
        }
        .offerCodeRedemption(isPresented: $showingOfferCodeSheet) { _ in
            Task { await store.offerCodeRedemptionFinished() }
        }
    }

    // MARK: - Sections

    private var subscriptionSection: some View {
        Section {
            if store.isPro {
                HStack {
                    Label("Paddle Up Pro", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(PUColor.lime)
                    Spacer()
                    Text(store.activeProduct?.title ?? (store.hasActiveComp ? "Friend code" : "Active"))
                        .foregroundStyle(PUColor.textSecondary)
                }
                if !store.hasVerifiedEntitlement, store.hasActiveComp {
                    HStack {
                        Text("Free access")
                        Spacer()
                        Text(store.compEntitlement?.compExpiresAt.map {
                            "Ends \($0.formatted(date: .abbreviated, time: .omitted))"
                        } ?? "Lifetime")
                            .foregroundStyle(PUColor.textSecondary)
                    }
                }
                if let expiry = store.expirationDate {
                    HStack {
                        Text(store.willAutoRenew == false ? "Ends" : "Renews")
                        Spacer()
                        Text(expiry.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(PUColor.textSecondary)
                    }
                }
                if store.hasVerifiedEntitlement {
                    Button("Manage subscription") { showingManageSubscriptions = true }
                        .foregroundStyle(PUColor.textPrimary)
                }
            } else {
                NavigationLink { PaywallView() } label: {
                    Label("Upgrade to Paddle Up Pro", systemImage: "sparkles")
                        .foregroundStyle(PUColor.lime)
                }
            }
            Button {
                Task {
                    let restored = await store.restore()
                    restoreMessage = restored ? "Paddle Up Pro restored." : store.lastError
                }
            } label: {
                HStack {
                    Text("Restore purchases")
                    Spacer()
                    if store.isPurchasing { ProgressView() }
                }
            }
            .foregroundStyle(PUColor.textPrimary)
            .disabled(store.isPurchasing)
        } header: {
            Text("Subscription")
        } footer: {
            if let restoreMessage { Text(restoreMessage) }
        }
        .listRowBackground(PUColor.surface)
    }

    /// Two separate redemption paths: Apple's offer-code sheet for App Store
    /// creator discounts, and a friend comp code checked by Paddle Up's server.
    private var redeemSection: some View {
        Section {
            Button {
                showingOfferCodeSheet = true
            } label: {
                Label("Redeem App Store offer code", systemImage: "giftcard")
            }
            .foregroundStyle(PUColor.textPrimary)
            .accessibilityIdentifier("redeem-offer-code")

            VStack(alignment: .leading, spacing: 10) {
                Text("Friend code")
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
                HStack(spacing: 10) {
                    TextField("Enter code", text: $compCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .focused($compFieldFocused)
                        .submitLabel(.go)
                        .onSubmit(redeemCompCode)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(PUColor.surfaceRaised, in: .rect(cornerRadius: 10))
                        .accessibilityIdentifier("comp-code-field")
                    Button(action: redeemCompCode) {
                        if comp.isRedeeming {
                            ProgressView().tint(PUColor.limeInk)
                        } else {
                            Text("Apply")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PUColor.limeInk)
                    .frame(width: 76, height: 44)
                    .background(PUColor.lime.opacity(canRedeemComp ? 1 : 0.35), in: .capsule)
                    .buttonStyle(.plain)
                    .disabled(!canRedeemComp)
                    .accessibilityIdentifier("comp-code-apply")
                }
                if let compResult {
                    Label(compResult.message,
                          systemImage: compResult.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(PUFont.caption)
                        .foregroundStyle(compResult.isSuccess ? PUColor.lime : PUColor.alert)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("Redeem Code")
        } footer: {
            Text(cloudAuth.isSignedIn
                 ? "App Store offer codes open Apple's redemption sheet. Friend codes unlock free Pro on your Paddle Up account."
                 : "App Store offer codes open Apple's redemption sheet. Friend codes need a Paddle Up Cloud sign-in (see Cloud below).")
        }
        .listRowBackground(PUColor.surface)
    }

    private var canRedeemComp: Bool {
        !comp.isRedeeming && !compCode.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func redeemCompCode() {
        guard canRedeemComp else { return }
        compFieldFocused = false
        Task {
            let result = await comp.redeem(code: compCode)
            withAnimation(.easeOut(duration: 0.2)) { compResult = result }
            if result.isSuccess {
                compCode = ""
                Haptics.success()
            } else {
                Haptics.warning()
            }
        }
    }

    private var cloudSection: some View {
        Section {
            NavigationLink { CloudAccountView() } label: {
                HStack {
                    Label("Cloud backup & sync", systemImage: "icloud")
                    Spacer()
                    Text(cloudStatusLabel)
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                }
            }
        } header: {
            Text("Cloud")
        }
        .listRowBackground(PUColor.surface)
    }

    private var cloudStatusLabel: String {
        guard cloudAuth.isSignedIn else { return "Off" }
        switch sync.status {
        case .syncing: return "Syncing…"
        case .offline: return "Offline"
        case .failed: return "Retrying"
        case .idle, .signedOut: return "On"
        }
    }

    private var coachingSection: some View {
        Section {
            Picker("Live audio coaching", selection: Binding(
                get: { appState.settings.voiceCoaching },
                set: { value in appState.updateSettings { $0.voiceCoaching = value } }
            )) {
                ForEach(VoiceCoachingLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            Toggle("Haptic feedback", isOn: Binding(
                get: { appState.settings.hapticFeedback },
                set: { value in appState.updateSettings { $0.hapticFeedback = value } }
            ))
            .tint(PUColor.lime)
        } header: {
            Text("Coaching")
        } footer: {
            Text("Paddle Up speaks only one correction at a time, and never mid-swing.")
        }
        .listRowBackground(PUColor.surface)
    }

    private var practiceSection: some View {
        Section {
            Picker("Default session length", selection: Binding(
                get: { appState.settings.defaultSessionLength },
                set: { value in appState.updateSettings { $0.defaultSessionLength = value } }
            )) {
                ForEach(SessionLength.allCases) { length in
                    Text(length.displayName).tag(length)
                }
            }
        } header: {
            Text("Practice")
        }
        .listRowBackground(PUColor.surface)
    }

    private var playerSection: some View {
        Section {
            Picker("Dominant hand", selection: Binding(
                get: { appState.profile.handedness },
                set: { value in appState.updateProfile { $0.handedness = value } }
            )) {
                ForEach(Handedness.allCases) { hand in
                    Text(hand.displayName).tag(hand)
                }
            }
            Picker("Level (DUPR)", selection: Binding(
                get: { appState.profile.duprRange ?? GamePlanEngine.defaultRange },
                set: { value in appState.updateProfile { $0.duprRange = value } }
            )) {
                ForEach(DuprRange.allCases) { range in
                    Text(range.fullLabel).tag(range)
                }
            }
            Picker("Primary focus", selection: Binding(
                get: { appState.profile.goals.first ?? .consistency },
                set: { value in appState.updateProfile { $0.goals = [value] } }
            )) {
                ForEach(TrainingGoal.allCases) { goal in
                    Text(goal.displayName).tag(goal)
                }
            }
        } header: {
            Text("Player")
        }
        .listRowBackground(PUColor.surface)
    }

    private var privacySection: some View {
        Section {
            NavigationLink { PrivacyView() } label: {
                Label("Privacy & data", systemImage: "hand.raised.fill")
            }
        }
        .listRowBackground(PUColor.surface)
    }

    private var accountSection: some View {
        Section {
            NavigationLink { AccountView() } label: {
                HStack {
                    Label("Account", systemImage: "person.crop.circle")
                    Spacer()
                    Text(cloudAuth.isSignedIn ? "Signed in" : "Not signed in")
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                }
            }
        } header: {
            Text("Account")
        }
        .listRowBackground(PUColor.surface)
    }

    private var aboutSection: some View {
        Section {
            Toggle("Developer mode", isOn: Binding(
                get: { appState.settings.developerModeEnabled },
                set: { value in appState.updateSettings { $0.developerModeEnabled = value } }
            ))
            .tint(PUColor.lime)

            if appState.settings.developerModeEnabled {
                Button("Rubric & detection tuning") { showingDeveloperTuning = true }
                    .foregroundStyle(PUColor.amber)
                NavigationLink { AnalyticsDebugView() } label: {
                    Label("Analytics", systemImage: "chart.xyaxis.line")
                        .foregroundStyle(PUColor.amber)
                }
                #if DEBUG
                Toggle("Pro override (debug builds only)", isOn: Binding(
                    get: { store.debugOverride },
                    set: { store.setPro($0) }
                ))
                .tint(PUColor.amber)
                #endif
            }

            HStack {
                Text("Benchmarks")
                Spacer()
                Text(BenchmarkLibrary.version)
                    .foregroundStyle(PUColor.textTertiary)
                    .font(.system(size: 13, design: .monospaced))
            }
        } header: {
            Text("Advanced")
        } footer: {
            Text("Developer mode exposes the pose skeleton, rep-detection state, joint angles and exportable analysis JSON during practice.")
        }
        .listRowBackground(PUColor.surface)
    }
}

struct AnalyticsDebugView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section("Detection quality") {
                if let acceptance = appState.analytics.repAcceptanceRate {
                    LabeledContent("Rep acceptance", value: "\(Int(acceptance * 100))%")
                }
                if let falsePositive = appState.analytics.falsePositiveRate {
                    LabeledContent("Deleted as false", value: "\(Int(falsePositive * 100))%")
                }
                LabeledContent("Total reps", value: "\(appState.totalRepCount)")
                LabeledContent("Sessions", value: "\(appState.completedSessionCount)")
            }
            .listRowBackground(PUColor.surface)

            Section("Event counts") {
                ForEach(appState.analytics.counts.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    LabeledContent(key, value: "\(value)")
                        .font(.system(size: 13, design: .monospaced))
                }
            }
            .listRowBackground(PUColor.surface)

            Section("Recent events") {
                ForEach(appState.analytics.recent.prefix(30), id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(PUColor.textSecondary)
                }
            }
            .listRowBackground(PUColor.surface)
        }
        .scrollContentBackground(.hidden)
        .puScreenBackground()
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Live rubric weight tuning — critical for calibrating scores with coaches.
struct RubricTuningView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shot: ShotType = .forehandDink
    @State private var weights: [MechanicID: Double] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Shot", selection: $shot) {
                        ForEach(ShotType.practiceable) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .onChange(of: shot) { _, _ in loadWeights() }
                }
                .listRowBackground(PUColor.surface)

                Section {
                    ForEach(RubricLibrary.rubric(for: shot).components) { component in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(component.mechanic.displayName)
                                    .font(PUFont.body)
                                Spacer()
                                Text("\(Int((weights[component.mechanic] ?? component.weight) * 100))%")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(PUColor.lime)
                            }
                            Slider(
                                value: Binding(
                                    get: { weights[component.mechanic] ?? component.weight },
                                    set: { weights[component.mechanic] = $0 }
                                ),
                                in: 0...0.6
                            )
                            .tint(PUColor.lime)
                            if !component.isMeasured {
                                Text("Not measured yet — excluded from scoring")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PUColor.amber)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Weights")
                } footer: {
                    Text("Total: \(Int(weights.values.reduce(0, +) * 100))%. Weights are renormalised across measured mechanics at scoring time.")
                }
                .listRowBackground(PUColor.surface)

                Section {
                    Button("Apply weights") {
                        RubricLibrary.setWeights(weights, for: shot)
                        Haptics.success()
                    }
                    .foregroundStyle(PUColor.lime)
                    Button("Reset to defaults") {
                        RubricLibrary.resetOverrides()
                        loadWeights()
                    }
                    .foregroundStyle(PUColor.alert)
                }
                .listRowBackground(PUColor.surface)
            }
            .scrollContentBackground(.hidden)
            .puScreenBackground()
            .navigationTitle("Rubric Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onAppear(perform: loadWeights)
        }
    }

    private func loadWeights() {
        weights = Dictionary(uniqueKeysWithValues:
            RubricLibrary.rubric(for: shot).components.map { ($0.mechanic, $0.weight) })
    }
}
