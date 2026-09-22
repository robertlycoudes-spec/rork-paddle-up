//
//  AccountView.swift
//  PaddleUp
//

import SwiftUI

struct AccountView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var showingDeleteAccount = false
    @State private var deleteConfirmationText = ""

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("Your name", text: $displayName)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(PUColor.textPrimary)
                        .onSubmit { auth.updateDisplayName(displayName) }
                }
                Button("Save changes") {
                    auth.updateDisplayName(displayName)
                    appState.updateProfile { $0.displayName = displayName }
                    Haptics.success()
                }
                .foregroundStyle(PUColor.lime)
            } header: {
                Text("Account details")
            }
            .listRowBackground(PUColor.surface)

            Section {
                HStack {
                    Text("Sessions")
                    Spacer()
                    Text("\(appState.completedSessionCount)").foregroundStyle(PUColor.textSecondary)
                }
                HStack {
                    Text("Reps measured")
                    Spacer()
                    Text("\(appState.totalRepCount)").foregroundStyle(PUColor.textSecondary)
                }
                HStack {
                    Text("Member since")
                    Spacer()
                    Text(appState.profile.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(PUColor.textSecondary)
                }
            } header: {
                Text("Your data")
            }
            .listRowBackground(PUColor.surface)

            Section {
                Button("Delete all data", role: .destructive) {
                    showingDeleteAccount = true
                }
            } header: {
                Text("Danger zone")
            } footer: {
                Text("Deleting your data permanently removes your profile, sessions, reps, clips and ratings from this device.")
            }
            .listRowBackground(PUColor.surface)
        }
        .scrollContentBackground(.hidden)
        .puScreenBackground()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { displayName = appState.profile.displayName }
        .alert("Delete all data?", isPresented: $showingDeleteAccount) {
            Button("Cancel", role: .cancel) {}
            Button("Delete permanently", role: .destructive) {
                appState.deleteEverything()
                appState.unload()
                let account = auth.ensureLocalAccount()
                appState.load(accountID: account.id, email: account.email,
                              displayName: account.displayName)
            }
        } message: {
            Text("This cannot be undone. Your profile, sessions, reps and clips will be erased.")
        }
    }
}
