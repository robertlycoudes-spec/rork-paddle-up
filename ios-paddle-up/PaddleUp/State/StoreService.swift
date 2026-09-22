//
//  StoreService.swift
//  PaddleUp
//
//  Paddle Up Pro subscription entitlement.
//
//  TEMPORARY — LOCAL ENTITLEMENT: no billing SDK is wired yet, so purchases
//  resolve against a locally stored entitlement. Everything else is production
//  shaped: gating rules, product catalogue, restore, and management all flow
//  through this one service, so switching to real StoreKit/RevenueCat billing
//  means replacing `purchase` / `restore` and the entitlement read — no screen
//  or gating rule changes.
//

import Foundation
import Observation
import SwiftUI

nonisolated struct SubscriptionProduct: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let price: String
    let period: String
    let subtitle: String?
    let badge: String?
    /// Monthly-equivalent price, for the savings line.
    let monthlyEquivalent: String?
}

/// Pricing is configurable in one place.
nonisolated enum PricingConfiguration {
    static let monthly = SubscriptionProduct(
        id: "paddleup_pro_monthly",
        title: "Monthly",
        price: "$9.99",
        period: "per month",
        subtitle: "Cancel anytime",
        badge: nil,
        monthlyEquivalent: nil
    )

    static let annual = SubscriptionProduct(
        id: "paddleup_pro_annual",
        title: "Annual",
        price: "$59.99",
        period: "per year",
        subtitle: "Billed once a year",
        badge: "Save 50%",
        monthlyEquivalent: "$5.00 / month"
    )

    static var all: [SubscriptionProduct] { [annual, monthly] }
}

/// What the free tier allows before Pro is required.
nonisolated enum FreeTierLimits {
    /// Free players get onboarding plus one complete session.
    static let includedSessions = 1
    /// Free history depth.
    static let visibleSessionHistory = 3
}

nonisolated enum ProFeature: String, CaseIterable, Sendable, Identifiable {
    case unlimitedSessions
    case fullShotAnalysis
    case completeHistory
    case personalizedPlans
    case advancedTrends
    case swingMatch
    case advancedLiveCoaching

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedSessions: return "Unlimited practice sessions"
        case .fullShotAnalysis: return "Full shot analysis on every rep"
        case .completeHistory: return "Complete session & rep history"
        case .personalizedPlans: return "Personalised weekly practice plans"
        case .advancedTrends: return "Advanced mechanic trends"
        case .swingMatch: return "Swing Match & benchmark comparison"
        case .advancedLiveCoaching: return "Advanced live audio coaching"
        }
    }

    var symbol: String {
        switch self {
        case .unlimitedSessions: return "infinity"
        case .fullShotAnalysis: return "scope"
        case .completeHistory: return "clock.arrow.circlepath"
        case .personalizedPlans: return "calendar"
        case .advancedTrends: return "chart.line.uptrend.xyaxis"
        case .swingMatch: return "person.2.fill"
        case .advancedLiveCoaching: return "waveform"
        }
    }
}

@MainActor
@Observable
final class StoreService {
    private let entitlementKey = "app.paddleup.pro.entitlement"
    private let productKey = "app.paddleup.pro.product"

    private(set) var isPro: Bool = false
    private(set) var activeProductID: String?
    private(set) var isPurchasing = false
    private(set) var lastError: String?

    let products = PricingConfiguration.all

    init() {
        isPro = UserDefaults.standard.bool(forKey: entitlementKey)
        activeProductID = UserDefaults.standard.string(forKey: productKey)
    }

    var activeProduct: SubscriptionProduct? {
        products.first { $0.id == activeProductID }
    }

    /// MOCK PURCHASE — replace with a real billing transaction.
    func purchase(_ product: SubscriptionProduct) async -> Bool {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        try? await Task.sleep(for: .milliseconds(700))

        isPro = true
        activeProductID = product.id
        UserDefaults.standard.set(true, forKey: entitlementKey)
        UserDefaults.standard.set(product.id, forKey: productKey)
        return true
    }

    /// MOCK RESTORE — replace with a real entitlement fetch.
    func restore() async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        try? await Task.sleep(for: .milliseconds(500))

        let restored = UserDefaults.standard.bool(forKey: entitlementKey)
        isPro = restored
        if !restored { lastError = "No previous purchase found for this Apple Account." }
        return restored
    }

    /// Development affordance so the full Pro experience stays testable.
    func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: entitlementKey)
        if !value {
            activeProductID = nil
            UserDefaults.standard.removeObject(forKey: productKey)
        }
    }

    // MARK: - Gating

    /// Whether the player may start another session.
    func canStartSession(completedSessions: Int) -> Bool {
        isPro || completedSessions < FreeTierLimits.includedSessions
    }

    func sessionHistoryLimit() -> Int? {
        isPro ? nil : FreeTierLimits.visibleSessionHistory
    }

    func isLocked(_ feature: ProFeature) -> Bool { !isPro }
}
