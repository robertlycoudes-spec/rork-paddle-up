//
//  StoreService.swift
//  PaddleUp
//
//  Paddle Up Pro subscription entitlement, backed by Apple StoreKit 2.
//
//  `isPro` is derived only from verified, unrevoked, unexpired transactions in
//  `Transaction.currentEntitlements` for the two Paddle Up Pro product IDs.
//  Purchases, restore (`AppStore.sync`) and renewals/refunds arriving via
//  `Transaction.updates` all funnel through `refreshEntitlements()`.
//  The gating rules below (`canStartSession`, `sessionHistoryLimit`,
//  `isLocked`) are unchanged — only what backs `isPro` is real now.
//
//  Requires `paddleup_pro_monthly` and `paddleup_pro_annual` to exist as
//  auto-renewable subscriptions in App Store Connect for this bundle ID.
//

import Foundation
import Observation
import OSLog
import StoreKit
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
    private let logger = Logger(subsystem: "app.paddleup", category: "store")
    private let productIDs: Set<String> = [PricingConfiguration.monthly.id, PricingConfiguration.annual.id]

    /// True only while a verified, active Paddle Up Pro subscription exists
    /// (or the developer override is on in a DEBUG build).
    var isPro: Bool { hasVerifiedEntitlement || debugOverride }
    private(set) var hasVerifiedEntitlement = false
    private(set) var activeProductID: String?
    private(set) var expirationDate: Date?
    private(set) var willAutoRenew: Bool?
    private(set) var isPurchasing = false
    private(set) var lastError: String?
    /// True once the App Store returned both products. When false, the paywall
    /// still renders from `PricingConfiguration` but purchases are unavailable.
    private(set) var storeProductsLoaded = false

    /// DEBUG-only override so the Pro experience stays testable in the
    /// simulator before App Store Connect products exist. Never compiled into
    /// Release builds' gating.
    private(set) var debugOverride = false

    private var storeProducts: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    /// Products for display: live App Store price strings when available,
    /// otherwise the configured catalogue.
    var products: [SubscriptionProduct] {
        PricingConfiguration.all.map { configured in
            guard let live = storeProducts[configured.id] else { return configured }
            return SubscriptionProduct(
                id: configured.id,
                title: configured.title,
                price: live.displayPrice,
                period: configured.period,
                subtitle: configured.subtitle,
                badge: configured.badge,
                monthlyEquivalent: monthlyEquivalent(for: live) ?? configured.monthlyEquivalent
            )
        }
    }

    var activeProduct: SubscriptionProduct? {
        products.first { $0.id == activeProductID }
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: productIDs)
            storeProducts = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            storeProductsLoaded = productIDs.allSatisfy { storeProducts[$0] != nil }
            if !storeProductsLoaded {
                logger.warning("App Store returned \(loaded.count) of \(self.productIDs.count) Pro products.")
            }
        } catch {
            storeProductsLoaded = false
            logger.error("Failed to load products: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func monthlyEquivalent(for product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod,
              period.unit == .year, period.value == 1 else { return nil }
        let monthly = product.price / 12
        return "\(monthly.formatted(product.priceFormatStyle)) / month"
    }

    // MARK: - Purchase & restore

    /// Buys a subscription through StoreKit. Returns true only when a verified
    /// transaction grants Pro.
    func purchase(_ subscription: SubscriptionProduct) async -> Bool {
        lastError = nil
        if storeProducts[subscription.id] == nil { await loadProducts() }
        guard let product = storeProducts[subscription.id] else {
            lastError = "Subscriptions aren't available right now. Check your connection and try again."
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "Apple couldn't verify this purchase. You have not been charged twice — try Restore."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return hasVerifiedEntitlement
            case .pending:
                lastError = "Your purchase is pending approval. Pro unlocks as soon as it's approved."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            lastError = "The purchase didn't complete. Please try again."
            return false
        }
    }

    /// Restores purchases by syncing with the App Store, then re-reading the
    /// verified entitlements.
    func restore() async -> Bool {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
        } catch {
            // Cancelling the Apple ID prompt lands here; still re-read what we have.
            logger.info("AppStore.sync did not complete: \(error.localizedDescription, privacy: .public)")
        }
        await refreshEntitlements()
        if !hasVerifiedEntitlement {
            lastError = "No active Paddle Up Pro subscription found for this Apple Account."
        }
        return hasVerifiedEntitlement
    }

    // MARK: - Entitlements

    /// Re-derives Pro from verified current entitlements. Unverified,
    /// revoked and expired transactions never grant access.
    func refreshEntitlements() async {
        var activeID: String?
        var expiry: Date?
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expires = transaction.expirationDate, expires < .now { continue }
            // Prefer the entitlement that runs longest.
            if expiry == nil || (transaction.expirationDate ?? .distantFuture) > (expiry ?? .distantPast) {
                activeID = transaction.productID
                expiry = transaction.expirationDate
            }
        }
        hasVerifiedEntitlement = activeID != nil
        activeProductID = activeID
        expirationDate = expiry
        willAutoRenew = await autoRenewStatus(for: activeID)
    }

    private func autoRenewStatus(for productID: String?) async -> Bool? {
        guard let productID, let product = storeProducts[productID],
              let statuses = try? await product.subscription?.status else { return nil }
        for status in statuses {
            if case .verified(let info) = status.renewalInfo { return info.willAutoRenew }
        }
        return nil
    }

    private func handle(_ update: VerificationResult<StoreKit.Transaction>) async {
        if case .verified(let transaction) = update {
            await transaction.finish()
        }
        await refreshEntitlements()
    }

    /// Developer affordance so the full Pro experience stays testable before
    /// App Store Connect products exist. Only effective in DEBUG builds.
    func setPro(_ value: Bool) {
        #if DEBUG
        debugOverride = value
        #endif
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
