import XCTest
@testable import MORT

final class SessionRoutingTests: XCTestCase {
    func testSignedOutWithoutUser() {
        XCTAssertEqual(SessionRouting.destination(hasUser: false, profile: nil), .signedOut)
    }

    func testMissingOrIncompleteProfileRoutesToOnboarding() {
        XCTAssertEqual(SessionRouting.destination(hasUser: true, profile: nil), .onboarding)
        XCTAssertEqual(SessionRouting.destination(hasUser: true, profile: profile(role: .teen, onboarded: false)), .onboarding)
        XCTAssertEqual(SessionRouting.destination(hasUser: true, profile: profile(role: nil, onboarded: true)), .onboarding)
    }

    func testCompletedProfilesRouteByRole() {
        for role in UserRole.allCases {
            XCTAssertEqual(SessionRouting.destination(hasUser: true, profile: profile(role: role)), .ready(role))
        }
    }

    func testRestrictedAccountNeverReachesRoleShell() {
        let restricted = profile(role: .adult, accountStatus: "restricted")
        XCTAssertEqual(SessionRouting.destination(hasUser: true, profile: restricted), .restricted("restricted"))
    }

    func testGuardianSkipDoesNotBlockCompletedTeenAccount() {
        let teen = profile(role: .teen, guardianStatus: "skipped")
        XCTAssertEqual(SessionRouting.destination(hasUser: true, profile: teen), .ready(.teen))
    }

    private func profile(
        role: UserRole?,
        onboarded: Bool = true,
        accountStatus: String = "active",
        guardianStatus: String = "skipped"
    ) -> Profile {
        Profile(
            id: UUID(), role: role, displayName: "Test User", username: "test_user",
            dob: "2010-01-01", city: "Indianapolis", state: "IN", locationSetupMode: "city_state",
            onboardingCompleted: onboarded, accountStatus: accountStatus,
            verificationStatus: "unverified", paymentPreference: "none",
            guardianSetupStatus: guardianStatus, avatarPath: nil,
            avatarModerationStatus: "none", bio: nil, availability: nil,
            preferredJobCategories: [], approximateArea: nil, goals: nil
        )
    }
}
