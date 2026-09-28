//
//  OnboardingReviewsScreen.swift
//  PaddleUp
//
//  Social proof right before the plan is built. The continue action stays
//  locked until the player has scrolled to the end of the reviews; a slim
//  reading bar in the pinned footer shows how far they've got.
//

import SwiftUI
import UIKit

struct OnboardingReviewsScreen: View {
    let onContinue: () -> Void

    @State private var appeared = false
    @State private var readProgress: Double = 0
    @State private var hasReadAll = false

    private let reviews = OnboardingSocialProof.reviews

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, 28)

                ratingSummary
                    .padding(.top, 26)

                sectionLabel
                    .padding(.top, 34)
                    .padding(.bottom, 14)

                VStack(spacing: 12) {
                    ForEach(Array(reviews.enumerated()), id: \.element.id) { index, review in
                        ReviewCard(review: review)
                            .scrollTransition(.animated(.spring(response: 0.5, dampingFraction: 0.86))) { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0.35)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                    .offset(y: phase.value > 0 ? 18 : 0)
                            }
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .easeOut(duration: 0.5).delay(0.45 + Double(min(index, 2)) * 0.08),
                                value: appeared
                            )
                    }
                }

                endMarker
                    .padding(.top, 22)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, PUMetrics.margin)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Double.self) { geo in
            let scrollable = geo.contentSize.height + geo.contentInsets.top
                + geo.contentInsets.bottom - geo.containerSize.height
            guard scrollable > 1 else { return 1 }
            let travelled = geo.contentOffset.y + geo.contentInsets.top
            return min(1, max(0, travelled / (scrollable - 24)))
        } action: { _, progress in
            if progress > readProgress { readProgress = progress }
            if progress >= 1, !hasReadAll {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { hasReadAll = true }
                Haptics.success()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .onAppear { appeared = true }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 18) {
            avatarStack

            VStack(spacing: 10) {
                Text(OnboardingSocialProof.eyebrow)
                    .font(PUFont.micro)
                    .tracking(1.8)
                    .foregroundStyle(PUColor.lime)

                Text(OnboardingSocialProof.headline)
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(-0.5)
                    .lineSpacing(1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PUColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.spring(response: 0.6, dampingFraction: 0.88).delay(0.25), value: appeared)
        }
    }

    private var avatarStack: some View {
        HStack(spacing: -14) {
            ForEach(Array(reviews.prefix(5).enumerated()), id: \.element.id) { index, review in
                ReviewAvatar(review: review, size: 52, ringWidth: 3)
                    .zIndex(Double(5 - index))
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.72).delay(0.04 + Double(index) * 0.05),
                        value: appeared
                    )
            }
            Text("+\(OnboardingSocialProof.ratingCount)")
                .font(.system(size: 13, weight: .heavy).monospacedDigit())
                .foregroundStyle(PUColor.limeInk)
                .frame(width: 58, height: 58)
                .background(PUColor.lime, in: .circle)
                .overlay(Circle().strokeBorder(PUColor.canvasDeep, lineWidth: 3))
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.3), value: appeared)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Rating summary

    private var ratingSummary: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "laurel.leading")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(PUColor.lime.opacity(0.85))
                Text(OnboardingSocialProof.averageRating)
                    .font(.system(size: 60, weight: .heavy).monospacedDigit())
                    .tracking(-1.5)
                    .foregroundStyle(PUColor.textPrimary)
                Image(systemName: "laurel.trailing")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(PUColor.lime.opacity(0.85))
            }
            StarRow(rating: 5, size: 17, delay: 0.5)
            Text(OnboardingSocialProof.ratingCaption)
                .font(PUFont.caption)
                .foregroundStyle(PUColor.textSecondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            LinearGradient(colors: [PUColor.surfaceRaised, PUColor.surface],
                           startPoint: .top, endPoint: .bottom),
            in: .rect(cornerRadius: PUMetrics.cardRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PUMetrics.cardRadius)
                .strokeBorder(PUColor.hairline, lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(.spring(response: 0.6, dampingFraction: 0.88).delay(0.35), value: appeared)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rated \(OnboardingSocialProof.averageRating) out of 5. \(OnboardingSocialProof.ratingCaption)")
    }

    // MARK: - Section chrome

    private var sectionLabel: some View {
        HStack {
            Text("What players say")
                .puMicroLabel()
            Spacer()
            Text("\(reviews.count) REVIEWS")
                .font(PUFont.micro)
                .tracking(1.1)
                .foregroundStyle(PUColor.textTertiary)
        }
    }

    private var endMarker: some View {
        HStack(spacing: 10) {
            Rectangle().fill(PUColor.hairline).frame(height: 1)
            Image(systemName: hasReadAll ? "checkmark.circle.fill" : "circle.dotted")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(hasReadAll ? PUColor.lime : PUColor.textTertiary)
                .contentTransition(.symbolEffect(.replace))
            Rectangle().fill(PUColor.hairline).frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(hasReadAll ? "All reviews read" : "Read all reviews to continue")
                    .font(PUFont.caption)
                    .foregroundStyle(hasReadAll ? PUColor.lime : PUColor.textSecondary)
                    .contentTransition(.opacity)
                Spacer()
                ReadingBar(progress: hasReadAll ? 1 : readProgress)
                    .frame(width: 96, height: 4)
            }
            .padding(.horizontal, 4)

            OnboardingCTA(
                title: hasReadAll ? "BUILD MY PLAN" : "KEEP SCROLLING",
                systemImage: hasReadAll ? "arrow.right" : "arrow.down",
                enabled: hasReadAll
            ) { onContinue() }
        }
        .padding(.horizontal, PUMetrics.margin)
        .padding(.top, 26)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                stops: [
                    .init(color: PUColor.canvas.opacity(0), location: 0),
                    .init(color: PUColor.canvas.opacity(0.92), location: 0.35),
                    .init(color: PUColor.canvas, location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        )
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
    }
}

// MARK: - Reading bar

private struct ReadingBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(PUColor.surfaceRaised)
                Capsule()
                    .fill(PUColor.lime)
                    .frame(width: max(4, geo.size.width * progress))
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: progress)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Reviews read")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

// MARK: - Review card

/// App Store-style review: stars and headline, the quote, then the reviewer.
private struct ReviewCard: View {
    let review: OnboardingReview

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    StarRow(rating: review.rating, size: 12, delay: 0)
                    Text(review.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(PUColor.textPrimary)
                }
                Spacer(minLength: 12)
                Image(systemName: "quote.closing")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(PUColor.limeDim)
            }

            Text(review.quote)
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(PUColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            Rectangle()
                .fill(PUColor.hairline)
                .frame(height: 1)
                .padding(.vertical, 16)

            HStack(spacing: 12) {
                ReviewAvatar(review: review, size: 38, ringWidth: 0)
                Text(review.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PUColor.textPrimary)
                Spacer(minLength: 0)
                Text("PICKLEBALL")
                    .font(PUFont.micro)
                    .tracking(1.1)
                    .foregroundStyle(PUColor.textTertiary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PUMetrics.cardRadius)
                .strokeBorder(PUColor.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(review.rating) stars. \(review.title). \(review.quote) By \(review.name).")
    }
}

/// Row of amber stars that light up one after another.
private struct StarRow: View {
    let rating: Int
    let size: CGFloat
    let delay: Double
    @State private var lit = false

    var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(index < rating ? PUColor.amber : PUColor.textTertiary)
                    .scaleEffect(lit ? 1 : 0.4)
                    .opacity(lit ? 1 : 0)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.62).delay(delay + Double(index) * 0.05),
                        value: lit
                    )
            }
        }
        .onAppear { lit = true }
    }
}

// MARK: - Avatar

/// Circular player photo with an optional dark ring; falls back to initials on
/// a raised disc when the photo hasn't been added to the asset catalog yet.
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
                            .font(.system(size: size * 0.34, weight: .heavy))
                            .foregroundStyle(PUColor.lime)
                    )
            }
        }
        .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        .padding(ringWidth)
        .background(PUColor.canvasDeep, in: .circle)
    }
}
