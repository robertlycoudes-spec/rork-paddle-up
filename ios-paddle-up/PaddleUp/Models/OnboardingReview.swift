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
    let title: String
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

    static let eyebrow = "TRUSTED ON COURT"
    static let averageRating = "4.9"
    static let ratingCount = "1K+"
    static let ratingCaption = "Average from 1K+ player ratings"

    static let reviews: [OnboardingReview] = [
        OnboardingReview(
            id: "review-1", name: "Conner Wilson", imageName: "review-1",
            title: "My dinks finally stay low",
            quote: "Six weeks of daily reps and my dinks finally stay low. My partners keep asking who's coaching me."
        ),
        OnboardingReview(
            id: "review-2", name: "Chris Aureliano", imageName: "review-2",
            title: "One fix at a time works",
            quote: "One fix per session is genius. I stopped overthinking and my third-shot drop actually lands in the kitchen now."
        ),
        OnboardingReview(
            id: "review-3", name: "Andre Dean", imageName: "review-3",
            title: "A score on every rep",
            quote: "I set my phone on the fence, hit 50 reps, and get a score on every single one. Nothing else does that."
        ),
        OnboardingReview(
            id: "review-4", name: "Tucker Tralson", imageName: "review-4",
            title: "3.2 to 3.6 in one season",
            quote: "Went from 3.2 to 3.6 this season. The weekly plan keeps me honest about the shots I used to avoid."
        ),
        OnboardingReview(
            id: "review-5", name: "George Murduck", imageName: "review-5",
            title: "Like a pro on my shoulder",
            quote: "The voice coach between reps feels like having a pro standing next to me. Worth every minute."
        ),
        OnboardingReview(
            id: "review-6", name: "Caleb Plummer", imageName: "review-6",
            title: "Perfect for busy weeks",
            quote: "I only have 20 minutes after work. The daily drill tells me exactly what to hit, so none of it is wasted."
        )
    ]
}
