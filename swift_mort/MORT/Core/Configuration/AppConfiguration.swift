import Foundation

struct AppConfiguration: Sendable {
    let supabaseURL: URL
    let supabaseAnonKey: String
    let revenueCatIOSAPIKey: String?
    let admobAppID: String?
    let admobBannerID: String?
    let admobRewardedID: String?
    let adsEnabled: Bool
    let useTestAds: Bool

    static func load(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> AppConfiguration {
        let urlValue = try requiredValue(
            environmentName: "MORT_SUPABASE_URL",
            plistName: "MORTSupabaseURL",
            bundle: bundle,
            environment: environment
        )
        guard let url = URL(string: urlValue), url.scheme == "https" else {
            throw ConfigurationError.invalidValue("MORT_SUPABASE_URL must be an HTTPS URL.")
        }

        let anonKey = try requiredValue(
            environmentName: "MORT_SUPABASE_ANON_KEY",
            plistName: "MORTSupabaseAnonKey",
            bundle: bundle,
            environment: environment
        )

        return AppConfiguration(
            supabaseURL: url,
            supabaseAnonKey: anonKey,
            revenueCatIOSAPIKey: optionalValue(
                environmentName: "MORT_REVENUECAT_IOS_API_KEY",
                plistName: "MORTRevenueCatIOSAPIKey",
                bundle: bundle,
                environment: environment
            ),
            admobAppID: optionalValue(
                environmentName: "MORT_ADMOB_APP_ID",
                plistName: "GADApplicationIdentifier",
                bundle: bundle,
                environment: environment
            ),
            admobBannerID: optionalValue(
                environmentName: "MORT_ADMOB_BANNER_ID",
                plistName: "MORTAdMobBannerID",
                bundle: bundle,
                environment: environment
            ),
            admobRewardedID: optionalValue(
                environmentName: "MORT_ADMOB_REWARDED_ID",
                plistName: "MORTAdMobRewardedID",
                bundle: bundle,
                environment: environment
            ),
            adsEnabled: boolValue(
                environmentName: "MORT_ADS_ENABLED",
                plistName: "MORTAdsEnabled",
                defaultValue: false,
                bundle: bundle,
                environment: environment
            ),
            useTestAds: boolValue(
                environmentName: "MORT_USE_TEST_ADS",
                plistName: "MORTUseTestAds",
                defaultValue: true,
                bundle: bundle,
                environment: environment
            )
        )
    }

    private static func requiredValue(
        environmentName: String,
        plistName: String,
        bundle: Bundle,
        environment: [String: String]
    ) throws -> String {
        guard let value = optionalValue(
            environmentName: environmentName,
            plistName: plistName,
            bundle: bundle,
            environment: environment
        ) else {
            throw ConfigurationError.missingValue(environmentName)
        }
        return value
    }

    private static func optionalValue(
        environmentName: String,
        plistName: String,
        bundle: Bundle,
        environment: [String: String]
    ) -> String? {
        let raw = environment[environmentName] ?? bundle.object(forInfoDictionaryKey: plistName) as? String
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              !value.contains("$(")
        else { return nil }
        return value
    }

    private static func boolValue(
        environmentName: String,
        plistName: String,
        defaultValue: Bool,
        bundle: Bundle,
        environment: [String: String]
    ) -> Bool {
        if let text = optionalValue(
            environmentName: environmentName,
            plistName: plistName,
            bundle: bundle,
            environment: environment
        ) {
            return ["1", "true", "yes"].contains(text.lowercased())
        }
        if let value = bundle.object(forInfoDictionaryKey: plistName) as? Bool {
            return value
        }
        return defaultValue
    }
}

enum ConfigurationError: LocalizedError, Equatable {
    case missingValue(String)
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case let .missingValue(name):
            return "Missing build configuration: \(name)."
        case let .invalidValue(message):
            return message
        }
    }
}
