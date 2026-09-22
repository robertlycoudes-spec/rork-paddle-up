//
//  Haptics.swift
//  PaddleUp
//

import UIKit

@MainActor
enum Haptics {
    static var enabled = true

    static func repDetected(score: Double) {
        guard enabled else { return }
        let generator = UIImpactFeedbackGenerator(style: score >= 80 ? .medium : .light)
        generator.impactOccurred(intensity: score >= 80 ? 0.9 : 0.6)
    }

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
