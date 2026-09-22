//
//  OnboardingRadarChart.swift
//  PaddleUp
//
//  Six-axis skill radar for the onboarding story slides. Slide one shows a
//  player's map with visible gaps (weak axes dotted in alert red); slide two
//  shows the same map fully developed. Grows from the centre on appear so the
//  chart feels measured, not static.
//

import SwiftUI

struct OnboardingRadarChart: View {
    nonisolated struct Axis: Identifiable, Sendable, Equatable {
        let label: String
        /// 0...1 relative skill level.
        let value: Double
        nonisolated var id: String { label }
    }

    let axes: [Axis]
    let caption: String
    var showsLegend: Bool = false

    /// Axes below this level read as "needs work" — mirrors the 0–100 score
    /// colour ramp's 60-point line.
    private let solidThreshold = 0.6

    @State private var progress: Double = 0

    private let chartSize: CGFloat = 290
    private let radius: CGFloat = 84

    private var center: CGPoint {
        CGPoint(x: chartSize / 2, y: chartSize / 2)
    }

    var body: some View {
        PUCard {
            VStack(spacing: 16) {
                ZStack {
                    grid
                    dataShape
                        .scaleEffect(progress, anchor: .center)
                    dots
                    labels
                }
                .frame(width: chartSize, height: chartSize)
                .frame(maxWidth: .infinity)

                Text(caption)
                    .font(PUFont.body)
                    .foregroundStyle(PUColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(progress)

                if showsLegend {
                    HStack(spacing: 18) {
                        HStack(spacing: 6) {
                            Circle().fill(PUColor.alert).frame(width: 8, height: 8)
                            Text("Needs work")
                        }
                        HStack(spacing: 6) {
                            Circle().fill(PUColor.lime).frame(width: 8, height: 8)
                            Text("Solid")
                        }
                    }
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
                    .opacity(progress)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.85).delay(0.15)) { progress = 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Skill radar: " + axes.map { "\($0.label) \(Int($0.value * 100)) percent" }
                .joined(separator: ", ")
        )
    }

    // MARK: - Geometry

    private func point(axis index: Int, fraction: CGFloat) -> CGPoint {
        let angle = (Double(index) * 60 - 90) * .pi / 180
        return CGPoint(
            x: center.x + cos(angle) * radius * fraction,
            y: center.y + sin(angle) * radius * fraction
        )
    }

    private func polygon(_ fractions: [CGFloat]) -> Path {
        var path = Path()
        for (index, fraction) in fractions.enumerated() {
            let point = point(axis: index, fraction: fraction)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Layers

    /// Concentric hexagon rings and spokes in hairline strokes.
    private var grid: some View {
        ZStack {
            ForEach([0.33, 0.66, 1.0], id: \.self) { fraction in
                polygon(Array(repeating: fraction, count: 6))
                    .stroke(PUColor.hairline, lineWidth: 1)
            }
            ForEach(0..<6, id: \.self) { index in
                Path { path in
                    path.move(to: center)
                    path.addLine(to: point(axis: index, fraction: 1))
                }
                .stroke(PUColor.hairline, lineWidth: 1)
            }
        }
    }

    private var dataShape: some View {
        polygon(axes.map { CGFloat($0.value) })
            .fill(PUColor.limeDim)
            .overlay(
                polygon(axes.map { CGFloat($0.value) })
                    .stroke(PUColor.lime, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            )
    }

    /// Vertex dots: alert below the solid threshold, lime above.
    private var dots: some View {
        ForEach(Array(axes.enumerated()), id: \.element.id) { index, axis in
            Circle()
                .fill(axis.value >= solidThreshold ? PUColor.lime : PUColor.alert)
                .frame(width: 11, height: 11)
                .overlay(Circle().strokeBorder(PUColor.canvas, lineWidth: 2))
                .position(point(axis: index, fraction: CGFloat(axis.value)))
                .scaleEffect(progress, anchor: .center)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.65)
                        .delay(0.35 + Double(index) * 0.07),
                    value: progress
                )
        }
    }

    private var labels: some View {
        ForEach(Array(axes.enumerated()), id: \.element.id) { index, axis in
            Text(axis.label)
                .font(PUFont.caption)
                .foregroundStyle(PUColor.textSecondary)
                .lineLimit(1)
                .fixedSize()
                .position(point(axis: index, fraction: CGFloat((radius + 34) / radius)))
        }
    }
}
