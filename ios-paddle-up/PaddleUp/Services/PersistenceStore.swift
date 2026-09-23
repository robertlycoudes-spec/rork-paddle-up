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
    /// Current on-disk schema. v2 introduced DUPR ranges, reserved ball/paddle
    /// rep fields, consent flags and `modifiedAt` for cloud sync.
    static let currentSchemaVersion = 2

    var profile: PlayerProfile = PlayerProfile()
    var sessions: [SessionRecord] = []
    var mechanicHistory: [MechanicHistoryPoint] = []
    var achievements: [Achievement] = []
    var feedback: [UserFeedbackRecord] = []
    var plan: WeeklyPlan?
    var settings: AppSettings = AppSettings()
    var schemaVersion: Int = AccountData.currentSchemaVersion
    /// When this data last changed locally. Cloud sync is last-write-wins on
    /// this timestamp — no merging.
    var modifiedAt: Date = .distantPast

    init() {}

    nonisolated enum CodingKeys: String, CodingKey {
        case profile, sessions, mechanicHistory, achievements, feedback, plan, settings
        case schemaVersion, modifiedAt
    }

    /// Tolerant decoding: every field falls back to its default, so data saved
    /// by any earlier schema still opens instead of being discarded.
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decodeIfPresent(PlayerProfile.self, forKey: .profile) ?? PlayerProfile()
        sessions = try container.decodeIfPresent([SessionRecord].self, forKey: .sessions) ?? []
        mechanicHistory = try container.decodeIfPresent([MechanicHistoryPoint].self, forKey: .mechanicHistory) ?? []
        achievements = try container.decodeIfPresent([Achievement].self, forKey: .achievements) ?? []
        feedback = try container.decodeIfPresent([UserFeedbackRecord].self, forKey: .feedback) ?? []
        plan = try? container.decodeIfPresent(WeeklyPlan.self, forKey: .plan)
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
    }
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
    /// Opt-in (default OFF) to share anonymized rep/session data to help
    /// improve scoring. Today this only flags new records; no data is sent.
    var shareAnonymizedData: Bool = false

    init() {}

    nonisolated enum CodingKeys: String, CodingKey {
        case voiceCoaching, hapticFeedback, saveRepClips, clipRetentionDays
        case developerModeEnabled, analyticsEnabled, defaultSessionLength, shareAnonymizedData
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        voiceCoaching = (try? container.decodeIfPresent(VoiceCoachingLevel.self, forKey: .voiceCoaching))
            ?? defaults.voiceCoaching
        hapticFeedback = try container.decodeIfPresent(Bool.self, forKey: .hapticFeedback) ?? defaults.hapticFeedback
        saveRepClips = try container.decodeIfPresent(Bool.self, forKey: .saveRepClips) ?? defaults.saveRepClips
        clipRetentionDays = try container.decodeIfPresent(Int.self, forKey: .clipRetentionDays) ?? defaults.clipRetentionDays
        developerModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .developerModeEnabled) ?? defaults.developerModeEnabled
        analyticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .analyticsEnabled) ?? defaults.analyticsEnabled
        defaultSessionLength = (try? container.decodeIfPresent(SessionLength.self, forKey: .defaultSessionLength))
            ?? defaults.defaultSessionLength
        shareAnonymizedData = try container.decodeIfPresent(Bool.self, forKey: .shareAnonymizedData) ?? false
    }
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
nonisolated final class PersistenceStore: @unchecked Sendable {
    private let logger = Logger(subsystem: "app.paddleup", category: "persistence")
    private let fileManager = FileManager.default
    private let customRoot: URL?

    /// Shared JSON coding used on disk and for cloud sync, so both paths read
    /// and write exactly the same field names.
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private let encoder = PersistenceStore.makeEncoder()
    private let decoder = PersistenceStore.makeDecoder()

    /// - Parameter rootDirectory: Override for the storage folder (tests use a
    ///   temporary directory). Defaults to Application Support/PaddleUp.
    init(rootDirectory: URL? = nil) {
        self.customRoot = rootDirectory
    }

    private var rootDirectory: URL {
        let directory: URL
        if let customRoot {
            directory = customRoot
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            directory = base.appendingPathComponent("PaddleUp", isDirectory: true)
        }
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    func dataURL(for accountID: String) -> URL {
        rootDirectory.appendingPathComponent("account-\(accountID).json")
    }

    /// Brings data saved by an older schema up to the current one. Field-level
    /// changes (e.g. skill level → DUPR range) happen in tolerant decoding; this
    /// step records the upgrade and fills values older schemas never had.
    static func migrate(_ data: AccountData) -> AccountData {
        var migrated = data
        if migrated.schemaVersion < 2 {
            // v1 had no sync timestamp. It stays at `distantPast` so a first
            // sync never lets never-synced local data beat newer cloud data;
            // the next local edit stamps a real time.
            migrated.schemaVersion = 2
        }
        migrated.schemaVersion = max(migrated.schemaVersion, AccountData.currentSchemaVersion)
        return migrated
    }

    /// Decodes raw account JSON and migrates it. Returns nil for unreadable data.
    func decodeAccountData(_ raw: Data) -> AccountData? {
        do {
            return Self.migrate(try decoder.decode(AccountData.self, from: raw))
        } catch {
            logger.error("Failed to decode account data.")
            return nil
        }
    }

    func encodeAccountData(_ accountData: AccountData) -> Data? {
        try? encoder.encode(accountData)
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
        guard let decoded = decodeAccountData(data) else {
            // Keep the unreadable file aside rather than overwriting it, so a
            // decoding bug can never silently destroy a player's history.
            let backup = url.deletingPathExtension().appendingPathExtension("unreadable.json")
            try? fileManager.removeItem(at: backup)
            try? fileManager.copyItem(at: url, to: backup)
            logger.error("Account data unreadable; backed up and starting fresh.")
            return nil
        }
        return decoded
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
