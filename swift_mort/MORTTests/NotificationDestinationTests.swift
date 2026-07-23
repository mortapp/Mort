import XCTest
@testable import MORT

final class NotificationDestinationTests: XCTestCase {
    private let threadID = UUID()
    private let applicationID = UUID()
    private let jobID = UUID()

    func testMessagePayloadOpensThread() {
        XCTAssertEqual(resolve(["threadId": value(threadID)], role: .teen), .messageThread(threadID))
    }

    func testApplicationPayloadUsesSignedInRole() {
        let payload = ["applicationId": value(applicationID), "jobId": value(jobID)]
        XCTAssertEqual(resolve(payload, role: .teen), .applicationDetail(applicationID, .teen))
        XCTAssertEqual(resolve(payload, role: .adult), .applicationDetail(applicationID, .adult))
        XCTAssertEqual(resolve(payload, role: .guardian), .applicationDetail(applicationID, .guardian))
        XCTAssertEqual(resolve(payload, role: .admin), .activity)
    }

    func testAdminPayloadsOpenAuthorizedQueues() {
        XCTAssertEqual(resolve(["supportTicketId": value(jobID)], role: .admin), .adminQueue(.support))
        XCTAssertEqual(resolve(["reportId": value(jobID), "targetJobId": value(jobID)], role: .admin), .adminQueue(.reports))
        XCTAssertEqual(resolve(["safetyPingId": value(jobID)], role: .admin), .adminQueue(.safetyPings))
        XCTAssertEqual(resolve(["reviewId": value(jobID)], role: .admin), .adminQueue(.reviews))
    }

    func testRolePayloadsOpenSafeDestinations() {
        XCTAssertEqual(resolve(["supportTicketId": value(jobID)], role: .teen), .support)
        XCTAssertEqual(resolve(["guardianLinkId": value(jobID)], role: .guardian), .guardianMode)
        XCTAssertEqual(resolve(["reviewId": value(jobID), "jobId": value(jobID)], role: .adult), .reviews)
        XCTAssertEqual(resolve(["jobId": value(jobID)], role: .teen), .jobDetail(jobID))
        XCTAssertEqual(resolve(["safetyPingId": value(jobID)], role: .guardian), .guardianSafetyPings)
    }

    func testBothVerificationPayloadVariantsResolve() {
        XCTAssertEqual(resolve(["verificationId": value(jobID)], role: .adult), .verification)
        XCTAssertEqual(resolve(["verificationStatus": .string("approved")], role: .adult), .verification)
        XCTAssertEqual(resolve(["verificationStatus": .string("pending")], role: .admin), .adminQueue(.verifications))
    }

    func testUnknownOrMalformedPayloadFallsBackToActivity() {
        XCTAssertEqual(resolve([:], role: .teen), .activity)
        XCTAssertEqual(resolve(["applicationId": .string("not-a-uuid")], role: .teen), .activity)
        XCTAssertEqual(resolve(["supportTicketId": .null], role: .teen), .activity)
    }

    func testNotificationURLUsesTheSameTypedResolver() throws {
        let url = try XCTUnwrap(URL(string: "mort://notifications?threadId=\(threadID.uuidString)"))
        XCTAssertEqual(
            NotificationDestinationResolver.linkResolution(for: url, role: .teen),
            .destination(.messageThread(threadID))
        )
    }

    func testAuthURLIsNotConsumedAsNotificationNavigation() throws {
        let url = try XCTUnwrap(URL(string: "mort://auth/recovery?code=client-safe-test-value"))
        XCTAssertEqual(NotificationDestinationResolver.linkResolution(for: url, role: .teen), .notNotification)
    }

    private func resolve(_ data: [String: JSONValue], role: UserRole?) -> AppRoute {
        NotificationDestinationResolver.destination(for: data, role: role)
    }

    private func value(_ id: UUID) -> JSONValue {
        .string(id.uuidString)
    }
}
