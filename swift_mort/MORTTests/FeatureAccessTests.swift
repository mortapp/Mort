import XCTest
@testable import MORT

final class FeatureAccessTests: XCTestCase {
    func testSafetyAndBasicMarketplaceFeaturesAreAlwaysFree() {
        let access = FeatureAccess(state: EntitlementState(), adsEnabled: true)
        XCTAssertTrue(access.safetyToolsFree)
        XCTAssertTrue(access.basicApplyingFree)
        XCTAssertTrue(access.basicGuardianModeFree)
        XCTAssertTrue(access.proofUploadFree)
    }

    func testAdFreeAndPlusSuppressEligibleAds() {
        let adFree = FeatureAccess(state: EntitlementState(active: [.adFree]), adsEnabled: true)
        let plus = FeatureAccess(state: EntitlementState(active: [.plus]), adsEnabled: true)
        XCTAssertFalse(adFree.canShowAds)
        XCTAssertFalse(plus.canShowAds)
        XCTAssertTrue(plus.state.isPlus)
    }

    func testRoleSpecificEntitlementsDoNotUnlockSafety() {
        let state = EntitlementState(active: [.adultPro, .guardianPlus, .jobBoost])
        let access = FeatureAccess(state: state, adsEnabled: false)
        XCTAssertTrue(access.canUseAdultApplicantSorting)
        XCTAssertTrue(access.canUseGuardianWeeklyDigest)
        XCTAssertTrue(state.hasJobBoost)
        XCTAssertTrue(access.safetyToolsFree)
    }
}
