//
//  PUComponents.swift
//  PaddleUp
//
//  Shared component language: cards, dials, bars, tiles, buttons.
//

import SwiftUI

// MARK: - Surfaces

struct PUCard<Content: View>: View {
    var padding: CGFloat = 16
    var background: Color = PUColor.surface
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: .rect(cornerRadius: PUMetrics.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PUMetrics.cardRadius)
                    .strokeBorder(PUColor.hairline, lineWidth: 1)
            )
    }
}

struct PUSectionHeader: View {
    let title: String
    var accessory: String?

    var body: some View {
        HStack {
            Text(title).puMicroLabel()
            Spacer()
            if let accessory {
                Text(accessory)
                    .font(PUFont.micro)
                    .foregroundStyle(PUColor.textTertiary)
            }
        }
    }
}

// MARK: - Buttons

struct PUPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(enabled ? PUColor.limeInk : PUColor.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(enabled ? PUColor.lime : PUColor.surfaceRaised, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PUSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(PUColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(PUColor.surfaceRaised, in: .capsule)
            .overlay(Capsule().strokeBorder(PUColor.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Score dial

/// The signature circular rating dial: thin lime progress ring around a huge numeral.
struct PUScoreDial: View {
    let value: Double?
    var maxValue: Double = 100
    var caption: String
    var subtitle: String?
    var subtitleIsPositive: Bool = true
    var size: CGFloat = 230
    var lineWidth: CGFloat = 14
    var numberFont: Font = PUFont.dial

    @State private var animatedFraction: Double = 0

    private var fraction: Double {
        guard let value, maxValue > 0 else { return 0 }
        return min(1, max(0.02, value / maxValue))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animatedFraction)
                .stroke(
                    PUColor.lime,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: PUColor.lime.opacity(0.35), radius: 12)

            VStack(spacing: 2) {
                Text(caption).puMicroLabel()
                Text(value.map { String(Int($0.rounded())) } ?? "—")
                    .font(numberFont)
                    .foregroundStyle(PUColor.textPrimary)
                    .contentTransition(.numericText())
                if let subtitle {
                    HStack(spacing: 4) {
                        if subtitleIsPositive {
                            Image(systemName: "arrow.up").font(.system(size: 12, weight: .bold))
                        }
                        Text(subtitle).font(PUFont.caption)
                    }
                    .foregroundStyle(subtitleIsPositive ? PUColor.lime : PUColor.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .multilineTextAlignment(.center)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.85)) { animatedFraction = fraction }
        }
        .onChange(of: fraction) { _, newValue in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) { animatedFraction = newValue }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption): \(value.map { String(Int($0)) } ?? "not rated")")
    }
}

// MARK: - Bars

struct PUScoreBar: View {
    let value: Double
    var height: CGFloat = 8
    @State private var animated: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.09))
                Capsule()
                    .fill(PUColor.score(value))
                    .frame(width: max(6, geo.size.width * animated / 100))
            }
        }
        .frame(height: height)
        .onAppear { withAnimation(.easeOut(duration: 0.7)) { animated = min(100, max(0, value)) } }
        .onChange(of: value) { _, new in
            withAnimation(.easeOut(duration: 0.45)) { animated = min(100, max(0, new)) }
        }
    }
}

struct PUMechanicRow: View {
    let title: String
    let value: Double
    var delta: Double?
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(PUFont.body)
                .foregroundStyle(PUColor.textPrimary)
                .frame(width: 128, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            PUScoreBar(value: value)
            Text("\(Int(value.rounded()))")
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(PUColor.textPrimary)
                .frame(width: 30, alignment: .trailing)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PUColor.textTertiary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }
}

// MARK: - Tiles

struct PUStatTile: View {
    let symbol: String
    let symbolColor: Color
    let label: String
    let value: String
    var detail: String?
    var detailIsPositive: Bool = true

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(symbolColor)
                .frame(height: 24)
            Text(label).puMicroLabel().multilineTextAlignment(.center)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PUColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            if let detail {
                Text(detail)
                    .font(PUFont.caption)
                    .foregroundStyle(detailIsPositive ? PUColor.lime : PUColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.tileRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PUMetrics.tileRadius)
                .strokeBorder(PUColor.hairline, lineWidth: 1)
        )
    }
}

/// Four equal columns divided by hairlines — used for session summary headline stats.
struct PUStatStrip: View {
    nonisolated struct Item: Identifiable, Sendable {
        let id = UUID()
        let label: String
        let value: String
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 6) {
                    Text(item.label).puMicroLabel().multilineTextAlignment(.center)
                    Text(item.value)
                        .font(.system(size: 24, weight: .bold).monospacedDigit())
                        .foregroundStyle(PUColor.textPrimary)
                }
                .frame(maxWidth: .infinity)
                if index < items.count - 1 {
                    Rectangle().fill(PUColor.hairline).frame(width: 1, height: 42)
                }
            }
        }
        .padding(.vertical, 16)
        .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PUMetrics.cardRadius)
                .strokeBorder(PUColor.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Branding

struct PUWordmark: View {
    var showsTagline: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 9) {
                PUBallGlyph(size: 26)
                Text("Paddle Up")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(PUColor.textPrimary)
            }
            if showsTagline {
                Text("Practice better  ·  Play higher")
                    .font(PUFont.micro)
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(PUColor.textTertiary)
            }
        }
    }
}

/// The lime pickleball on its own — a radially symmetric mark whose visual
/// centre is exactly its frame centre (the five holes are evenly spaced, so
/// they cancel out). Use this, never `PUBallGlyph`, whenever the mark sits
/// inside a ring, disc or any circular container that must share its centre.
struct PUBallMark: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle().fill(PUColor.lime)
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(PUColor.limeInk.opacity(0.85))
                    .frame(width: size * 0.15, height: size * 0.15)
                    .offset(
                        x: cos(Double(index) / 5 * 2 * .pi) * size * 0.26,
                        y: sin(Double(index) / 5 * 2 * .pi) * size * 0.26
                    )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Lime pickleball with motion streaks — the app's recurring brand glyph.
/// The streaks trail to the left, so this composition is deliberately
/// asymmetric: use `PUBallMark` when the mark must be centred in a circle.
struct PUBallGlyph: View {
    var size: CGFloat = 24

    var body: some View {
        HStack(spacing: 2) {
            VStack(alignment: .trailing, spacing: size * 0.13) {
                Capsule().fill(PUColor.lime.opacity(0.85)).frame(width: size * 0.42, height: size * 0.09)
                Capsule().fill(PUColor.lime.opacity(0.6)).frame(width: size * 0.3, height: size * 0.09)
                Capsule().fill(PUColor.lime.opacity(0.35)).frame(width: size * 0.2, height: size * 0.09)
            }
            PUBallMark(size: size)
        }
        .accessibilityHidden(true)
    }
}

/// Small circular icon badge used in lists and callouts.
struct PUIconBadge: View {
    let symbol: String
    var tint: Color = PUColor.lime
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: .circle)
    }
}

/// Inline empty-state block for screens with no data yet.
struct PUEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(PUColor.textTertiary)
            Text(title)
                .font(PUFont.headline)
                .foregroundStyle(PUColor.textPrimary)
            Text(message)
                .font(PUFont.caption)
                .foregroundStyle(PUColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
