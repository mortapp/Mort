import XCTest
@testable import MORT

final class ValidationAndErrorsTests: XCTestCase {
    func testCredentialValidation() {
        XCTAssertNotNil(MortValidators.email("not-an-email"))
        XCTAssertNil(MortValidators.email("teen@example.com"))
        XCTAssertNotNil(MortValidators.password("short"))
        XCTAssertNil(MortValidators.password("LongEnough9"))
        XCTAssertNil(MortValidators.stateCode("IN"))
        XCTAssertNotNil(MortValidators.stateCode("Indiana"))
    }

    func testStructuredBackendErrorsRemainUseful() {
        XCTAssertEqual(
            BackendErrorTranslator.message(for: "guardian_approval_required"),
            "This job requires guardian approval. Link a guardian or choose another job."
        )
        XCTAssertEqual(
            BackendErrorTranslator.message(for: "proof_required"),
            "This job requires proof before it can be marked complete."
        )
        XCTAssertEqual(
            BackendErrorTranslator.message(for: "rate_limit_exceeded"),
            "Too many attempts. Wait a moment and try again."
        )
    }

    func testUnknownBackendCodeUsesSafeFallback() {
        XCTAssertEqual(BackendErrorTranslator.message(for: "new_server_code", fallback: "Server supplied detail"), "Server supplied detail")
        XCTAssertEqual(BackendErrorTranslator.message(for: "new_server_code"), "We could not complete that action. Refresh and try again.")
    }

    func testMessageScannerStateParsing() {
        let blocked = message(status: "blocked")
        let flagged = message(status: "flagged")
        let clean = message(status: "clean")
        XCTAssertTrue(blocked.isBlocked)
        XCTAssertTrue(flagged.isFlagged)
        XCTAssertFalse(clean.isBlocked)
        XCTAssertFalse(clean.isFlagged)
    }

    private func message(status: String) -> MortMessage {
        MortMessage(
            id: UUID(), threadID: UUID(), senderID: UUID(), body: "Test",
            scannerStatus: status, scannerReason: nil, createdAt: nil
        )
    }
}
