//
//  CloudAccountView.swift
//  PaddleUp
//
//  Optional cloud account: sign in to back up and sync profile, sessions,
//  reps, mechanic history, plans and settings. Signed out, everything keeps
//  working on this device.
//

import SwiftUI

struct CloudAccountView: View {
    @Environment(CloudAuthService.self) private var cloudAuth
    @Environment(CloudSyncService.self) private var sync

    @State private var showingDeleteCloud = false
    @State private var deleteMessage: String?

    var body: some View {
        List {
            if cloudAuth.isSignedIn {
                signedInSections
            } else {
                signedOutSection
            }
        }
        .scrollContentBackground(.hidden)
        .puScreenBackground()
        .navigationTitle("Cloud backup")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign-in problem", isPresented: Binding(
            get: { cloudAuth.errorMessage != nil },
            set: { if !$0 { cloudAuth.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cloudAuth.errorMessage ?? "")
        }
        .confirmationDialog("Delete your cloud copy?", isPresented: $showingDeleteCloud,
                            titleVisibility: .visible) {
            Button("Delete cloud data", role: .destructive) {
                Task {
                    let deleted = await sync.deleteCloudData()
                    deleteMessage = deleted
                        ? "Cloud copy deleted. Data on this device is untouched."
                        : "Couldn't delete right now. Check your connection and try again."
                    if deleted { cloudAuth.signOut() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes everything Paddle Up has stored in the cloud for your account and signs you out. Your data on this iPhone stays.")
        }
    }

    // MARK: - Signed out

    private var signedOutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                PUIconBadge(symbol: "icloud.and.arrow.up")
                Text("Keep your progress safe")
                    .font(PUFont.headline)
                    .foregroundStyle(PUColor.textPrimary)
                Text("Sign in to back up your profile, sessions, reps, mechanic history, plans and settings — and pick up where you left off on a new phone. Rep videos always stay on this device.")
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)

            Button {
                Task { await cloudAuth.signIn(provider: "apple") }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                    Text("Continue with Apple")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PUPrimaryButtonStyle())
            .disabled(cloudAuth.isSigningIn)

            Button {
                Task { await cloudAuth.signIn(provider: "google") }
            } label: {
                HStack {
                    Image(systemName: "globe")
                    Text("Continue with Google")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PUSecondaryButtonStyle())
            .disabled(cloudAuth.isSigningIn)

            if cloudAuth.isSigningIn {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        } footer: {
            Text("Optional. Paddle Up works fully without an account.")
        }
        .listRowBackground(PUColor.surface)
    }

    // MARK: - Signed in

    @ViewBuilder
    private var signedInSections: some View {
        Section {
            LabeledContent("Signed in as", value: cloudAuth.user?.email.isEmpty == false
                           ? (cloudAuth.user?.email ?? "") : (cloudAuth.user?.name ?? "Your account"))
            LabeledContent("Status", value: statusText)
            if let last = sync.lastSyncedAt {
                LabeledContent("Last synced", value: last.formatted(date: .omitted, time: .shortened))
            }
            Button {
                Task { await sync.syncNow() }
            } label: {
                HStack {
                    Text("Sync now")
                    Spacer()
                    if sync.status == .syncing { ProgressView() }
                }
            }
            .foregroundStyle(PUColor.lime)
            .disabled(sync.status == .syncing)
        } header: {
            Text("Cloud backup")
        } footer: {
            Text("Changes on this device sync automatically. If this device and the cloud both changed while offline, the most recent change wins.")
        }
        .listRowBackground(PUColor.surface)

        Section {
            Button("Sign out") { cloudAuth.signOut() }
                .foregroundStyle(PUColor.textPrimary)
            Button("Delete cloud data", role: .destructive) { showingDeleteCloud = true }
        } footer: {
            if let deleteMessage {
                Text(deleteMessage)
            } else {
                Text("Signing out keeps everything on this device; it just stops syncing.")
            }
        }
        .listRowBackground(PUColor.surface)
    }

    private var statusText: String {
        switch sync.status {
        case .idle: return "Up to date"
        case .syncing: return "Syncing…"
        case .offline: return "Offline — will sync on reconnect"
        case .failed(let message): return message
        case .signedOut: return "Signed out"
        }
    }
}
