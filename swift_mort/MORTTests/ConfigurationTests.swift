import XCTest
@testable import MORT

final class ConfigurationTests: XCTestCase {
    func testLoadsOnlyClientSafeConfigurationContract() throws {
        let configuration = try AppConfiguration.load(environment: [
            "MORT_SUPABASE_URL": "https://example.supabase.co",
            "MORT_SUPABASE_ANON_KEY": "public-client-key",
            "MORT_REVENUECAT_IOS_API_KEY": "public-ios-sdk-key",
            "MORT_ADS_ENABLED": "false",
            "MORT_USE_TEST_ADS": "true",
        ])
        XCTAssertEqual(configuration.supabaseURL.absoluteString, "https://example.supabase.co")
        XCTAssertEqual(configuration.supabaseAnonKey, "public-client-key")
        XCTAssertFalse(configuration.adsEnabled)
        XCTAssertTrue(configuration.useTestAds)
    }

    func testRejectsMissingAndNonHTTPSSupabaseURL() {
        XCTAssertThrowsError(try AppConfiguration.load(environment: ["MORT_SUPABASE_ANON_KEY": "public-client-key"]))
        XCTAssertThrowsError(try AppConfiguration.load(environment: [
            "MORT_SUPABASE_URL": "http://localhost:54321",
            "MORT_SUPABASE_ANON_KEY": "public-client-key",
        ]))
    }
}
