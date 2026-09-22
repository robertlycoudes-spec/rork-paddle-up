//
//  SettingsView.swift
//  PaddleUp
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(StoreService.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeveloperTuning = false

    var body: some View {
        List {
            subscriptionSection
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
    }

    // MARK: - Sections

    private var subscriptionSection: some View {
        Section {
            if store.isPro {
                HStack {
                    Label("Paddle Up Pro", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(PUColor.lime)
                    Spacer()
                    Text(store.activeProduct?.title ?? "Active")
                        .foregroundStyle(PUColor.textSecondary)
                }
                Button("Manage subscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundStyle(PUColor.textPrimary)
            } else {
                NavigationLink { PaywallView() } label: {
                    Label("Upgrade to Paddle Up Pro", systemImage: "sparkles")
                        .foregroundStyle(PUColor.lime)
                }
            }
            Button("Restore purchases") {
                Task { _ = await store.restore() }
            }
            .foregroundStyle(PUColor.textPrimary)
        } header: {
            Text("Subscription")
        }
        .listRowBackground(PUColor.surface)
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
            Picker("Skill level", selection: Binding(
                get: { appState.profile.skillLevel },
                set: { value in appState.updateProfile { $0.skillLevel = value } }
            )) {
                ForEach(SkillLevel.allCases) { level in
                    Text(level.displayName).tag(level)
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
                Label("Account", systemImage: "person.crop.circle")
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
                Toggle("Pro entitlement (debug)", isOn: Binding(
                    get: { store.isPro },
                    set: { store.setPro($0) }
                ))
                .tint(PUColor.amber)
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
