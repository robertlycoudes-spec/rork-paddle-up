//
//  CompEntitlement.swift
//  PaddleUp
//
//  Free Pro access granted by a friend comp code. Completely separate from
//  Apple billing: it sits alongside StoreKit entitlements in `StoreService`.
//

import Foundation

nonisolated struct CompEntitlement: Codable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable {
        case freeMonth
        case lifetime
    }

    /// The account the grant belongs to — a cached grant never carries over
    /// to a different signed-in account.
    let userID: String
    let kind: Kind
    /// Nil means lifetime: the grant never expires.
    let compExpiresAt: Date?
    let grantedAt: Date

    /// Always "comp" — mirrors the server's `entitlementSource`.
    var entitlementSource: String { "comp" }

    func isActive(at date: Date = .now) -> Bool {
        guard let compExpiresAt else { return true }
        return compExpiresAt > date
    }
}

/// The server's JSON shape: dates are epoch milliseconds.
nonisolated struct CompEntitlementDTO: Decodable, Sendable {
    let isPro: Bool
    let entitlementSource: String
    let type: String
    let compExpiresAt: Double?
    let grantedAt: Double

    func entitlement(userID: String) -> CompEntitlement? {
        guard entitlementSource == "comp", let kind = CompEntitlement.Kind(rawValue: type) else { return nil }
        return CompEntitlement(
            userID: userID,
            kind: kind,
            compExpiresAt: compExpiresAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            grantedAt: Date(timeIntervalSince1970: grantedAt / 1000)
        )
    }
}
