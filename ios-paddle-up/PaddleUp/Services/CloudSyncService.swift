//
//  CloudSyncService.swift
//  PaddleUp
//
//  Local-first cloud sync. The on-device store is always the source the app
//  reads from; the cloud is a backup that follows it.
//
//  Rules (deliberately simple — no merging, no conflict resolution):
//    • Every local change stamps `AccountData.modifiedAt` and triggers a push.
//    • On sign-in, launch, foreground and network reconnect, the service pulls
//      the cloud snapshot and compares `modifiedAt`:
//        – cloud newer  → replace local with cloud
//        – local newer  → push local to cloud
//    • The server rejects an upload older than what it holds (409), in which
//      case the newer server copy is applied locally.
//
//  Rep video clips never leave the device; only scores, measurements and pose
//  frames sync.
//

import Foundation
import Network
import Observation
import OSLog

@MainActor
@Observable
final class CloudSyncService {
    enum Status: Equatable {
        case signedOut
        case idle
        case syncing
        case offline
        case failed(String)
    }

    private(set) var status: Status = .signedOut
    private(set) var lastSyncedAt: Date?

    private let auth: CloudAuthService
    private weak var appState: AppState?
    private let logger = Logger(subsystem: "app.paddleup", category: "sync")
    private let monitor = NWPathMonitor()
    private var isOnline = true
    private var pushTask: Task<Void, Never>?
    private var isSyncing = false

    private let encoder = PersistenceStore.makeEncoder()
    private let decoder = PersistenceStore.makeDecoder()

    private var baseURL: URL? {
        let raw = Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    init(auth: CloudAuthService) {
        self.auth = auth
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.networkChanged(online: online) }
        }
        monitor.start(queue: DispatchQueue(label: "app.paddleup.sync.network"))
    }

    func attach(_ appState: AppState) {
        self.appState = appState
        appState.onLocalChange = { [weak self] in self?.schedulePush() }
    }

    private func networkChanged(online: Bool) {
        let cameBack = online && !isOnline
        isOnline = online
        if !online, auth.isSignedIn { status = .offline }
        if cameBack { Task { await syncNow() } }
    }

    // MARK: - Public entry points

    /// Pull-compare-push. Safe to call any time; no-ops when signed out.
    func syncNow() async {
        guard auth.isSignedIn else {
            status = .signedOut
            return
        }
        guard isOnline else {
            status = .offline
            return
        }
        guard !isSyncing, let appState, appState.currentAccountID != nil else { return }
        isSyncing = true
        status = .syncing
        defer { isSyncing = false }

        do {
            let remote = try await fetchRemote()
            let local = appState.data
            if let remote, remote.modifiedAt > local.modifiedAt {
                appState.applyRemote(remote)
                logger.info("Applied newer cloud snapshot.")
            } else if remote == nil || local.modifiedAt > (remote?.modifiedAt ?? .distantPast) {
                try await push(local)
            }
            lastSyncedAt = .now
            status = .idle
        } catch SyncError.signedOut {
            status = .signedOut
        } catch {
            logger.error("Sync failed: \(error.localizedDescription, privacy: .public)")
            status = isOnline ? .failed("Couldn't reach Paddle Up Cloud. We'll retry automatically.") : .offline
        }
    }

    /// Debounced push after local edits so a burst of reps is one upload.
    func schedulePush() {
        guard auth.isSignedIn else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await self?.pushLatest()
        }
    }

    /// Permanently removes the signed-in player's cloud copy.
    func deleteCloudData() async -> Bool {
        guard let token = await auth.validAccessToken(), let request = makeRequest(method: "DELETE", token: token) else {
            return false
        }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func signedOut() {
        pushTask?.cancel()
        status = .signedOut
        lastSyncedAt = nil
    }

    // MARK: - Transport

    private func pushLatest() async {
        guard let appState, isOnline, auth.isSignedIn, !isSyncing else { return }
        status = .syncing
        do {
            try await push(appState.data)
            lastSyncedAt = .now
            status = .idle
        } catch SyncError.signedOut {
            status = .signedOut
        } catch {
            status = isOnline ? .failed("Couldn't reach Paddle Up Cloud. We'll retry automatically.") : .offline
        }
    }

    private func fetchRemote() async throws -> AccountData? {
        guard let token = await auth.validAccessToken() else { throw SyncError.signedOut }
        guard let request = makeRequest(method: "GET", token: token) else { throw SyncError.notConfigured }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        switch status {
        case 200: return try decodeSnapshot(data)
        case 404: return nil
        case 401: throw SyncError.signedOut
        default: throw SyncError.server(status)
        }
    }

    private func push(_ local: AccountData) async throws {
        guard let token = await auth.validAccessToken() else { throw SyncError.signedOut }
        guard var request = makeRequest(method: "PUT", token: token) else { throw SyncError.notConfigured }
        request.httpBody = try encodeSnapshot(local)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        switch status {
        case 200: return
        case 409:
            // The cloud holds something newer — last write wins, so take it.
            if let stale = try? decoder.decode(StaleResponse.self, from: data), let snapshot = stale.snapshot {
                appState?.applyRemote(snapshot.accountData())
            }
        case 401: throw SyncError.signedOut
        default: throw SyncError.server(status)
        }
    }

    private func makeRequest(method: String, token: String) -> URLRequest? {
        guard let url = baseURL?.appendingPathComponent("v1/account") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("ios", forHTTPHeaderField: "X-PaddleUp-Platform")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    // MARK: - Snapshot coding
    // The wire snapshot carries AccountData's own field names; modifiedAt is
    // sent as epoch milliseconds so the server can compare it numerically.

    private func encodeSnapshot(_ data: AccountData) throws -> Data {
        let payload = try encoder.encode(data)
        guard var object = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw SyncError.encoding
        }
        object.removeValue(forKey: "modifiedAt")
        object.removeValue(forKey: "schemaVersion")
        let envelope: [String: Any] = [
            "modifiedAt": Int((data.modifiedAt.timeIntervalSince1970 * 1000).rounded()),
            "schemaVersion": data.schemaVersion,
            "data": object
        ]
        return try JSONSerialization.data(withJSONObject: envelope)
    }

    private func decodeSnapshot(_ raw: Data) throws -> AccountData {
        try decoder.decode(RemoteSnapshot.self, from: raw).accountData()
    }
}

nonisolated private struct RemoteSnapshot: Decodable {
    let modifiedAt: Double
    let schemaVersion: Int?
    let data: AccountData

    func accountData() -> AccountData {
        var result = data
        result.modifiedAt = Date(timeIntervalSince1970: modifiedAt / 1000)
        result.schemaVersion = schemaVersion ?? result.schemaVersion
        return result
    }
}

nonisolated private struct StaleResponse: Decodable {
    let snapshot: RemoteSnapshot?
}

nonisolated enum SyncError: LocalizedError {
    case signedOut, notConfigured, encoding
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .signedOut: return "Signed out."
        case .notConfigured: return "Cloud sync isn't configured for this build."
        case .encoding: return "Couldn't prepare your data for upload."
        case .server(let code): return "Cloud error (\(code))."
        }
    }
}
