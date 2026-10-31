//
//  ActionApprovalCoordinatorTests.swift
//  IRIS_ITests
//
//  Verifies cryptographic confirmation tickets, parameter binding,
//  centralized ActionApprovalCoordinator state management, queued approvals,
//  and cancellation safety.
//

import XCTest
@testable import IRIS_I

final class ActionApprovalCoordinatorTests: XCTestCase {

    @MainActor
    override func setUp() {
        super.setUp()
        ActionApprovalCoordinator.shared.resetForTesting()
    }

    @MainActor
    override func tearDown() {
        ActionApprovalCoordinator.shared.resetForTesting()
        super.tearDown()
    }

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

    @MainActor
    func testQueuedApprovalsSequentialPresentation() {
        let coordinator = ActionApprovalCoordinator.shared

        let ticket1 = ConfirmationTicket(
            toolName: "MessagingTool",
            operationType: .send,
            parameters: ["message": "First"]
        )
        let ticket2 = ConfirmationTicket(
            toolName: "MessagingTool",
            operationType: .send,
            parameters: ["message": "Second"]
        )

        coordinator.requestApproval(ticket: ticket1)
        coordinator.requestApproval(ticket: ticket2)

        // Ticket 1 should be active immediately
        XCTAssertEqual(coordinator.activeTicket?.ticketId, ticket1.ticketId)

        // Reject ticket 1
        coordinator.reject(ticket: ticket1)
        XCTAssertNil(coordinator.activeTicket)

        // Wait for ticket 2 to be presented
        let exp = expectation(description: "Ticket 2 presented")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(coordinator.activeTicket?.ticketId, ticket2.ticketId)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    @MainActor
    func testCancelAllQueuedResumesContinuations() async {
        let coordinator = ActionApprovalCoordinator.shared

        let ticket = ConfirmationTicket(
            toolName: "PhoneCallTool",
            operationType: .send,
            parameters: ["recipient": "Alice"]
        )

        let task = Task {
            try await coordinator.requestApprovalAsync(ticket: ticket)
        }

        // Give continuation a tick to register
        try? await Task.sleep(nanoseconds: 20_000_000)

        coordinator.cancelAllQueued(reason: "User cancelled all")

        do {
            _ = try await task.value
            XCTFail("Expected cancellation error to be thrown")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, 499)
            XCTAssertEqual(nsError.domain, "IRIS.ActionApproval")
        }

        XCTAssertFalse(coordinator.isPresentingApproval)
        XCTAssertNil(coordinator.activeTicket)
    }
}
