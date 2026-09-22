//
//  PaywallView.swift
//  PaddleUp
//

import SwiftUI

struct PaywallView: View {
    @Environment(StoreService.self) private var store
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String = PricingConfiguration.annual.id
    @State private var message: String?
    @State private var showWelcome = false

    private var selectedProduct: SubscriptionProduct {
        store.products.first { $0.id == selectedProductID } ?? PricingConfiguration.annual
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    featureList
                    productPicker
                    if let message {
                        Text(message)
                            .font(PUFont.caption)
                            .foregroundStyle(PUColor.amber)
                            .multilineTextAlignment(.center)
                    }
                    legal
                }
                .padding(.horizontal, PUMetrics.margin)
                .padding(.bottom, 24)
            }
            .puScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PUColor.textSecondary)
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restore") { restore() }
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) { purchaseBar }
        }
        .onAppear { appState.analytics.record(.paywallViewed) }
        .fullScreenCover(isPresented: $showWelcome) {
            WelcomePremiumView(firstName: appState.profile.displayName) {
                dismiss()
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            PUBallGlyph(size: 46)
            Text("Paddle Up Pro")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(PUColor.textPrimary)
            Text("Unlimited practice, full analysis on every rep, and a coach that measures whether you actually improved.")
                .font(PUFont.body)
                .foregroundStyle(PUColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var featureList: some View {
        PUCard {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(ProFeature.allCases) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PUColor.lime)
                            .frame(width: 24)
                        Text(feature.title)
                            .font(PUFont.body)
                            .foregroundStyle(PUColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var productPicker: some View {
        VStack(spacing: 10) {
            ForEach(store.products) { product in
                Button {
                    Haptics.tap()
                    selectedProductID = product.id
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: selectedProductID == product.id
                              ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(selectedProductID == product.id
                                             ? PUColor.lime : PUColor.textTertiary.opacity(0.6))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(product.title)
                                    .font(PUFont.headline)
                                    .foregroundStyle(PUColor.textPrimary)
                                if let badge = product.badge {
                                    Text(badge)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(PUColor.limeInk)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(PUColor.lime, in: .capsule)
                                }
                            }
                            if let subtitle = product.subtitle {
                                Text(subtitle)
                                    .font(PUFont.caption)
                                    .foregroundStyle(PUColor.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(product.price)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(PUColor.textPrimary)
                            Text(product.monthlyEquivalent ?? product.period)
                                .font(.system(size: 11))
                                .foregroundStyle(PUColor.textTertiary)
                        }
                    }
                    .padding(16)
                    .background(selectedProductID == product.id ? PUColor.surfaceRaised : PUColor.surface,
                                in: .rect(cornerRadius: PUMetrics.tileRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: PUMetrics.tileRadius)
                            .strokeBorder(selectedProductID == product.id
                                          ? PUColor.lime.opacity(0.55) : PUColor.hairline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var legal: some View {
        Text("Subscriptions renew automatically until cancelled. Manage or cancel any time in your Apple Account settings.")
            .font(.system(size: 11))
            .foregroundStyle(PUColor.textTertiary)
            .multilineTextAlignment(.center)
    }

    private var purchaseBar: some View {
        VStack(spacing: 8) {
            Button {
                purchase()
            } label: {
                if store.isPurchasing {
                    ProgressView().tint(PUColor.limeInk)
                } else {
                    Text("CONTINUE — \(selectedProduct.price)")
                }
            }
            .buttonStyle(PUPrimaryButtonStyle())
            .disabled(store.isPurchasing)

            Text("Free plan includes onboarding and your first full session.")
                .font(.system(size: 11))
                .foregroundStyle(PUColor.textTertiary)
        }
        .padding(.horizontal, PUMetrics.margin)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func purchase() {
        Task {
            let success = await store.purchase(selectedProduct)
            if success {
                appState.analytics.record(.subscriptionStarted, properties: ["product": selectedProduct.id])
                Haptics.success()
                showWelcome = true
            } else {
                message = store.lastError ?? "Purchase didn't complete."
            }
        }
    }

    private func restore() {
        Task {
            let restored = await store.restore()
            if restored {
                Haptics.success()
                dismiss()
            } else {
                message = store.lastError
            }
        }
    }
}
