//
//  CloudConnectionSections.swift
//  PaddleUp
//
//  List sections for Paddle Up Cloud: live connection status, sign-in
//  (Apple / Google), Sync now and Sign out. Shared by the Account and
//  Cloud backup screens so both always show the same state.
//

import SwiftUI

struct CloudConnectionSections: View {
    @Environment(CloudAuthService.self) private var cloudAuth
    @Environment(CloudSyncService.self) private var sync

    /// Show the explanatory "why sign in" card above the sign-in buttons.
    var showsPitch: Bool = true

    var body: some View {
        if cloudAuth.isSignedIn {
            signedInSections
        } else {
            signedOutSection
        }
    }

    // MARK: - Signed out

    private var signedOutSection: some View {
        Section {
            statusRow

            if showsPitch {
                Text("Sign in to back up your profile, sessions, reps, mechanic history, plans and settings, and restore them on a new phone. Rep videos always stay on this device.")
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 2)
            }

            Button {
                Haptics.tap()
                Task { await cloudAuth.signIn(provider: "apple") }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                    Text("Continue with Apple")
                }
            }
            .buttonStyle(PUPrimaryButtonStyle(enabled: !cloudAuth.isSigningIn))
            .disabled(cloudAuth.isSigningIn)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
            .accessibilityIdentifier("cloudSignInApple")

            Button {
                Haptics.tap()
                Task { await cloudAuth.signIn(provider: "google") }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "g.circle.fill")
                    Text("Continue with Google")
                }
            }
            .buttonStyle(PUSecondaryButtonStyle())
            .disabled(cloudAuth.isSigningIn)
            .opacity(cloudAuth.isSigningIn ? 0.5 : 1)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            .accessibilityIdentifier("cloudSignInGoogle")
        } header: {
            Text("Paddle Up Cloud")
        } footer: {
            Text("Optional. Paddle Up works fully on this device without an account.")
        }
        .listRowBackground(PUColor.surface)
    }

    // MARK: - Signed in

    @ViewBuilder
    private var signedInSections: some View {
        Section {
            statusRow
            LabeledContent("Signed in as", value: accountLabel)
            if let last = sync.lastSyncedAt {
                LabeledContent("Last synced", value: last.formatted(date: .omitted, time: .shortened))
            }
            Button {
                Haptics.tap()
                Task { await sync.syncNow() }
            } label: {
                HStack {
                    Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    if sync.status == .syncing { ProgressView() }
                }
            }
            .foregroundStyle(PUColor.lime)
            .disabled(sync.status == .syncing)
            .accessibilityIdentifier("cloudSyncNow")
        } header: {
            Text("Paddle Up Cloud")
        } footer: {
            Text("Changes sync automatically. If this device and the cloud both changed while offline, the most recent change wins.")
        }
        .listRowBackground(PUColor.surface)

        Section {
            Button("Sign out") {
                Haptics.tap()
                cloudAuth.signOut()
            }
            .foregroundStyle(PUColor.textPrimary)
            .accessibilityIdentifier("cloudSignOut")
        } footer: {
            Text("Signing out keeps everything on this device. It just stops syncing.")
        }
        .listRowBackground(PUColor.surface)
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusTint.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: statusSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(statusTint)
                    .symbolEffect(.pulse, isActive: isBusy)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(PUFont.headline)
                    .foregroundStyle(PUColor.textPrimary)
                Text(statusDetail)
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if isBusy { ProgressView() }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cloudStatus")
        .animation(.easeInOut(duration: 0.2), value: statusTitle)
    }

    private var isBusy: Bool {
        cloudAuth.isSigningIn || (cloudAuth.isSignedIn && sync.status == .syncing)
    }

    private var accountLabel: String {
        guard let user = cloudAuth.user else { return "Your account" }
        if !user.email.isEmpty { return user.email }
        return user.name ?? "Your account"
    }

    private var statusTitle: String {
        if cloudAuth.isSigningIn { return "Signing in…" }
        guard cloudAuth.isSignedIn else { return "Not connected" }
        switch sync.status {
        case .syncing: return "Syncing…"
        case .idle: return sync.lastSyncedAt == nil ? "Connected" : "Connected · Up to date"
        case .offline: return "Offline"
        case .failed: return "Can't reach the cloud"
        case .signedOut: return "Connecting…"
        }
    }

    private var statusDetail: String {
        if cloudAuth.isSigningIn { return "Finish signing in the window that opened." }
        guard cloudAuth.isSignedIn else { return "Your data is saved on this iPhone only." }
        switch sync.status {
        case .syncing: return "Backing up to Paddle Up Cloud."
        case .idle: return "Your data is backed up to Paddle Up Cloud."
        case .offline: return "Changes are saved and will sync when you reconnect."
        case .failed(let message): return message
        case .signedOut: return "Checking your cloud copy."
        }
    }

    private var statusSymbol: String {
        if cloudAuth.isSigningIn { return "person.badge.key" }
        guard cloudAuth.isSignedIn else { return "icloud.slash" }
        switch sync.status {
        case .syncing, .signedOut: return "arrow.triangle.2.circlepath.icloud"
        case .idle: return "checkmark.icloud"
        case .offline: return "wifi.slash"
        case .failed: return "exclamationmark.icloud"
        }
    }

    private var statusTint: Color {
        if cloudAuth.isSigningIn { return PUColor.textSecondary }
        guard cloudAuth.isSignedIn else { return PUColor.textSecondary }
        switch sync.status {
        case .idle: return PUColor.lime
        case .syncing, .signedOut, .offline: return PUColor.amber
        case .failed: return PUColor.alert
        }
    }
}
