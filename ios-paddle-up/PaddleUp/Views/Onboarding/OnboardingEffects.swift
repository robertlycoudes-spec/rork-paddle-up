//
//  OnboardingEffects.swift
//  PaddleUp
//
//  The onboarding "flash" kit: a light sweep, staggered entrances, a glowing
//  CTA, a live status chip, the orbit brand glyph, an animated court
//  drawing, count-up numerals and a drifting background bloom. Everything
//  stays inside the app palette: canvas, surface, one lime accent.
//

import SwiftUI

// MARK: - Shimmer sweep

extension View {
    /// A diagonal band of light that sweeps across the view's own shape on a loop.
    func shimmerSweep(
        isActive: Bool = true,
        tint: Color = .white,
        intensity: Double = 0.45,
        period: Double = 2.4
    ) -> some View {
        modifier(ShimmerSweep(isActive: isActive, tint: tint, intensity: intensity, period: period))
    }

    /// Fades, lifts and de-blurs the view in, delayed by its list position.
    func staggerIn(_ index: Int, base: Double = 0.12, step: Double = 0.06) -> some View {
        modifier(StaggerIn(index: index, base: base, step: step))
    }
}

private struct ShimmerSweep: ViewModifier {
    let isActive: Bool
    let tint: Color
    let intensity: Double
    let period: Double

    func body(content: Content) -> some View {
        content.overlay {
            if isActive {
                ShimmerBand(tint: tint, intensity: intensity, period: period)
                    .mask(content)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Owns its own phase so it restarts cleanly every time it's inserted.
private struct ShimmerBand: View {
    let tint: Color
    let intensity: Double
    let period: Double
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let band = max(36, width * 0.28)
            LinearGradient(
                colors: [tint.opacity(0), tint.opacity(intensity), tint.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: band, height: height * 3)
            .rotationEffect(.degrees(20))
            .position(x: -band + phase * (width + band * 2), y: height / 2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).delay(period).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

private struct StaggerIn: ViewModifier {
    let index: Int
    let base: Double
    let step: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .blur(radius: shown ? 0 : 6)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)
                    .delay(base + Double(index) * step)) {
                    shown = true
                }
            }
    }
}

// MARK: - Primary CTA

/// The onboarding's lime capsule: soft glow and a light sweep when armed.
struct OnboardingCTA: View {
    let title: String
    var systemImage: String? = "arrow.right"
    var enabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 9) {
                if isLoading {
                    ProgressView().tint(PUColor.limeInk)
                } else {
                    Text(title)
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .heavy))
                    }
                }
            }
        }
        .buttonStyle(PUPrimaryButtonStyle(enabled: enabled))
        .shimmerSweep(isActive: enabled && !isLoading, tint: .white, intensity: 0.5, period: 2.2)
        .shadow(color: PUColor.lime.opacity(enabled ? 0.35 : 0), radius: 18, y: 6)
        .disabled(!enabled || isLoading)
    }
}

// MARK: - Live chip

/// Lime status capsule with a radiating "live" dot.
struct LiveChip: View {
    let text: String
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(PUColor.lime.opacity(0.4))
                    .frame(width: 11, height: 11)
                    .scaleEffect(pulse ? 1.4 : 0.5)
                    .opacity(pulse ? 0 : 1)
                Circle()
                    .fill(PUColor.lime)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 11, height: 11)
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(PUColor.lime)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(PUColor.lime.opacity(0.08), in: .capsule)
        .overlay(Capsule().strokeBorder(PUColor.lime.opacity(0.22), lineWidth: 1))
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

// MARK: - Orbit glyph

/// Symmetric ball mark in a raised disc, two counter-rotating dashed rings,
/// a lime scanner arc and a bloom, plus a one-shot pulse ring on entrance.
/// Every ring spins about the shared centre; satellite dots stay pinned.
struct OrbitGlyph: View {
    var scale: CGFloat = 1
    var showsScanner: Bool = true
    @State private var spinning = false
    @State private var pulsed = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [PUColor.lime.opacity(0.22), .clear],
                        center: .center,
                        startRadius: 4 * scale,
                        endRadius: 70 * scale
                    )
                )
                .frame(width: 140 * scale, height: 140 * scale)

            Circle()
                .strokeBorder(PUColor.lime.opacity(pulsed ? 0 : 0.6), lineWidth: 1.5)
                .frame(width: 72 * scale, height: 72 * scale)
                .scaleEffect(pulsed ? 1.9 : 1)

            Circle()
                .stroke(PUColor.lime.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                .frame(width: 104 * scale, height: 104 * scale)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(.linear(duration: 48).repeatForever(autoreverses: false), value: spinning)

            Circle()
                .stroke(PUColor.lime.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [1, 6]))
                .frame(width: 88 * scale, height: 88 * scale)
                .rotationEffect(.degrees(spinning ? -360 : 0))
                .animation(.linear(duration: 36).repeatForever(autoreverses: false), value: spinning)

            if showsScanner {
                Circle()
                    .trim(from: 0, to: 0.24)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [PUColor.lime.opacity(0), PUColor.lime]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(86)
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 122 * scale, height: 122 * scale)
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .animation(.linear(duration: 2.8).repeatForever(autoreverses: false), value: spinning)
            }

            Circle()
                .fill(PUColor.lime)
                .frame(width: 7 * scale, height: 7 * scale)
                .offset(x: -52 * scale)

            Circle()
                .fill(PUColor.lime.opacity(0.5))
                .frame(width: 4 * scale, height: 4 * scale)
                .offset(x: 44 * scale)

            Circle()
                .fill(PUColor.surfaceRaised)
                .overlay(Circle().strokeBorder(PUColor.hairline, lineWidth: 1))
                .frame(width: 72 * scale, height: 72 * scale)

            PUBallMark(size: 40 * scale)
        }
        .frame(width: 140 * scale, height: 140 * scale)
        .onAppear {
            spinning = true
            withAnimation(.easeOut(duration: 1.2).delay(0.25)) { pulsed = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Court drawing

/// A pickleball court in perspective: sidelines, baselines, both kitchen
/// lines, the net and the centre service lines.
nonisolated struct CourtPerspectiveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.28
        let topLeft = CGPoint(x: rect.minX + inset, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX - inset, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)

        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }

        path.move(to: bottomLeft)
        path.addLine(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.closeSubpath()

        // Far kitchen line, net, near kitchen line (perspective-compressed).
        for t in [0.30, 0.45, 0.62] as [CGFloat] {
            path.move(to: lerp(topLeft, bottomLeft, t))
            path.addLine(to: lerp(topRight, bottomRight, t))
        }

        let topMid = CGPoint(x: rect.midX, y: rect.minY)
        let bottomMid = CGPoint(x: rect.midX, y: rect.maxY)
        path.move(to: topMid)
        path.addLine(to: lerp(topMid, bottomMid, 0.30))
        path.move(to: lerp(topMid, bottomMid, 0.62))
        path.addLine(to: bottomMid)
        return path
    }
}

/// Court lines that draw themselves in, fading toward the top.
struct CourtBackdrop: View {
    @State private var drawn = false

    var body: some View {
        CourtPerspectiveShape()
            .trim(from: 0, to: drawn ? 1 : 0)
            .stroke(PUColor.lime.opacity(0.18),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
            .onAppear {
                withAnimation(.easeOut(duration: 1.8).delay(0.3)) { drawn = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Count-up numerals

/// An integer that rolls up from zero with numeric text transitions.
struct CountUpText: View {
    let value: Int
    let font: Font
    let color: Color
    var delay: Double = 0
    var duration: Double = 0.9
    @State private var shown = 0

    var body: some View {
        Text("\(shown)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(shown)))
            .task(id: value) {
                try? await Task.sleep(for: .seconds(delay))
                let steps = min(max(value, 1), 24)
                let stepDelay = max(1, Int(duration * 1000) / steps)
                for step in 1...steps {
                    try? await Task.sleep(for: .milliseconds(stepDelay))
                    if Task.isCancelled { return }
                    let next = Int((Double(value) * Double(step) / Double(steps)).rounded())
                    withAnimation(.snappy(duration: 0.2)) { shown = next }
                }
            }
            .accessibilityLabel("\(value)")
    }
}

// MARK: - Backdrop

/// The app canvas plus a soft lime bloom that drifts across as the player
/// moves through the flow, so every step feels like forward motion.
struct OnboardingBackdrop: View {
    var progress: Double

    var body: some View {
        ZStack {
            PUBackground()
            GeometryReader { geo in
                Circle()
                    .fill(PUColor.lime.opacity(0.07))
                    .frame(width: 340, height: 340)
                    .blur(radius: 90)
                    .position(x: geo.size.width * (0.15 + 0.7 * progress),
                              y: geo.size.height * 0.12)
                    .animation(.easeInOut(duration: 0.9), value: progress)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
