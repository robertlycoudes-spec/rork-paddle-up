//
//  PersistenceStore.swift
//  PaddleUp
//
//  Local-first persistence. Everything the player generates — profile,
//  sessions, reps, mechanic history, plans, feedback — is stored on device in
//  the app's Application Support directory, scoped per account.
//
//  The schema mirrors the intended server tables (User, PlayerProfile, Session,
//  Rep, MechanicScore, Drill, Recommendation, PracticePlan, ProgressMetric,
//  Achievement, UserFeedback) so a backend sync layer can be added without
//  reshaping the client's data model.
//

import Foundation
import OSLog

/// The complete persisted state for one account.
nonisolated struct AccountData: Codable, Sendable {
    var profile: PlayerProfile = PlayerProfile()
    var sessions: [SessionRecord] = []
    var mechanicHistory: [MechanicHistoryPoint] = []
    var achievements: [Achievement] = []
    var feedback: [UserFeedbackRecord] = []
    var plan: WeeklyPlan?
    var settings: AppSettings = AppSettings()
    var schemaVersion: Int = 1
}

nonisolated struct AppSettings: Codable, Sendable, Equatable {
    var voiceCoaching: VoiceCoachingLevel = .importantOnly
    var hapticFeedback: Bool = true
    var saveRepClips: Bool = true
    /// Days after which clips are purged automatically.
    var clipRetentionDays: Int = 14
    var developerModeEnabled: Bool = false
    var analyticsEnabled: Bool = true
    var defaultSessionLength: SessionLength = .tenMinutes
}

nonisolated enum VoiceCoachingLevel: String, Codable, CaseIterable, Sendable, Identifiable {
    case off, importantOnly, everyFewReps, frequent
    nonisolated var id: String { rawValue }
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .importantOnly: return "Important corrections only"
        case .everyFewReps: return "Every few reps"
        case .frequent: return "Frequent"
        }
    }
    /// How many reps must pass before speaking again.
    var repInterval: Int {
        switch self {
        case .off: return .max
        case .importantOnly: return 4
        case .everyFewReps: return 3
        case .frequent: return 1
        }
    }
}

nonisolated enum SessionLength: String, Codable, CaseIterable, Sendable, Identifiable {
    case fiveMinutes, tenMinutes, fifteenMinutes, thirtyMinutes, unlimited
    nonisolated var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fiveMinutes: return "5 min"
        case .tenMinutes: return "10 min"
        case .fifteenMinutes: return "15 min"
        case .thirtyMinutes: return "30 min"
        case .unlimited: return "Manual"
        }
    }
    var seconds: TimeInterval? {
        switch self {
        case .fiveMinutes: return 300
        case .tenMinutes: return 600
        case .fifteenMinutes: return 900
        case .thirtyMinutes: return 1800
        case .unlimited: return nil
        }
    }
}

/// A personalised weekly practice plan.
nonisolated struct WeeklyPlan: Codable, Sendable, Equatable {
    nonisolated struct Entry: Codable, Sendable, Identifiable, Equatable {
        var id: UUID = UUID()
        /// 1 = Sunday, matching `Calendar.component(.weekday:)`.
        var weekday: Int
        var shot: ShotType
        var mechanic: MechanicID
        var drillID: String
        var isAssessment: Bool = false
        var completedAt: Date?

        var weekdayName: String {
            let symbols = Calendar.current.weekdaySymbols
            return symbols[safe: weekday - 1] ?? "Day"
        }
    }

    var generatedAt: Date
    var entries: [Entry]
    /// Explains why this plan was built the way it was.
    var rationale: String
}

/// File-backed JSON store. Writes are debounced by the caller (AppState).
final class PersistenceStore: @unchecked Sendable {
    private let logger = Logger(subsystem: "app.paddleup", category: "persistence")
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var rootDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent("PaddleUp", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func dataURL(for accountID: String) -> URL {
        rootDirectory.appendingPathComponent("account-\(accountID).json")
    }

    func clipsDirectory(for accountID: String) -> URL {
        let directory = rootDirectory.appendingPathComponent("clips-\(accountID)", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    func load(accountID: String) -> AccountData? {
        let url = dataURL(for: accountID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try decoder.decode(AccountData.self, from: data)
        } catch {
            logger.error("Failed to decode account data; starting fresh.")
            return nil
        }
    }

    func save(_ accountData: AccountData, accountID: String) {
        do {
            let data = try encoder.encode(accountData)
            try data.write(to: dataURL(for: accountID), options: .atomic)
        } catch {
            logger.error("Failed to persist account data.")
        }
    }

    func deleteAccount(accountID: String) {
        try? fileManager.removeItem(at: dataURL(for: accountID))
        try? fileManager.removeItem(at: clipsDirectory(for: accountID))
    }

    /// Total bytes used by saved rep clips.
    func clipStorageBytes(accountID: String) -> Int64 {
        let directory = clipsDirectory(for: accountID)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return contents.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }

    func deleteAllClips(accountID: String) {
        let directory = clipsDirectory(for: accountID)
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for url in contents { try? fileManager.removeItem(at: url) }
    }

    func deleteClip(named filename: String, accountID: String) {
        try? fileManager.removeItem(at: clipsDirectory(for: accountID).appendingPathComponent(filename))
    }

    /// Remove clips older than the retention window.
    func purgeExpiredClips(accountID: String, retentionDays: Int) {
        guard retentionDays > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86_400)
        let directory = clipsDirectory(for: accountID)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        for url in contents {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            if let modified, modified < cutoff { try? fileManager.removeItem(at: url) }
        }
    }
}
