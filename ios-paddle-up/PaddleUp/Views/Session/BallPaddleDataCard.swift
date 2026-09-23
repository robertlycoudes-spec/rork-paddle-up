//
//  BallPaddleDataCard.swift
//  PaddleUp
//
//  Where ball and paddle metrics will live once Paddle Up can measure them.
//  Paddle Up tracks the body only today, so every value reads "Not yet
//  available" unless a real measurement is ever stored on the rep.
//

import SwiftUI

struct BallPaddleDataCard: View {
    let rep: RepRecord

    private var metrics: [(title: String, symbol: String, value: String?)] {
        [
            ("Ball speed", "gauge.with.dots.needle.67percent", rep.ballSpeedMPH.map { "\(Int($0.rounded())) mph" }),
            ("Spin", "arrow.triangle.2.circlepath", rep.spinRPM.map { "\(Int($0.rounded())) rpm" }),
            ("Paddle face angle", "rectangle.portrait.rotate", rep.paddleFaceAngleDegrees.map { "\(Int($0.rounded()))°" }),
            ("Contact timing", "timer", rep.contactTimingPrecisionMS.map { "±\(Int($0.rounded())) ms" })
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Ball & paddle")
            PUCard(padding: 14) {
                VStack(spacing: 0) {
                    ForEach(Array(metrics.enumerated()), id: \.element.title) { index, metric in
                        HStack(spacing: 12) {
                            Image(systemName: metric.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PUColor.textTertiary)
                                .frame(width: 22)
                            Text(metric.title)
                                .font(PUFont.body)
                                .foregroundStyle(PUColor.textPrimary)
                            Spacer()
                            if let value = metric.value {
                                Text(value)
                                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(PUColor.textPrimary)
                            } else {
                                Text("Not yet available")
                                    .font(PUFont.caption)
                                    .foregroundStyle(PUColor.textTertiary)
                            }
                        }
                        .padding(.vertical, 10)
                        if index < metrics.count - 1 {
                            Divider().overlay(PUColor.hairline)
                        }
                    }
                    Text("Paddle Up measures your body mechanics today. Ball and paddle tracking are on the way.")
                        .font(.system(size: 11))
                        .foregroundStyle(PUColor.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
