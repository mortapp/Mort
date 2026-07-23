import Foundation
import Supabase

protocol MonetizationRepositoryProtocol: Sendable {
    func backendEntitlements() async throws -> BackendEntitlements
    func recordPaywallEvent(type: String, placement: String, offeringID: String?, packageID: String?, productID: String?, errorMessage: String?) async throws
    func adEligibility(placement: String, format: String) async throws -> AdEligibility
    func recordAdImpression(placement: String, format: String, adUnitID: String?) async throws
    func recordFeatureUsage(featureKey: String, entitlementRequired: String?, allowed: Bool) async throws
    func subscriptionStatus() async throws -> SubscriptionStatus?
    func jobBoostStatus() async throws -> JobBoostStatus
    func consumeJobBoost(jobID: UUID) async throws -> BoostedJob
    func adPreferences() async throws -> AdPreferences?
    func saveAdPreferences(personalized: Bool, consentReady: Bool, ageRestricted: Bool) async throws
}

final class MonetizationRepository: SupabaseRepository, MonetizationRepositoryProtocol {
    func backendEntitlements() async throws -> BackendEntitlements {
        try await translated {
            let rows: [BackendEntitlements] = try await client.rpc("get_my_entitlements").execute().value
            return rows.first ?? .empty
        }
    }

    func recordPaywallEvent(type: String, placement: String, offeringID: String?, packageID: String?, productID: String?, errorMessage: String?) async throws {
        struct Params: Encodable {
            let p_event_type: String; let p_placement: String; let p_offering_id: String?
            let p_package_id: String?; let p_product_id: String?; let p_error_message: String?
        }
        try await translated {
            let _: UUID = try await client.rpc("record_paywall_event", params: Params(
                p_event_type: type, p_placement: placement, p_offering_id: offeringID,
                p_package_id: packageID, p_product_id: productID, p_error_message: errorMessage
            )).execute().value
        }
    }

    func adEligibility(placement: String, format: String) async throws -> AdEligibility {
        struct Params: Encodable { let p_placement: String; let p_ad_format: String }
        return try await translated {
            let rows: [AdEligibility] = try await client.rpc("get_ad_eligibility", params: Params(
                p_placement: placement, p_ad_format: format
            )).execute().value
            guard let result = rows.first else { throw MortError.invalidResponse }
            return result
        }
    }

    func recordAdImpression(placement: String, format: String, adUnitID: String?) async throws {
        struct Params: Encodable { let p_placement: String; let p_ad_format: String; let p_ad_unit_id: String? }
        try await translated {
            let _: UUID = try await client.rpc("record_ad_impression", params: Params(
                p_placement: placement, p_ad_format: format, p_ad_unit_id: adUnitID
            )).execute().value
        }
    }

    func recordFeatureUsage(featureKey: String, entitlementRequired: String?, allowed: Bool) async throws {
        struct Params: Encodable { let p_feature_key: String; let p_entitlement_required: String?; let p_allowed: Bool }
        try await translated {
            let _: UUID = try await client.rpc("record_feature_usage", params: Params(
                p_feature_key: featureKey, p_entitlement_required: entitlementRequired, p_allowed: allowed
            )).execute().value
        }
    }

    func subscriptionStatus() async throws -> SubscriptionStatus? {
        try await translated {
            let rows: [SubscriptionStatus] = try await client.from("user_subscription_status").select()
                .eq("user_id", value: try await currentUserID()).limit(1).execute().value
            return rows.first
        }
    }

    func jobBoostStatus() async throws -> JobBoostStatus {
        try await translated {
            let rows: [JobBoostStatus] = try await client.rpc("get_job_boost_credit_status").execute().value
            return rows.first ?? .empty
        }
    }

    func consumeJobBoost(jobID: UUID) async throws -> BoostedJob {
        struct Params: Encodable { let p_job_id: UUID }
        return try await translated {
            try await client.rpc("consume_job_boost_credit", params: Params(p_job_id: jobID)).execute().value
        }
    }

    func adPreferences() async throws -> AdPreferences? {
        try await translated {
            let rows: [AdPreferences] = try await client.from("user_ad_preferences").select()
                .eq("user_id", value: try await currentUserID()).limit(1).execute().value
            return rows.first
        }
    }

    func saveAdPreferences(personalized: Bool, consentReady: Bool, ageRestricted: Bool) async throws {
        struct Input: Encodable {
            let user_id: UUID; let personalized_ads_allowed: Bool; let ads_consent_ready: Bool
            let age_restricted_ads: Bool; let last_prompted_at: String
        }
        try await translated {
            try await client.from("user_ad_preferences").upsert(Input(
                user_id: try await currentUserID(), personalized_ads_allowed: personalized,
                ads_consent_ready: consentReady, age_restricted_ads: ageRestricted,
                last_prompted_at: Date().iso8601String
            )).execute()
        }
    }
}

