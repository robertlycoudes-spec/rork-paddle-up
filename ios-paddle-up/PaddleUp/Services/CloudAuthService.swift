//
//  CloudAuthService.swift
//  PaddleUp
//
//  Optional cloud account via Rork Auth (Sign in with Apple / Google). The app
//  stays fully usable signed out on its implicit on-device account; signing in
//  only turns on cloud backup & sync.
//

import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class CloudAuthService {
    nonisolated struct User: Codable, Sendable, Equatable {
        let id: String
        let email: String
        let name: String?
        let picture: String?
    }

    private(set) var user: User?
    private(set) var isLoading = true
    private(set) var isSigningIn = false
    var errorMessage: String?

    var isSignedIn: Bool { user != nil }

    private let authURL = Config.EXPO_PUBLIC_RORK_AUTH_URL
    private let appKey = Config.EXPO_PUBLIC_RORK_APP_KEY
    private let projectID = Config.EXPO_PUBLIC_PROJECT_ID
    private var codeVerifier: String?
    private var webAuthSession: ASWebAuthenticationSession?

    /// Injected by Rork into UserDefaults on its managed simulator only; read
    /// on every access because it can arrive after launch.
    private var developerHint: String? {
        UserDefaults.standard.string(forKey: "RORK_DEVELOPER_HINT")
    }

    private var authEnv: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "native"
        #endif
    }

    // MARK: - Session

    /// Restores a stored session, refreshing the access token if it expired.
    func checkAuth() async {
        defer { isLoading = false }
        if let token = KeychainHelper.get("access_token"), let decoded = Self.userFromToken(token) {
            user = decoded
            return
        }
        if refreshTokenValue() != nil { await refreshAccessToken() }
    }

    /// A non-expired access token, refreshing first when needed. Nil when
    /// signed out or the session can no longer be refreshed.
    func validAccessToken() async -> String? {
        if let token = KeychainHelper.get("access_token"), Self.userFromToken(token) != nil {
            return token
        }
        guard refreshTokenValue() != nil else { return nil }
        await refreshAccessToken()
        return KeychainHelper.get("access_token")
    }

    func signIn(provider: String) async {
        guard !authURL.isEmpty, !appKey.isEmpty else {
            errorMessage = "Sign-in isn't configured for this build."
            return
        }
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }
        do {
            let verifier = Self.generateCodeVerifier()
            codeVerifier = verifier

            guard let url = URL(string: "\(authURL)/oauth/initiate") else { throw CloudAuthError.invalidURL }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var body: [String: String] = [
                "app_key": appKey,
                "provider": provider,
                "code_challenge": Self.codeChallenge(from: verifier),
                "target": "swift",
                "env": authEnv
            ]
            if authEnv == "simulator", let hint = developerHint { body["developer_hint"] = hint }
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
                throw CloudAuthError.server(message ?? "Sign-in failed.")
            }
            let initiate = try JSONDecoder().decode(InitiateResponse.self, from: data)

            let code: String
            if initiate.flow == "popup" {
                do {
                    code = try await pollForCode(state: initiate.state)
                } catch CloudAuthError.cancelledByUser {
                    code = try await runWebAuthSession(authURL: initiate.auth_url)
                }
            } else {
                code = try await runWebAuthSession(authURL: initiate.auth_url)
            }
            try await exchangeCode(code)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch let error as CloudAuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Sign-in failed. Check your connection and try again."
        }
    }

    func signOut() {
        KeychainHelper.delete("access_token")
        KeychainHelper.delete("refresh_token")
        UserDefaults.standard.removeObject(forKey: "RORK_AUTH_REFRESH_TOKEN")
        user = nil
    }

    // MARK: - OAuth plumbing

    private func pollForCode(state: String) async throws -> String {
        guard let url = URL(string: "\(authURL)/oauth/poll-code") else { throw CloudAuthError.invalidURL }
        let deadline = Date().addingTimeInterval(5 * 60)
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(1500))
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["app_key": appKey, "state": state])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let poll = try? JSONDecoder().decode(PollCodeResponse.self, from: data) else { continue }
            if poll.status == "cancelled" { throw CloudAuthError.cancelledByUser }
            if poll.status == "ready", let code = poll.code { return code }
        }
        throw CloudAuthError.popupTimeout
    }

    private func runWebAuthSession(authURL authURLString: String) async throws -> String {
        let callbackScheme = "rork-\(projectID)"
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            guard let url = URL(string: authURLString) else {
                continuation.resume(throwing: CloudAuthError.invalidURL)
                return
            }
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
                Task { @MainActor in self?.webAuthSession = nil }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: CloudAuthError.noCode)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = WebAuthPresentationContext.shared
            session.prefersEphemeralWebBrowserSession = false
            webAuthSession = session
            session.start()
        }
    }

    private func exchangeCode(_ code: String) async throws {
        guard let verifier = codeVerifier else { throw CloudAuthError.noCode }
        codeVerifier = nil
        guard let url = URL(string: "\(authURL)/oauth/token") else { throw CloudAuthError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["app_key": appKey, "code": code, "code_verifier": verifier])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
            throw CloudAuthError.server(message ?? "Sign-in failed.")
        }
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        KeychainHelper.set("access_token", value: tokens.access_token)
        KeychainHelper.set("refresh_token", value: tokens.refresh_token)
        user = tokens.user
    }

    private func refreshTokenValue() -> String? {
        #if targetEnvironment(simulator)
        if let injected = UserDefaults.standard.string(forKey: "RORK_AUTH_REFRESH_TOKEN") { return injected }
        #endif
        return KeychainHelper.get("refresh_token")
    }

    private func refreshAccessToken() async {
        guard let refreshToken = refreshTokenValue(),
              let url = URL(string: "\(authURL)/oauth/refresh") else {
            user = nil
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["app_key": appKey, "refresh_token": refreshToken])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if status == 401 || status == 400 {
                signOut()
                return
            }
            guard status == 200 else { return } // transient — keep the session for a later retry
            let refreshed = try JSONDecoder().decode(RefreshResponse.self, from: data)
            KeychainHelper.set("access_token", value: refreshed.access_token)
            user = Self.userFromToken(refreshed.access_token) ?? user
        } catch {
            // Offline: keep the signed-in state; sync retries on reconnect.
        }
    }

    // MARK: - Helpers

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func codeChallenge(from verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decodes the JWT payload for user info and expiry. The signature was
    /// verified by Rork when issued; the backend re-verifies on every request.
    private static func userFromToken(_ token: String) -> User? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONDecoder().decode(JWTPayload.self, from: data) else { return nil }
        if let exp = payload.exp, Date(timeIntervalSince1970: exp) < Date().addingTimeInterval(30) { return nil }
        return User(id: payload.sub, email: payload.email ?? "", name: payload.name, picture: payload.picture)
    }
}

// MARK: - Wire types

nonisolated private struct JWTPayload: Codable {
    let sub: String
    let email: String?
    let name: String?
    let picture: String?
    let exp: TimeInterval?
}

nonisolated private struct InitiateResponse: Codable {
    let auth_url: String
    let state: String
    let flow: String?
}

nonisolated private struct PollCodeResponse: Codable {
    let status: String
    let code: String?
}

nonisolated private struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let user: CloudAuthService.User
}

nonisolated private struct RefreshResponse: Codable {
    let access_token: String
}

nonisolated private struct ErrorResponse: Codable {
    let error: String
}

nonisolated enum CloudAuthError: LocalizedError {
    case noCode, invalidURL, popupTimeout, cancelledByUser
    case server(String)

    var errorDescription: String? {
        switch self {
        case .noCode: return "No authorization code was received. Please try again."
        case .invalidURL: return "Sign-in isn't configured correctly."
        case .popupTimeout: return "Sign-in timed out — please try again."
        case .cancelledByUser: return "Sign-in was cancelled."
        case .server(let message): return message
        }
    }
}

final class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
