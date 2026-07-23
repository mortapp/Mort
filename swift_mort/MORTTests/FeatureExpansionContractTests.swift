import XCTest
@testable import MORT

final class FeatureExpansionContractTests: XCTestCase {
    func testUnreadCountIsNeverNegative() {
        let thread = MessageThread(
            id: UUID(),
            jobID: nil,
            applicationID: nil,
            teenID: nil,
            adultID: nil,
            guardianID: nil,
            updatedAt: nil,
            unreadCount: -2
        )

        XCTAssertEqual(thread.unread, 0)
    }

    func testProofStatusUsesClearLanguage() {
        let proof = ProofUpload(
            id: UUID(),
            applicationID: UUID(),
            uploadedBy: UUID(),
            storagePath: "teen/proof.jpg",
            note: nil,
            status: "resubmission_requested",
            reviewedBy: nil,
            reviewNote: "Show the completed work area.",
            reviewedAt: nil,
            createdAt: nil,
            updatedAt: nil
        )

        XCTAssertEqual(proof.statusTitle, "New proof requested")
    }

    func testProofApprovalErrorExplainsNextStep() {
        XCTAssertEqual(
            BackendErrorTranslator.message(for: "proof_approval_required"),
            "Approve the submitted proof before marking this job complete."
        )
    }
}
