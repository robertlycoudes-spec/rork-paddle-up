//
//  PersistenceStoreTests.swift
//  PaddleUpTests
//
//  Read/write/migration against a real file store in a throwaway directory.
//

import Foundation
import Testing
@testable import PaddleUp

struct PersistenceStoreTests {
    let root: URL
    let store: PersistenceStore

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaddleUpTests-\(UUID().uuidString)", isDirectory: true)
        store = PersistenceStore(rootDirectory: root)
    }

    private let fixedDate = Date(timeIntervalSince1970: 1_790_000_000)

    private func sampleData() -> AccountData {
        var data = AccountData()
        data.profile.displayName = "Jordan"
        data.profile.duprRange = .upperIntermediate
        data.profile.handedness = .left
        data.profile.goals = [.dinking, .thirdShotDrops]
        // ISO-8601 on disk stores whole seconds, so fixtures use a whole-second date.
        data.profile.createdAt = fixedDate
        data.settings.shareAnonymizedData = true
        data.settings.voiceCoaching = .frequent
        data.modifiedAt = fixedDate

        let sessionID = UUID()
        var rep = RepRecord(sessionID: sessionID, index: 1, timestamp: fixedDate, shot: .forehandDink,
                            score: 82, mechanics: [
                                MechanicScore(mechanic: .kneeBend, score: 90, rawValue: 132, unit: "°", confidence: 0.9)
                            ],
                            correction: "Stay low", nextRepCue: "STAY LOW", confidence: 0.85)
        rep.sharedForResearch = true
        var session = SessionRecord(startedAt: fixedDate, shot: .forehandDink, mode: .freePractice)
        session.id = sessionID
        session.endedAt = fixedDate.addingTimeInterval(600)
        session.reps = [rep]
        session.sharedForResearch = true
        data.sessions = [session]
        data.mechanicHistory = [MechanicHistoryPoint(date: fixedDate, shot: .forehandDink, mechanic: .kneeBend, score: 90)]
        return data
    }

    // MARK: - Read / write

    @Test func missingAccountLoadsNil() {
        #expect(store.load(accountID: "nobody") == nil)
    }

    @Test func saveThenLoadRoundTripsEveryField() throws {
        let original = sampleData()
        store.save(original, accountID: "a1")

        let loaded = try #require(store.load(accountID: "a1"))
        #expect(loaded.profile == original.profile)
        #expect(loaded.settings == original.settings)
        #expect(loaded.sessions == original.sessions)
        #expect(loaded.mechanicHistory == original.mechanicHistory)
        #expect(loaded.modifiedAt == fixedDate)
        #expect(loaded.schemaVersion == AccountData.currentSchemaVersion)
    }

    @Test func consentFlagsAndSettingPersist() throws {
        store.save(sampleData(), accountID: "a2")
        let loaded = try #require(store.load(accountID: "a2"))
        #expect(loaded.settings.shareAnonymizedData)
        #expect(loaded.sessions.first?.sharedForResearch == true)
        #expect(loaded.sessions.first?.reps.first?.sharedForResearch == true)
    }

    @Test func reservedBallAndPaddleFieldsDefaultToNilAndRoundTrip() throws {
        var data = sampleData()
        #expect(data.sessions[0].reps[0].ballSpeedMPH == nil)
        #expect(data.sessions[0].reps[0].spinRPM == nil)
        #expect(data.sessions[0].reps[0].paddleFaceAngleDegrees == nil)
        #expect(data.sessions[0].reps[0].contactTimingPrecisionMS == nil)

        data.sessions[0].reps[0].ballSpeedMPH = 21.5
        data.sessions[0].reps[0].spinRPM = 900
        data.sessions[0].reps[0].paddleFaceAngleDegrees = 12
        data.sessions[0].reps[0].contactTimingPrecisionMS = 8
        store.save(data, accountID: "a3")

        let rep = try #require(store.load(accountID: "a3")?.sessions.first?.reps.first)
        #expect(rep.ballSpeedMPH == 21.5)
        #expect(rep.spinRPM == 900)
        #expect(rep.paddleFaceAngleDegrees == 12)
        #expect(rep.contactTimingPrecisionMS == 8)
    }

    @Test func accountsAreIsolated() throws {
        var other = AccountData()
        other.profile.displayName = "Other"
        store.save(sampleData(), accountID: "a")
        store.save(other, accountID: "b")
        #expect(store.load(accountID: "a")?.profile.displayName == "Jordan")
        #expect(store.load(accountID: "b")?.profile.displayName == "Other")
    }

    @Test func deleteAccountRemovesItsData() {
        store.save(sampleData(), accountID: "gone")
        store.deleteAccount(accountID: "gone")
        #expect(store.load(accountID: "gone") == nil)
    }

    @Test func unreadableFileLoadsNilAndIsBackedUpNotOverwritten() throws {
        let url = store.dataURL(for: "broken")
        try Data("{ not json".utf8).write(to: url)

        #expect(store.load(accountID: "broken") == nil)
        let backup = url.deletingPathExtension().appendingPathExtension("unreadable.json")
        #expect(FileManager.default.fileExists(atPath: backup.path))
        #expect(try String(contentsOf: backup, encoding: .utf8) == "{ not json")
    }

    // MARK: - Migration

    /// A file exactly as schema v1 wrote it: five-step skill level, retired
    /// onboarding fields, and reps without reserved fields or consent flags.
    private let v1JSON = """
    {
      "schemaVersion": 1,
      "profile": {
        "displayName": "Sam", "email": "", "skillLevel": "advanced", "handedness": "left",
        "playerTypes": ["aggressive"], "goals": ["dinking"], "struggles": ["thirdShot"],
        "weaknesses": ["serve"], "trainingTime": "serious", "motivation": "fun",
        "competitiveness": "league", "successMetric": "consistency", "frequency": "weekly",
        "heightCentimetres": 180, "hasCompletedOnboarding": true,
        "hasCompletedBaselineAssessment": false, "createdAt": "2026-08-01T00:00:00Z"
      },
      "settings": {
        "voiceCoaching": "frequent", "hapticFeedback": false, "saveRepClips": true,
        "clipRetentionDays": 7, "developerModeEnabled": false, "analyticsEnabled": true,
        "defaultSessionLength": "fiveMinutes"
      },
      "sessions": [{
        "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF",
        "startedAt": "2026-09-01T10:00:00Z", "endedAt": "2026-09-01T10:10:00Z",
        "shot": "forehandDink", "mode": "freePractice",
        "reps": [{
          "id": "7F9619FF-8B86-D011-B42D-00C04FC964FF",
          "sessionID": "6F9619FF-8B86-D011-B42D-00C04FC964FF",
          "index": 1, "timestamp": "2026-09-01T10:01:00Z", "shot": "forehandDink", "score": 72,
          "mechanics": [{"mechanic": "kneeBend", "score": 80, "rawValue": 130, "unit": "°", "confidence": 0.9}],
          "correction": "Bend more", "nextRepCue": "STAY LOW", "confidence": 0.8,
          "isDeleted": false, "wasReclassified": false, "poseFrames": [],
          "rubricVersion": 1, "benchmarkVersion": "v1-heuristic-2026.09"
        }]
      }],
      "mechanicHistory": [], "achievements": [], "feedback": []
    }
    """

    @Test func v1FileMigratesToCurrentSchema() throws {
        try Data(v1JSON.utf8).write(to: store.dataURL(for: "legacy"))

        let loaded = try #require(store.load(accountID: "legacy"))
        #expect(loaded.schemaVersion == 2)
        // v1 never synced, so it must not look newer than any cloud copy.
        #expect(loaded.modifiedAt == .distantPast)
        #expect(loaded.settings.shareAnonymizedData == false)
        #expect(loaded.settings.voiceCoaching == .frequent)
        #expect(loaded.settings.clipRetentionDays == 7)
    }

    @Test func v1ProfileKeepsAnswersAndMapsLevelToDuprRange() throws {
        try Data(v1JSON.utf8).write(to: store.dataURL(for: "legacy"))
        let profile = try #require(store.load(accountID: "legacy")?.profile)
        #expect(profile.displayName == "Sam")
        #expect(profile.duprRange == .upperIntermediate)
        #expect(profile.handedness == .left)
        #expect(profile.playerTypes == [.aggressive])
        #expect(profile.struggles == [.thirdShot])
        #expect(profile.successMetric == .consistency)
        #expect(profile.hasCompletedOnboarding)
    }

    @Test func v1RepsKeepScoresAndGainEmptyReservedFields() throws {
        try Data(v1JSON.utf8).write(to: store.dataURL(for: "legacy"))
        let session = try #require(store.load(accountID: "legacy")?.sessions.first)
        let rep = try #require(session.reps.first)
        #expect(rep.score == 72)
        #expect(rep.mechanics.first?.rawValue == 130)
        #expect(rep.ballSpeedMPH == nil)
        #expect(rep.spinRPM == nil)
        #expect(rep.paddleFaceAngleDegrees == nil)
        #expect(rep.contactTimingPrecisionMS == nil)
        #expect(rep.sharedForResearch == false)
        #expect(session.sharedForResearch == false)
    }

    @Test func migratedFileRewritesWithoutRetiredFields() throws {
        try Data(v1JSON.utf8).write(to: store.dataURL(for: "legacy"))
        let loaded = try #require(store.load(accountID: "legacy"))
        store.save(loaded, accountID: "legacy")

        let raw = try String(contentsOf: store.dataURL(for: "legacy"), encoding: .utf8)
        #expect(raw.contains("\"duprRange\":\"upperIntermediate\""))
        #expect(!raw.contains("weaknesses"))
        #expect(!raw.contains("competitiveness"))
        #expect(!raw.contains("\"motivation\""))
        #expect(!raw.contains("skillLevel"))
    }

    @Test(arguments: [
        ("justStarting", DuprRange.beginner),
        ("beginner", .beginner),
        ("intermediate", .intermediate),
        ("advanced", .upperIntermediate),
        ("competitive", .advanced)
    ])
    func legacySkillLevelMapping(raw: String, expected: DuprRange) {
        #expect(DuprRange.migrating(legacySkillLevel: raw) == expected)
    }

    @Test func unknownLegacyLevelLeavesRangeUnset() {
        #expect(DuprRange.migrating(legacySkillLevel: "wizard") == nil)
    }
}
