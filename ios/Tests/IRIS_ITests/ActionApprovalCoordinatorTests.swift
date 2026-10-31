//
//  ActionApprovalCoordinatorTests.swift
//  IRIS_ITests
//
//  Verifies cryptographic confirmation tickets, parameter binding,
//  and centralized ActionApprovalCoordinator state management.
//

import XCTest
@testable import IRIS_I

final class ActionApprovalCoordinatorTests: XCTestCase {

    @MainActor
    func testTicketPresentationAndRejection() {
        let coordinator = ActionApprovalCoordinator.shared
        let ticket = ConfirmationTicket(
            toolName: "MessagingTool",
            operationType: .send,
            parameters: ["message": "Test Message", "recipient": "John Doe"]
        )

        coordinator.requestApproval(ticket: ticket)
        XCTAssertTrue(coordinator.isPresentingApproval)
        XCTAssertEqual(coordinator.activeTicket?.ticketId, ticket.ticketId)

        coordinator.reject(ticket: ticket)
        XCTAssertFalse(coordinator.isPresentingApproval)
        XCTAssertNil(coordinator.activeTicket)
    }

    func testDigestCalculationMatchesParameters() {
        let params: [String: Any] = ["action": "open", "target": "camera"]
        let digest1 = ConfirmationTicket.computeDigest(params)
        let digest2 = ConfirmationTicket.computeDigest(params)

        XCTAssertEqual(digest1, digest2)

        let alteredParams: [String: Any] = ["action": "open", "target": "youtube"]
        let alteredDigest = ConfirmationTicket.computeDigest(alteredParams)
        XCTAssertNotEqual(digest1, alteredDigest)
    }
}
