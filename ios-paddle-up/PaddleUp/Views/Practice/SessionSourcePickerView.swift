//
//  SessionSourcePickerView.swift
//  PaddleUp
//
//  First step of every session: record live with the camera, or analyze an
//  existing video. Both paths score reps with the same pipeline.
//

import SwiftUI

struct SessionSourcePickerView: View {
    let configuration: PracticeConfiguration
    let onRecordLive: () -> Void
    let onUpload: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PUColor.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(PUColor.surfaceRaised, in: .circle)
                }
                .accessibilityLabel("Close")
                Spacer()
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(configuration.mode.displayName).puMicroLabel()
                Text(title)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(PUColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Choose how Paddle Up should see your swings.")
                    .font(PUFont.body)
                    .foregroundStyle(PUColor.textSecondary)
            }
            .padding(.top, 20)

            VStack(spacing: 12) {
                SourceOptionCard(
                    symbol: "camera.fill",
                    title: "Record Live",
                    detail: "Prop your phone up and get every rep scored in real time, with live coaching.",
                    isPrimary: true,
                    action: onRecordLive
                )
                SourceOptionCard(
                    symbol: "film.stack",
                    title: "Upload Video",
                    detail: "Pick a clip from your library. Same scoring, feedback and summary as a live session.",
                    isPrimary: false,
                    action: onUpload
                )
            }
            .padding(.top, 28)

            Spacer()

            HStack(spacing: 8) {
                MetaChip(symbol: "figure.pickleball", text: configuration.drill?.name ?? configuration.shot.displayName)
                MetaChip(symbol: "clock", text: configuration.length.displayName)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, PUMetrics.margin)
        .puScreenBackground()
    }

    private var title: String {
        switch configuration.mode {
        case .assessment: return "Baseline Assessment"
        case .drill: return configuration.drill?.name ?? "Drill"
        case .freePractice: return configuration.shot.displayName
        }
    }
}

private struct SourceOptionCard: View {
    let symbol: String
    let title: String
    let detail: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isPrimary ? PUColor.limeInk : PUColor.lime)
                    .frame(width: 52, height: 52)
                    .background(isPrimary ? PUColor.lime : PUColor.limeDim, in: .circle)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(PUColor.textPrimary)
                    Text(detail)
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PUColor.textTertiary)
            }
            .padding(18)
            .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PUMetrics.cardRadius)
                    .strokeBorder(isPrimary ? PUColor.lime.opacity(0.45) : PUColor.hairline, lineWidth: 1)
            )
            .contentShape(.rect(cornerRadius: PUMetrics.cardRadius))
        }
        .buttonStyle(SourceCardPressStyle())
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}

private struct SourceCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
