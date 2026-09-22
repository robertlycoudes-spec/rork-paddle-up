//
//  VoiceCoach.swift
//  PaddleUp
//
//  Optional real-time spoken coaching. Deliberately sparse: it respects the
//  player's frequency setting and never speaks over itself.
//

import AVFoundation
import Foundation

@MainActor
final class VoiceCoach {
    private let synthesizer = AVSpeechSynthesizer()
    private var repsSinceLastCue = 0
    private var lastSpokenCue: String?

    var level: VoiceCoachingLevel = .importantOnly

    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        // Duck other audio (music) briefly rather than stopping it.
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true)
    }

    func deactivate() {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Decide whether to speak coaching for a rep, based on the level setting.
    func handle(coaching: RepCoaching, repIndex: Int) {
        guard level != .off else { return }
        repsSinceLastCue += 1

        let shouldSpeak: Bool
        switch level {
        case .off:
            shouldSpeak = false
        case .importantOnly:
            shouldSpeak = coaching.severity == .major && repsSinceLastCue >= level.repInterval
        case .everyFewReps:
            shouldSpeak = repsSinceLastCue >= level.repInterval
        case .frequent:
            shouldSpeak = true
        }

        guard shouldSpeak else { return }
        repsSinceLastCue = 0

        let phrase = spokenPhrase(for: coaching)
        speak(phrase)
    }

    private func spokenPhrase(for coaching: RepCoaching) -> String {
        if coaching.isPraise { return ["Good rep.", "Better.", "That's it.", "Clean."].randomElement()! }
        switch coaching.issue?.mechanic {
        case .kneeBend: return "Stay lower."
        case .contactPosition: return "Contact farther in front."
        case .headStability: return "Keep your head still."
        case .followThrough: return "Finish the swing."
        case .armStructure: return "Hold your arm shape."
        case .softHands: return "Softer hands."
        case .weightTransfer: return "Step through it."
        case .balance: return "Stay balanced."
        default: return "More " + (coaching.issue?.mechanic.displayName.lowercased() ?? "control") + "."
        }
    }

    private func speak(_ text: String) {
        if synthesizer.isSpeaking { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.9
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
        lastSpokenCue = text
    }

    func reset() {
        repsSinceLastCue = 0
        lastSpokenCue = nil
    }
}
