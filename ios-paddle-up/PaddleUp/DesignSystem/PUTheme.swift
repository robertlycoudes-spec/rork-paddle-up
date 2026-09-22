//
//  PUTheme.swift
//  PaddleUp
//
//  Design tokens for the "Rating Hero" visual system.
//

import SwiftUI

/// Builds an sRGB color from a packed hex literal.
nonisolated func puHex(_ hex: UInt32, _ opacity: Double = 1) -> Color {
    Color(
        .sRGB,
        red: Double((hex >> 16) & 0xFF) / 255,
        green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255,
        opacity: opacity
    )
}

/// Core palette. Near-black canvas, charcoal surfaces, a single lime accent.
nonisolated enum PUColor {
    static let canvas = puHex(0x0B0F0C)
    static let canvasDeep = puHex(0x070A08)
    static let surface = puHex(0x151B16)
    static let surfaceRaised = puHex(0x1C241D)
    static let hairline = Color.white.opacity(0.08)
    static let lime = puHex(0xC6FF3D)
    static let limeDim = puHex(0xC6FF3D, 0.16)
    static let limeInk = puHex(0x0A1005)
    static let textPrimary = puHex(0xF4F7F2)
    static let textSecondary = puHex(0x8C968D)
    static let textTertiary = puHex(0x5E6760)
    static let alert = puHex(0xFF5F52)
    static let alertDim = puHex(0xFF5F52, 0.14)
    static let amber = puHex(0xFFB020)

    /// Color used for a 0-100 score readout.
    static func score(_ value: Double) -> Color {
        switch value {
        case ..<60: return alert
        case ..<75: return amber
        default: return lime
        }
    }
}

/// Typographic roles. Huge tabular numerals are the apex of the hierarchy.
nonisolated enum PUFont {
    static let dial = Font.system(size: 88, weight: .heavy).monospacedDigit()
    static let hero = Font.system(size: 56, weight: .heavy).monospacedDigit()
    static let metric = Font.system(size: 30, weight: .bold).monospacedDigit()
    static let title = Font.system(size: 22, weight: .bold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 15, weight: .medium)
    static let caption = Font.system(size: 13, weight: .medium)
    static let micro = Font.system(size: 11, weight: .semibold)
}

nonisolated enum PUMetrics {
    static let margin: CGFloat = 20
    static let cardRadius: CGFloat = 20
    static let tileRadius: CGFloat = 16
    static let gutter: CGFloat = 12
}

extension View {
    /// Small-caps style label used above every metric in the app.
    func puMicroLabel() -> some View {
        self.font(PUFont.micro)
            .textCase(.uppercase)
            .tracking(1.1)
            .foregroundStyle(PUColor.textSecondary)
    }

    /// The app-wide near-black background with a faint court-green glow.
    func puScreenBackground() -> some View {
        self.background(PUBackground().ignoresSafeArea())
    }
}

/// Atmospheric canvas: near-black with a soft off-center lime bloom.
struct PUBackground: View {
    var body: some View {
        ZStack {
            PUColor.canvas
            RadialGradient(
                colors: [puHex(0x1E3A12, 0.55), .clear],
                center: UnitPoint(x: 0.85, y: 0.08),
                startRadius: 10,
                endRadius: 420
            )
            RadialGradient(
                colors: [puHex(0x0E2410, 0.6), .clear],
                center: UnitPoint(x: 0.1, y: 0.95),
                startRadius: 10,
                endRadius: 380
            )
        }
    }
}
