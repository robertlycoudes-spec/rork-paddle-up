//
//  OnboardingReviewsScreen.swift
//  PaddleUp
//
//  Social proof right before the plan is built: an overlapping avatar stack,
//  headline, a two-up ratings card, and scrolling player review cards, with
//  a pinned lime "BUILD MY PLAN" action.
//

import SwiftUI
import UIKit

struct OnboardingReviewsScreen: View {
    let onContinue: () -> Void

    @State private var appeared = false

    private let reviews = OnboardingSocialProof.reviews

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                avatarStack
                    .padding(.top, 36)

                Text(OnboardingSocialProof.headline)
                    .font(.system(size: 29, weight: .heavy))
                    .tracking(-0.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PUColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.3), value: appeared)

                ratingsCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.4), value: appeared)

                VStack(spacing: 14) {
                    ForEach(Array(reviews.enumerated()), id: \.element.id) { index, review in
                        ReviewCard(review: review, starDelay: 0.6 + Double(index) * 0.1)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.55, dampingFraction: 0.85)
                                    .delay(0.5 + Double(min(index, 3)) * 0.08),
                                value: appeared
                            )
                    }
                }
                .padding(.bottom, 110)
            }
            .padding(.horizontal, PUMetrics.margin)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            OnboardingCTA(title: "BUILD MY PLAN") { onContinue() }
                .padding(.horizontal, PUMetrics.margin)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
        }
        .onAppear { appeared = true }
    }

    // MARK: - Avatar stack

    private var avatarStack: some View {
        HStack(spacing: -18) {
            ForEach(Array(reviews.prefix(5).enumerated()), id: \.element.id) { index, review in
                ReviewAvatar(review: review, size: 76, ringWidth: 4)
                    .zIndex(Double(index))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.68).delay(0.05 + Double(index) * 0.06),
                        value: appeared
                    )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Ratings card

    private var ratingsCard: some View {
        HStack(spacing: 0) {
            ratingStat(symbol: "star.fill", tint: PUColor.amber,
                       value: OnboardingSocialProof.ratingValue,
                       label: OnboardingSocialProof.ratingLabel)
            Rectangle()
                .fill(PUColor.hairline)
                .frame(width: 1, height: 52)
            ratingStat(symbol: "heart.fill", tint: PUColor.alert,
                       value: OnboardingSocialProof.lovedValue,
                       label: OnboardingSocialProof.lovedLabel)
        }
        .padding(.vertical, 20)
        .background(PUColor.surface, in: .rect(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(PUColor.hairline, lineWidth: 1))
    }

    private func ratingStat(symbol: String, tint: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tint)
                    .symbolEffect(.bounce, value: appeared)
                Text(value)
                    .font(.system(size: 30, weight: .heavy).monospacedDigit())
                    .foregroundStyle(PUColor.textPrimary)
            }
            Text(label)
                .font(PUFont.body)
                .foregroundStyle(PUColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Review card

private struct ReviewCard: View {
    let review: OnboardingReview
    let starDelay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ReviewAvatar(review: review, size: 58, ringWidth: 3)
                VStack(alignment: .leading, spacing: 5) {
                    Text(review.name)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(PUColor.textPrimary)
                    StarRow(rating: review.rating, delay: starDelay)
                }
                Spacer(minLength: 0)
            }
            Text(review.quote)
                .font(.system(size: 17, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(PUColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PUColor.surface, in: .rect(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(PUColor.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(review.name), \(review.rating) stars. \(review.quote)")
    }
}

/// Five small amber stars that light up one after another.
private struct StarRow: View {
    let rating: Int
    let delay: Double
    @State private var lit = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(index < rating ? PUColor.amber : PUColor.textTertiary)
                    .scaleEffect(lit ? 1 : 0.3)
                    .opacity(lit ? 1 : 0)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.6).delay(delay + Double(index) * 0.05),
                        value: lit
                    )
            }
        }
        .onAppear { lit = true }
    }
}

// MARK: - Avatar

/// Circular player photo with a dark ring; falls back to initials on a raised
/// disc when the photo hasn't been added to the asset catalog yet.
struct ReviewAvatar: View {
    let review: OnboardingReview
    let size: CGFloat
    let ringWidth: CGFloat

    var body: some View {
        ZStack {
            if let photo = UIImage(named: review.imageName) {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(.circle)
            } else {
                Circle()
                    .fill(PUColor.surfaceRaised)
                    .frame(width: size, height: size)
                    .overlay(
                        Text(review.initials)
                            .font(.system(size: size * 0.32, weight: .heavy))
                            .foregroundStyle(PUColor.lime)
                    )
            }
        }
        .padding(ringWidth)
        .background(PUColor.canvasDeep, in: .circle)
    }
}
