//
//  PrivacyView.swift
//  PaddleUp
//
//  Camera/body-data transparency plus real storage controls.
//

import SwiftUI

struct PrivacyView: View {
    @Environment(AppState.self) private var appState
    @State private var showingDeleteClips = false
    @State private var showingDeleteSessions = false

    var body: some View {
        List {
            Section {
                PrivacyPoint(
                    symbol: "iphone.gen3",
                    title: "Analysis runs on your iPhone",
                    detail: "Pose estimation, rep detection and scoring all happen on-device. Your video is not uploaded for analysis."
                )
                PrivacyPoint(
                    symbol: "film",
                    title: "Only short clips are kept",
                    detail: "The camera runs continuously, but Paddle Up keeps a rolling in-memory buffer and saves roughly three seconds around each detected rep. Everything else is discarded."
                )
                PrivacyPoint(
                    symbol: "mic.slash",
                    title: "No microphone access",
                    detail: "Paddle Up speaks coaching cues but never records audio."
                )
            } header: {
                Text("How your data is handled")
            }
            .listRowBackground(PUColor.surface)

            Section {
                Toggle("Save rep clips", isOn: Binding(
                    get: { appState.settings.saveRepClips },
                    set: { value in appState.updateSettings { $0.saveRepClips = value } }
                ))
                .tint(PUColor.lime)

                Picker("Keep clips for", selection: Binding(
                    get: { appState.settings.clipRetentionDays },
                    set: { value in appState.updateSettings { $0.clipRetentionDays = value } }
                )) {
                    Text("3 days").tag(3)
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                }

                HStack {
                    Text("Clip storage used")
                    Spacer()
                    Text(appState.clipStorageDescription)
                        .foregroundStyle(PUColor.textSecondary)
                }
            } header: {
                Text("Storage controls")
            } footer: {
                Text("Turning clips off keeps scores and mechanic data but stops any video being written to disk.")
            }
            .listRowBackground(PUColor.surface)

            Section {
                Toggle("Share anonymous usage analytics", isOn: Binding(
                    get: { appState.settings.analyticsEnabled },
                    set: { value in appState.updateSettings { $0.analyticsEnabled = value } }
                ))
                .tint(PUColor.lime)
            } header: {
                Text("Analytics")
            } footer: {
                Text("Used to measure detection accuracy and improve coaching. Never includes video or identifiable data.")
            }
            .listRowBackground(PUColor.surface)

            Section {
                Toggle("Help improve scoring", isOn: Binding(
                    get: { appState.settings.shareAnonymizedData },
                    set: { value in appState.updateSettings { $0.shareAnonymizedData = value } }
                ))
                .tint(PUColor.lime)
                .accessibilityIdentifier("share-anonymized-data")
            } header: {
                Text("Research sharing")
            } footer: {
                Text("Off by default. When on, new sessions and reps are marked as OK to include, anonymized, in future work to improve Paddle Up's scoring. Nothing is sent today, video is never included, and turning this off stops marking new records.")
            }
            .listRowBackground(PUColor.surface)

            Section {
                Button("Delete all saved clips", role: .destructive) { showingDeleteClips = true }
                Button("Delete all practice data", role: .destructive) { showingDeleteSessions = true }
            } header: {
                Text("Delete data")
            }
            .listRowBackground(PUColor.surface)
        }
        .scrollContentBackground(.hidden)
        .puScreenBackground()
        .navigationTitle("Privacy & data")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete all saved clips?", isPresented: $showingDeleteClips,
                            titleVisibility: .visible) {
            Button("Delete clips", role: .destructive) {
                appState.deleteAllClips()
                Haptics.success()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your scores and mechanic history are kept. Only the video clips are removed.")
        }
        .confirmationDialog("Delete all practice data?", isPresented: $showingDeleteSessions,
                            titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                appState.deleteAllPracticeData()
                Haptics.warning()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every session, rep, clip and rating. Your account stays active.")
        }
    }
}

struct PrivacyPoint: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PUColor.lime)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PUFont.body)
                    .foregroundStyle(PUColor.textPrimary)
                Text(detail)
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
