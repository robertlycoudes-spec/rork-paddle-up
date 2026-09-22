//
//  WelcomePremiumView.swift
//  PaddleUp
//

import SwiftUI

/// Full-screen celebration shown immediately after a successful subscription:
/// the brand mark in counter-rotating orbit rings over a lime bloom, a one-shot
/// pulse ring on entrance, a pulsing "PREMIUM ACTIVE" chip, a staged reveal of
/// everything the plan just unlocked, and the way back into the app. Reuses
/// the hook's motion language — flat surfaces, hairlines, one lime fill.
struct WelcomePremiumView: View {
    var firstName: String = ""
    var onDone: () -> Void

    @State private var appeared = false
    @State private var pulsed = false
    @State private var outerRotation: Double = 0
    @State private var innerRotation: Double = 0
    @State private var chipDotPulsing = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 20) {
                glyph

                VStack(spacing: 10) {
                    Text("Welcome to")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(PUColor.textPrimary)
                    (Text("PaddleUp ").foregroundStyle(PUColor.textPrimary)
                     + Text("Premium").foregroundStyle(PUColor.lime))
                        .font(.system(size: 30, weight: .heavy))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(PUColor.lime)
                        .frame(width: 26, height: 3)
                    Text(subtitle)
                        .font(PUFont.body)
                        .foregroundStyle(PUColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.85).delay(0.25),
                    value: appeared)

                chip
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.45), value: appeared)
            }
            .padding(.horizontal, PUMetrics.margin)

            unlockedCard
                .padding(.horizontal, PUMetrics.margin)
                .padding(.top, 32)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .puScreenBackground()
        .safeAreaInset(edge: .bottom) { footer }
        .onAppear { animateIn() }
    }

    private var subtitle: String {
        let name = firstName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty
            ? "Your plan is live and your coach is ready."
            : "\(name), your plan is live and your coach is ready."
    }

    /// Symmetric mark in a raised disc, two counter-rotating dashed orbit rings
    /// with pinned satellite dots, a faint lime bloom, and a one-shot expanding
    /// pulse ring fired once on entrance. Every ring rotates alone around its
    /// own centre so nothing wobbles.
    private var glyph: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [PUColor.lime.opacity(0.16), .clear],
                    center: .center, startRadius: 4, endRadius: 80))

            Circle()
                .strokeBorder(PUColor.lime, lineWidth: 2)
                .frame(width: 150, height: 150)
                .scaleEffect(pulsed ? 1.5 : 0.9)
                .opacity(pulsed ? 0 : 0.55)
                .animation(.easeOut(duration: 1.0).delay(0.5), value: pulsed)

            Circle()
                .strokeBorder(PUColor.lime.opacity(0.35),
                              style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                .frame(width: 124, height: 124)
                .rotationEffect(.degrees(outerRotation))
                .animation(.linear(duration: 48).repeatForever(autoreverses: false),
                           value: outerRotation)

            Circle()
                .strokeBorder(PUColor.lime.opacity(0.18),
                              style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                .frame(width: 106, height: 106)
                .rotationEffect(.degrees(innerRotation))
                .animation(.linear(duration: 36).repeatForever(autoreverses: false),
                           value: innerRotation)

            Circle().fill(PUColor.lime)
                .frame(width: 7, height: 7)
                .offset(x: -62)
            Circle().fill(PUColor.lime.opacity(0.5))
                .frame(width: 5, height: 5)
                .offset(x: 53)

            Circle()
                .fill(PUColor.surfaceRaised)
                .frame(width: 84, height: 84)
                .overlay(Circle().strokeBorder(PUColor.hairline, lineWidth: 1))

            PUBallMark(size: 46)
        }
        .frame(width: 160, height: 160)
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appeared)
        .accessibilityHidden(true)
    }

    private var chip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(PUColor.lime)
                .frame(width: 5, height: 5)
                .scaleEffect(chipDotPulsing ? 0.6 : 1)
            Text("PREMIUM ACTIVE")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(PUColor.lime)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(PUColor.lime.opacity(0.08), in: .capsule)
        .overlay(Capsule().strokeBorder(PUColor.lime.opacity(0.2), lineWidth: 1))
    }

    private var unlockedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(PUColor.lime)
                    .frame(width: 16, height: 2)
                Text("UNLOCKED JUST NOW")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(PUColor.lime)
                Rectangle().fill(PUColor.hairline).frame(height: 1)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.65), value: appeared)

            PUCard {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(ProFeature.allCases.enumerated()),
                            id: \.element) { index, feature in
                        HStack(spacing: 14) {
                            Image(systemName: feature.symbol)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(PUColor.lime)
                                .frame(width: 40, height: 40)
                                .background(PUColor.lime.opacity(0.14), in: .circle)
                                .overlay(Circle().strokeBorder(PUColor.hairline, lineWidth: 1))
                            Text(feature.title)
                                .font(PUFont.body)
                                .foregroundStyle(PUColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.85)
                                .delay(0.8 + Double(index) * 0.07),
                            value: appeared)
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button {
                Haptics.tap()
                onDone()
            } label: {
                Text("START TRAINING")
            }
            .buttonStyle(PUPrimaryButtonStyle())
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(
                .spring(response: 0.55, dampingFraction: 0.85).delay(1.5),
                value: appeared)

            Text("Membership active — manage or cancel any time.")
                .font(.system(size: 11))
                .foregroundStyle(PUColor.textTertiary)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(1.7), value: appeared)
        }
        .padding(.horizontal, PUMetrics.margin)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func animateIn() {
        appeared = true
        withAnimation(.easeOut(duration: 1.0).delay(0.5)) { pulsed = true }
        withAnimation(.linear(duration: 48).repeatForever(autoreverses: false)) {
            outerRotation = 360
        }
        withAnimation(.linear(duration: 36).repeatForever(autoreverses: false)) {
            innerRotation = -360
        }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            chipDotPulsing = true
        }
    }
}
