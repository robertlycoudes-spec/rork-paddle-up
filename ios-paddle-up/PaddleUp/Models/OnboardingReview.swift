//
//  OnboardingReview.swift
//  PaddleUp
//
//  Player testimonials shown on the onboarding social-proof screen.
//  Photos live in Assets.xcassets under `imageName`; when a photo is missing
//  the card falls back to an initials avatar so the screen never breaks.
//

import Foundation

nonisolated struct OnboardingReview: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let imageName: String
    let quote: String
    var rating: Int = 5

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

/// Everything shown on the reviews screen, kept in one place so copy, stats
/// and players can be updated without touching layout code.
nonisolated enum OnboardingSocialProof {
    static let headline = "Join thousands of players training with Paddle Up"

    static let ratingValue = "1K+"
    static let ratingLabel = "App ratings"
    static let lovedValue = "4.9"
    static let lovedLabel = "Loved by players"

    static let reviews: [OnboardingReview] = [
        OnboardingReview(
            id: "review-1", name: "Player One", imageName: "review-1",
            quote: "Six weeks of daily reps and my dinks finally stay low. My partners keep asking who's coaching me."
        ),
        OnboardingReview(
            id: "review-2", name: "Player Two", imageName: "review-2",
            quote: "One fix per session is genius. I stopped overthinking and my third-shot drop actually lands in the kitchen now."
        ),
        OnboardingReview(
            id: "review-3", name: "Player Three", imageName: "review-3",
            quote: "I set my phone on the fence, hit 50 reps, and get a score on every single one. Nothing else does that."
        ),
        OnboardingReview(
            id: "review-4", name: "Player Four", imageName: "review-4",
            quote: "Went from 3.2 to 3.6 this season. The weekly plan keeps me honest about the shots I used to avoid."
        ),
        OnboardingReview(
            id: "review-5", name: "Player Five", imageName: "review-5",
            quote: "The voice coach between reps feels like having a pro standing next to me. Worth every minute."
        ),
        OnboardingReview(
            id: "review-6", name: "Player Six", imageName: "review-6",
            quote: "I only have 20 minutes after work. The daily drill tells me exactly what to hit, so none of it is wasted."
        )
    ]
}
