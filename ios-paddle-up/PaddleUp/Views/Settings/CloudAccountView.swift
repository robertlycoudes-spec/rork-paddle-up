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
            CloudConnectionSections(showsPitch: true)
            if cloudAuth.isSignedIn {
                deleteCloudSection
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

    // MARK: - Delete cloud copy

    private var deleteCloudSection: some View {
        Section {
            Button("Delete cloud data", role: .destructive) { showingDeleteCloud = true }
        } footer: {
            Text(deleteMessage ?? "Removes your cloud copy only. Data on this iPhone stays.")
        }
        .listRowBackground(PUColor.surface)
    }
}
