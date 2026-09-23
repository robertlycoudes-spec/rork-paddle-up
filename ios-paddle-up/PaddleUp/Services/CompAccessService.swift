//
//  CompAccessService.swift
//  PaddleUp
//
//  Friend comp codes: redeems a code against the Paddle Up backend
//  (POST /v1/redeem-code) and keeps the account's comp entitlement in sync
//  (GET /v1/entitlement). Entirely separate from StoreKit — App Store offer
//  codes go through Apple's own redemption sheet instead.
//
//  The last confirmed grant is cached in the Keychain per account so Pro
//  keeps working offline; the server stays the source of truth and is
//  re-checked on launch, foreground and sign-in.
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class CompAccessService {
    private(set) var isRedeeming = false

    private let auth: CloudAuthService
    private let store: StoreService
    private let logger = Logger(subsystem: "app.paddleup", category: "comp")
    private static let cacheKey = "comp_entitlement"

    private var baseURL: URL? {
        let raw = Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    init(auth: CloudAuthService, store: StoreService) {
        self.auth = auth
        self.store = store
    }

    // MARK: - Entitlement

    /// Applies the cached grant for the signed-in account, then confirms it
    /// with the server. Signed out, comp access is cleared.
    func refresh() async {
        guard let userID = auth.user?.id else {
            store.applyComp(nil)
            return
        }
        store.applyComp(cached(for: userID))

        guard let token = await auth.validAccessToken(),
              let request = makeRequest(path: "v1/entitlement", method: "GET", token: token) else { return }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let body = try JSONDecoder().decode(EntitlementResponse.self, from: data)
            apply(body.entitlement?.entitlement(userID: userID), userID: userID)
        } catch {
            // Offline or server hiccup: keep the cached grant.
            logger.info("Comp entitlement check skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    func signedOut() {
        store.applyComp(nil)
    }

    // MARK: - Redeem

    enum RedeemResult: Equatable {
        case success(String)
        case failure(String)

        var message: String {
            switch self {
            case .success(let text), .failure(let text): return text
            }
        }

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    func redeem(code rawCode: String) async -> RedeemResult {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return .failure("Enter a code first.") }
        guard let userID = auth.user?.id else {
            return .failure("Sign in to Paddle Up Cloud to redeem a friend code.")
        }
        guard let token = await auth.validAccessToken(),
              let request = makeRequest(path: "v1/redeem-code", method: "POST", token: token,
                                        body: ["code": code]) else {
            return .failure(baseURL == nil
                            ? "Code redemption isn't available in this build."
                            : "Your sign-in expired. Sign in again to redeem.")
        }

        isRedeeming = true
        defer { isRedeeming = false }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200, let body = try? JSONDecoder().decode(RedeemResponse.self, from: data),
               let entitlement = body.entitlement?.entitlement(userID: userID) {
                apply(entitlement, userID: userID)
                return .success(entitlement.kind == .lifetime
                                ? "Code applied — enjoy Paddle Up Pro for life!"
                                : "Code applied — enjoy a free month!")
            }
            let errorCode = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
            return .failure(Self.message(for: errorCode, status: status))
        } catch {
            logger.error("Redeem failed: \(error.localizedDescription, privacy: .public)")
            return .failure("Couldn't reach Paddle Up. Check your connection and try again.")
        }
    }

    private static func message(for errorCode: String?, status: Int) -> String {
        switch errorCode {
        case "already_redeemed": return "You've already used this code."
        case "already_lifetime": return "You already have lifetime Paddle Up Pro."
        case "too_many_attempts": return "Too many tries. Please wait an hour and try again."
        case "sign_in_required": return "Your sign-in expired. Sign in again to redeem."
        case "invalid_code", "inactive", "expired", "exhausted": return "That code isn't valid"
        default:
            return status >= 500 ? "Something went wrong on our side. Try again shortly." : "That code isn't valid"
        }
    }

    // MARK: - Cache

    private func apply(_ entitlement: CompEntitlement?, userID: String) {
        if let entitlement, let data = try? JSONEncoder().encode(entitlement),
           let string = String(data: data, encoding: .utf8) {
            KeychainHelper.set(Self.cacheKey, value: string)
        } else {
            KeychainHelper.delete(Self.cacheKey)
        }
        store.applyComp(entitlement)
    }

    private func cached(for userID: String) -> CompEntitlement? {
        guard let string = KeychainHelper.get(Self.cacheKey), let data = string.data(using: .utf8),
              let entitlement = try? JSONDecoder().decode(CompEntitlement.self, from: data),
              entitlement.userID == userID else { return nil }
        return entitlement
    }

    // MARK: - Networking

    private func makeRequest(path: String, method: String, token: String,
                             body: [String: String]? = nil) -> URLRequest? {
        guard let url = baseURL?.appendingPathComponent(path) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONEncoder().encode(body) }
        return request
    }
}

nonisolated private struct EntitlementResponse: Decodable {
    let entitlement: CompEntitlementDTO?
}

nonisolated private struct RedeemResponse: Decodable {
    let entitlement: CompEntitlementDTO?
}

nonisolated private struct ErrorResponse: Decodable {
    let error: String
}
