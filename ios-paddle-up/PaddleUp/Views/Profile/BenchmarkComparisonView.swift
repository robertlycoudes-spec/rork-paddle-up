//
//  BenchmarkComparisonView.swift
//  PaddleUp
//
//  YOUR FORM vs ELITE REFERENCE — per-mechanic angle/measurement comparison.
//

import SwiftUI

struct BenchmarkComparisonView: View {
    let result: SwingMatchResult

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                ForEach(result.comparisons) { comparison in
                    ComparisonRow(comparison: comparison)
                }
                Text("Comparison is based on normalised joint angles, timing and contact position — not appearance or footage.")
                    .font(.system(size: 11))
                    .foregroundStyle(PUColor.textTertiary)
            }
            .padding(PUMetrics.margin)
        }
        .puScreenBackground()
        .navigationTitle("Benchmark Comparison")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var summaryCard: some View {
        PUCard {
            HStack(spacing: 16) {
                PUIconBadge(symbol: result.profile.avatarSymbol, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text("YOUR FORM vs \(result.profile.displayName.uppercased())").puMicroLabel()
                    Text("\(Int(result.similarity))% similarity")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(PUColor.score(result.similarity))
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct ComparisonRow: View {
    let comparison: MechanicComparison

    var body: some View {
        PUCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(comparison.mechanic.displayName).puMicroLabel()
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You").font(.system(size: 11)).foregroundStyle(PUColor.textTertiary)
                        Text(comparison.formatted(comparison.yourValue))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(PUColor.textPrimary)
                    }
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13))
                        .foregroundStyle(PUColor.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reference").font(.system(size: 11)).foregroundStyle(PUColor.textTertiary)
                        Text(comparison.formatted(comparison.referenceValue))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(PUColor.lime)
                    }
                    Spacer()
                    Text(comparison.formattedDifference)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(abs(comparison.normalizedGap) < 0.2 ? PUColor.lime : PUColor.amber)
                }
                Text(comparison.meaning)
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
