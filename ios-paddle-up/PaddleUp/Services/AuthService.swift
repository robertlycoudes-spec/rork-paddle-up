//
//  AuthService.swift
//  PaddleUp
//
//  Account-based identity. All player data is scoped to an account ID.
//
//  The standalone sign-up / log-in screen was removed: every launch runs on an
//  implicit on-device account created here. The credential-backed signUp / signIn
//  / resetPassword API remains as the single seam to replace when a hosted auth
//  backend is added; no screen touches the Keychain directly.
//

import CryptoKit
import Foundation
import Security

nonisolated struct Account: Codable, Sendable, Equatable {
    let id: String
    var email: String
    var displayName: String
}

nonisolated enum AuthError: LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case emailInUse
    case unknownAccount
    case wrongPassword
    case storageFailure

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return "Enter a valid email address."
        case .weakPassword: return "Use at least 8 characters."
        case .emailInUse: return "An account already exists for that email."
        case .unknownAccount: return "No account found for that email."
        case .wrongPassword: return "That password doesn't match."
        case .storageFailure: return "Couldn't save your credentials. Try again."
        }
    }
}

/// Keychain-backed credential record.
private struct StoredCredential: Codable {
    let accountID: String
    let email: String
    var displayName: String
    var passwordHash: String
    var salt: String
}

@MainActor
@Observable
final class AuthService {
    private(set) var currentAccount: Account?
    private let service = "app.paddleup.accounts"
    private let lastAccountKey = "app.paddleup.lastAccountEmail"

    var isSignedIn: Bool { currentAccount != nil }

    init() {
        restoreSession()
    }

    /// Returns the active account, creating the implicit local one if needed.
    func ensureLocalAccount() -> Account {
        if let currentAccount { return currentAccount }
        let account = createLocalAccount()
        currentAccount = account
        return account
    }

    // MARK: - Public API

    func signUp(email: String, password: String, displayName: String) throws -> Account {
        let normalizedEmail = normalize(email)
        try validate(email: normalizedEmail, password: password)
        guard credential(for: normalizedEmail) == nil else { throw AuthError.emailInUse }

        let salt = UUID().uuidString
        let credential = StoredCredential(
            accountID: UUID().uuidString,
            email: normalizedEmail,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            passwordHash: hash(password: password, salt: salt),
            salt: salt
        )
        guard store(credential) else { throw AuthError.storageFailure }

        let account = Account(id: credential.accountID, email: credential.email,
                              displayName: credential.displayName)
        currentAccount = account
        UserDefaults.standard.set(normalizedEmail, forKey: lastAccountKey)
        return account
    }

    func signIn(email: String, password: String) throws -> Account {
        let normalizedEmail = normalize(email)
        guard let credential = credential(for: normalizedEmail) else { throw AuthError.unknownAccount }
        guard hash(password: password, salt: credential.salt) == credential.passwordHash else {
            throw AuthError.wrongPassword
        }
        let account = Account(id: credential.accountID, email: credential.email,
                              displayName: credential.displayName)
        currentAccount = account
        UserDefaults.standard.set(normalizedEmail, forKey: lastAccountKey)
        return account
    }

    func signOut() {
        currentAccount = nil
        UserDefaults.standard.removeObject(forKey: lastAccountKey)
    }

    /// Resets the password for an existing account.
    func resetPassword(email: String, newPassword: String) throws {
        let normalizedEmail = normalize(email)
        guard var credential = credential(for: normalizedEmail) else { throw AuthError.unknownAccount }
        guard newPassword.count >= 8 else { throw AuthError.weakPassword }
        let salt = UUID().uuidString
        credential.salt = salt
        credential.passwordHash = hash(password: newPassword, salt: salt)
        guard store(credential) else { throw AuthError.storageFailure }
    }

    func updateDisplayName(_ name: String) {
        guard var account = currentAccount, var credential = credential(for: account.email) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        credential.displayName = trimmed
        _ = store(credential)
        account.displayName = trimmed
        currentAccount = account
    }

    /// Permanently removes the credential record. The caller is responsible for
    /// deleting the account's practice data.
    func deleteAccount() {
        guard let account = currentAccount else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.email
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: lastAccountKey)
        currentAccount = nil
    }

    // MARK: - Private

    private func restoreSession() {
        if let email = UserDefaults.standard.string(forKey: lastAccountKey),
           let credential = credential(for: email) {
            currentAccount = Account(id: credential.accountID, email: credential.email,
                                     displayName: credential.displayName)
            return
        }
        currentAccount = createLocalAccount()
    }

    /// The implicit on-device player account — no sign-up flow, stable ID across
    /// launches so scoped data survives.
    private func createLocalAccount() -> Account {
        let key = "app.paddleup.localAccountID"
        let id = UserDefaults.standard.string(forKey: key) ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return Account(id: id, email: "local@paddleup.app", displayName: "")
    }

    private func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func validate(email: String, password: String) throws {
        guard email.contains("@"), email.contains("."), email.count >= 6 else { throw AuthError.invalidEmail }
        guard password.count >= 8 else { throw AuthError.weakPassword }
    }

    private func hash(password: String, salt: String) -> String {
        let data = Data((salt + password).utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func credential(for email: String) -> StoredCredential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(StoredCredential.self, from: data)
    }

    private func store(_ credential: StoredCredential) -> Bool {
        guard let data = try? JSONEncoder().encode(credential) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credential.email
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }
}
