import XCTest
@testable import MORT

final class JobDraftTests: XCTestCase {
    func testPayloadNormalizesTextAndStateCode() {
        var draft = JobDraft()
        draft.title = "  Yard cleanup  "
        draft.summary = "  Bag leaves and branches safely.  "
        draft.description = "  Gather leaves, bag them, and place bags by the garage.  "
        draft.locationText = "  Near downtown  "
        draft.city = "  Indianapolis  "
        draft.state = "in"
        draft.equipmentProvided = "   "
        draft.safetyNotes = "  Gloves provided  "

        let payload = draft.payload
        XCTAssertEqual(payload.title, "Yard cleanup")
        XCTAssertEqual(payload.summary, "Bag leaves and branches safely.")
        XCTAssertEqual(payload.description, "Gather leaves, bag them, and place bags by the garage.")
        XCTAssertEqual(payload.locationText, "Near downtown")
        XCTAssertEqual(payload.city, "Indianapolis")
        XCTAssertEqual(payload.state, "IN")
        XCTAssertNil(payload.equipmentProvided)
        XCTAssertEqual(payload.safetyNotes, "Gloves provided")
    }

    func testGuardianApprovalDefaultsOffPerJob() {
        XCTAssertFalse(JobDraft().requiresGuardianApproval)
    }
}
