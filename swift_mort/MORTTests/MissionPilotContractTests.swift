import XCTest
@testable import MORT

final class MissionPilotContractTests: XCTestCase {
    func testClosedPilotTruthContract() throws {
        let data = Data("""
        {
          "allowed": false,
          "code": "closed_pilot_requirements_missing",
          "missing_requirements": ["approved_partner_enrollment"],
          "reason_codes": ["pilot_enrollment_missing"],
          "policy_version": 1,
          "pilot_mode_enabled": true,
          "unrestricted_public_access_enabled": false,
          "real_document_collection_enabled": false,
          "guardian_mode_optional": true,
          "guardian_connection_required": false,
          "permanent_address_required": false,
          "housing_status_collected": false,
          "support_circle_affects_eligibility": false
        }
        """.utf8)

        let result = try JSONDecoder().decode(ClosedPilotEligibility.self, from: data)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.guardianModeOptional == true)
        XCTAssertFalse(result.guardianConnectionRequired == true)
        XCTAssertFalse(result.permanentAddressRequired == true)
        XCTAssertFalse(result.realDocumentCollectionEnabled == true)
    }

    func testDocumentCollectionCannotBeEnabledByClient() throws {
        let data = Data("""
        {
          "ready": false,
          "real_document_collection_enabled": false,
          "client_can_enable": false,
          "collection_status": "disabled_until_operational_readiness",
          "required_gate_count": 18,
          "passed_gate_count": 0,
          "remaining_gate_keys": ["legal_privacy_review"],
          "truth_statement": "Visual review does not by itself prove legal identity."
        }
        """.utf8)

        let result = try JSONDecoder().decode(DocumentCollectionReadiness.self, from: data)
        XCTAssertFalse(result.ready)
        XCTAssertFalse(result.realDocumentCollectionEnabled)
        XCTAssertFalse(result.clientCanEnable)
        XCTAssertEqual(result.requiredGateCount, 18)
    }

    func testNoAddressProfileCountsLocationSetupWithoutHousingStatus() throws {
        let profile = Profile(
            id: UUID(), role: .teen, displayName: "Pilot Teen", username: "pilot_teen",
            dob: "2010-01-01", city: nil, state: nil, locationSetupMode: "partner_supported",
            onboardingCompleted: true, accountStatus: "active", verificationStatus: "unverified",
            paymentPreference: "none", guardianSetupStatus: "skipped", avatarPath: nil,
            avatarModerationStatus: "none", bio: nil, availability: nil,
            preferredJobCategories: [], approximateArea: nil, goals: nil
        )

        XCTAssertNil(profile.city)
        XCTAssertNil(profile.state)
        XCTAssertEqual(profile.locationSetupMode, "partner_supported")
        XCTAssertGreaterThan(profile.completionRatio, 0)
    }
}
