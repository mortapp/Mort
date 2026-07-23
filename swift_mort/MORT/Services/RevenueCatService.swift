import Foundation
import Observation
import RevenueCat

enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    case cancelled
    case restored
}

@MainActor
@Observable
final class RevenueCatService {
    private let publicAPIKey: String?
    private(set) var isConfigured = false
    private(set) var identifiedUserID: UUID?
    private(set) var offerings: Offerings?
    private(set) var customerInfo: CustomerInfo?
    private(set) var entitlementState = EntitlementState()
    private(set) var isLoading = false
    private(set) var lastError: MortError?

    init(publicAPIKey: String?) {
        self.publicAPIKey = publicAPIKey?.nilIfBlank
    }

    func configure(userID: UUID) async throws {
        guard let publicAPIKey else {
            throw MortError.featureUnavailable("RevenueCat's public iOS SDK key is not configured for this build.")
        }

        if !Purchases.isConfigured {
            #if DEBUG
            Purchases.logLevel = .debug
            #else
            Purchases.logLevel = .warn
            #endif
            Purchases.configure(withAPIKey: publicAPIKey, appUserID: userID.uuidString.lowercased())
            isConfigured = true
            identifiedUserID = userID
        } else if identifiedUserID != userID {
            let result = try await Purchases.shared.logIn(userID.uuidString.lowercased())
            customerInfo = result.customerInfo
            identifiedUserID = userID
            isConfigured = true
        }

        try await refresh()
    }

    func refresh() async throws {
        guard Purchases.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let info = Purchases.shared.customerInfo()
            async let availableOfferings = Purchases.shared.offerings()
            let (newInfo, newOfferings) = try await (info, availableOfferings)
            customerInfo = newInfo
            offerings = newOfferings
            entitlementState = Self.mapEntitlements(newInfo)
            lastError = nil
        } catch {
            let translated = BackendErrorTranslator.translate(error)
            lastError = translated
            throw translated
        }
    }

    func offering(identifier: String?) -> Offering? {
        guard let offerings else { return nil }
        if let identifier, let selected = offerings.offering(identifier: identifier) { return selected }
        return offerings.current
    }

    func packages(offeringID: String?) -> [Package] {
        offering(identifier: offeringID)?.availablePackages ?? []
    }

    func purchase(_ package: Package) async throws -> PurchaseOutcome {
        guard Purchases.isConfigured else {
            throw MortError.featureUnavailable("Purchases are not configured for this build.")
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            customerInfo = result.customerInfo
            entitlementState = Self.mapEntitlements(result.customerInfo)
            lastError = nil
            return result.userCancelled ? .cancelled : .purchased
        } catch {
            let translated = BackendErrorTranslator.translate(error)
            lastError = translated
            throw translated
        }
    }

    func restore() async throws -> PurchaseOutcome {
        guard Purchases.isConfigured else {
            throw MortError.featureUnavailable("Purchases are not configured for this build.")
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            customerInfo = info
            entitlementState = Self.mapEntitlements(info)
            lastError = nil
            return .restored
        } catch {
            let translated = BackendErrorTranslator.translate(error)
            lastError = translated
            throw translated
        }
    }

    func logOut() async {
        guard Purchases.isConfigured, identifiedUserID != nil else { return }
        do {
            _ = try await Purchases.shared.logOut()
        } catch {
            lastError = BackendErrorTranslator.translate(error)
        }
        identifiedUserID = nil
        customerInfo = nil
        offerings = nil
        entitlementState = EntitlementState()
    }

    static func mapEntitlements(_ info: CustomerInfo) -> EntitlementState {
        let active = Set(info.entitlements.active.keys.compactMap(MortEntitlement.init(rawValue:)))
        return EntitlementState(active: active)
    }
}

