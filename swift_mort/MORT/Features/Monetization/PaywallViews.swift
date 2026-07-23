import RevenueCat
import RevenueCatUI
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DependencyContainer.self) private var container
    @Environment(RevenueCatService.self) private var revenueCat
    @State private var backendEntitlements = BackendEntitlements.empty
    @State private var isWorking = false
    @State private var message: String?
    @State private var trackingWarning: String?
    let offeringID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: MortSpacing.xs) {
                        Text("OPTIONAL PERKS").font(MortTypography.caption).foregroundStyle(MortColors.premium)
                        Text("Make MORT yours.").font(MortTypography.title)
                    }
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }
                        .accessibilityLabel("Close paywall")
                }
                Text("Free stays useful. Plus just gives you extra style, control, and convenience.")
                    .foregroundStyle(MortColors.textMuted)
                freePromise
                if revenueCat.isLoading || isWorking {
                    ProgressView().tint(MortColors.premium)
                }
                packageList
                HStack(spacing: MortSpacing.sm) {
                    MortSecondaryButton(title: "Restore purchases", icon: "arrow.clockwise") { Task { await restore() } }
                    MortSecondaryButton(title: "Manage subscription", icon: "person.crop.circle.badge.checkmark") { container.router.push(.customerCenter) }
                }
                Text("Prices, billing period, renewal terms, and availability come from Apple through RevenueCat. MORT does not hardcode a purchase price as final store truth.")
                    .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                if let trackingWarning {
                    Text(trackingWarning).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("MORT perks")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Purchases", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private var freePromise: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                Label("Safety tools stay free", systemImage: "shield.fill")
                Label("Basic job applying stays free", systemImage: "briefcase.fill")
                Label("Guardian Mode basics stay free", systemImage: "person.2.fill")
                Label("Report, block, and Safety Ping stay free", systemImage: "hand.raised.fill")
            }
            .font(MortTypography.label)
            .foregroundStyle(MortColors.textSoft)
        }
    }

    @ViewBuilder
    private var packageList: some View {
        let packages = revenueCat.packages(offeringID: offeringID)
        if !revenueCat.isConfigured {
            MortAlertBanner(title: "Store setup required", message: "Add the public RevenueCat iOS SDK key in the Mac build configuration. No secret key belongs in this app.")
        } else if packages.isEmpty {
            MortEmptyState(title: "No packages available", message: "The selected RevenueCat offering has no App Store packages for this build.", systemImage: "cart")
                .frame(minHeight: 180)
        } else {
            ForEach(packages, id: \.identifier) { package in
                PackageCard(package: package, isWorking: isWorking) { Task { await purchase(package) } }
            }
        }
    }

    private func load() async {
        do { try await revenueCat.refresh() }
        catch { message = mortMessage(error) }
        do { backendEntitlements = try await container.monetization.backendEntitlements() }
        catch { trackingWarning = "Backend entitlement status could not be refreshed yet." }
        await record(type: "viewed", package: nil, error: nil)
    }

    private func purchase(_ package: Package) async {
        isWorking = true
        defer { isWorking = false }
        await record(type: "purchase_started", package: package, error: nil)
        do {
            let outcome = try await revenueCat.purchase(package)
            switch outcome {
            case .purchased:
                await record(type: "purchase_completed", package: package, error: nil)
                message = "Purchase confirmed by Apple. Entitlements will refresh through RevenueCat and the backend webhook."
            case .cancelled:
                await record(type: "purchase_cancelled", package: package, error: nil)
            case .restored:
                message = "Purchases restored."
            }
        } catch {
            await record(type: "purchase_failed", package: package, error: mortMessage(error))
            message = mortMessage(error)
        }
    }

    private func restore() async {
        isWorking = true
        defer { isWorking = false }
        do { _ = try await revenueCat.restore(); message = "Purchases restored and entitlements refreshed." }
        catch { message = mortMessage(error) }
    }

    private func record(type: String, package: Package?, error: String?) async {
        do {
            try await container.monetization.recordPaywallEvent(
                type: type,
                placement: offeringID ?? "default",
                offeringID: revenueCat.offering(identifier: offeringID)?.identifier,
                packageID: package?.identifier,
                productID: package?.storeProduct.productIdentifier,
                errorMessage: error
            )
        } catch { trackingWarning = "The optional paywall analytics event could not be recorded." }
    }
}

private struct PackageCard: View {
    let package: Package
    let isWorking: Bool
    let purchase: () -> Void

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                        Text(productTitle).font(MortTypography.section)
                        Text(perkDescription).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                    }
                    Spacer()
                    Text(package.localizedPriceString).font(MortTypography.section).foregroundStyle(MortColors.premium)
                }
                Button("Choose \(productTitle)", action: purchase)
                    .font(MortTypography.label)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .buttonStyle(.borderedProminent)
                    .tint(MortColors.premium)
                    .disabled(isWorking)
            }
        }
    }

    private var productTitle: String {
        let value = package.storeProduct.productIdentifier
        switch value {
        case "mort_plus_monthly": "MORT Plus Monthly"
        case "mort_plus_yearly": "MORT Plus Yearly"
        case "mort_plus_lifetime": "MORT Lifetime"
        case "mort_ad_free_lifetime": "Ad-Free"
        case "mort_username_change_token_1": "Username Change Token"
        case "mort_profile_style_pack": "Profile Style Pack"
        case "mort_adult_pro_monthly": "Adult Pro"
        case "mort_guardian_plus_monthly": "Guardian Plus"
        case "mort_job_boost_1": "Job Boost"
        default: package.storeProduct.localizedTitle
        }
    }

    private var perkDescription: String {
        switch package.storeProduct.productIdentifier {
        case "mort_ad_free_lifetime": "Hide eligible ads. Safety notices and core tools are unaffected."
        case "mort_username_change_token_1": "One optional username change credit after free allowances."
        case "mort_profile_style_pack": "Optional profile style choices."
        case "mort_adult_pro_monthly": "Convenience tools for adult and business job review."
        case "mort_guardian_plus_monthly": "Optional Guardian Mode digest conveniences."
        case "mort_job_boost_1": "One visibility credit that never bypasses moderation or verification."
        default: "Extra style, control, and convenience while the free app stays useful."
        }
    }
}

struct CustomerCenterScreen: View {
    @Environment(RevenueCatService.self) private var revenueCat

    var body: some View {
        Group {
            if revenueCat.isConfigured {
                CustomerCenterView()
            } else {
                UnavailableFeatureView(title: "Manage subscription", reason: "RevenueCat's public iOS SDK key is not configured for this build.")
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .mortScreen()
    }
}
