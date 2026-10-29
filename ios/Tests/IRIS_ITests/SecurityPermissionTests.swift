//
//  SecurityPermissionTests.swift
//  IRIS_ITests
//
//  Verifies single-use ticket lifecycle, replay protection, and parameter tampering prevention.
//

import XCTest
@testable import IRIS_ICore

final class SecurityPermissionTests: XCTestCase {

    func testTicketIssuanceAndDigestVerification() async throws {
        let manager = ConfirmationManager()
        let params: [String: Any] = ["action": "delete_all", "scope": "events"]

        let ticket = await manager.issueTicket(for: "EventKitTool", parameters: params)
        XCTAssertFalse(ticket.ticketId.isEmpty)
        XCTAssertFalse(ticket.isConsumed)
        XCTAssertFalse(ticket.isExpired)

        // Valid consumption
        let consumed = try await manager.validateAndConsume(ticketId: ticket.ticketId, parameters: params)
        XCTAssertTrue(consumed.isConsumed)
    }

    func testReplayAttackPrevention() async throws {
        let manager = ConfirmationManager()
        let params: [String: Any] = ["amount": 100]

        let ticket = await manager.issueTicket(for: "PaymentTool", parameters: params)

        // First execution succeeds
        _ = try await manager.validateAndConsume(ticketId: ticket.ticketId, parameters: params)

        // Replay attempt fails immediately
        do {
            _ = try await manager.validateAndConsume(ticketId: ticket.ticketId, parameters: params)
            XCTFail("Replay of consumed ticket must throw ConfirmationError.alreadyConsumed")
        } catch let err as ConfirmationError {
            XCTAssertEqual(err, .alreadyConsumed)
        }
    }

    func testParameterTamperingPostApprovalThrows() async throws {
        let manager = ConfirmationManager()
        let originalParams: [String: Any] = ["recipient": "Alice", "message": "Hello"]
        let tamperedParams: [String: Any] = ["recipient": "Mallory", "message": "Transfer All"]

        let ticket = await manager.issueTicket(for: "MessagingTool", parameters: originalParams)

        // Attempt to execute with altered parameters
        do {
            _ = try await manager.validateAndConsume(ticketId: ticket.ticketId, parameters: tamperedParams)
            XCTFail("Parameter tampering must be caught by SHA-256 digest check")
        } catch let err as ConfirmationError {
            XCTAssertEqual(err, .parameterMismatch)
        }
    }
}

