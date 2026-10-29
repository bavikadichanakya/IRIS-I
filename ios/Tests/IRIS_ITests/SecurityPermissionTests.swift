//
//  SecurityPermissionTests.swift
//  IRIS_ITests
//
//  Verifies single-use ticket lifecycle, replay protection, parameter tampering prevention,
//  expiration handling, and operation-type permission evaluations.
//

import XCTest
@testable import IRIS_ICore

final class SecurityPermissionTests: XCTestCase {

    func testTicketIssuanceAndDigestVerification() async throws {
        let manager = ConfirmationManager()
        let params: [String: Any] = ["action": "delete_all", "scope": "events"]

        let ticket = await manager.issueTicket(for: "EventKitTool", operationType: .destructive, parameters: params)
        XCTAssertFalse(ticket.ticketId.isEmpty)
        XCTAssertFalse(ticket.isConsumed)
        XCTAssertFalse(ticket.isExpired)

        // Valid consumption
        let consumed = try await manager.validateAndConsume(ticketId: ticket.ticketId, toolName: "EventKitTool", parameters: params)
        XCTAssertTrue(consumed.isConsumed)
    }

    func testReplayAttackPrevention() async throws {
        let manager = ConfirmationManager()
        let params: [String: Any] = ["amount": 100]

        let ticket = await manager.issueTicket(for: "PaymentTool", operationType: .send, parameters: params)

        // First execution succeeds
        _ = try await manager.validateAndConsume(ticketId: ticket.ticketId, toolName: "PaymentTool", parameters: params)

        // Replay attempt fails immediately
        do {
            _ = try await manager.validateAndConsume(ticketId: ticket.ticketId, toolName: "PaymentTool", parameters: params)
            XCTFail("Replay of consumed ticket must throw ConfirmationError.alreadyConsumed")
        } catch let err as ConfirmationError {
            XCTAssertEqual(err, .alreadyConsumed)
        }
    }

    func testParameterTamperingPostApprovalThrows() async throws {
        let manager = ConfirmationManager()
        let originalParams: [String: Any] = ["recipient": "alice@example.com", "subject": "Hello"]
        let tamperedParams: [String: Any] = ["recipient": "mallory@attacker.com", "subject": "Transfer Funds"]

        let ticket = await manager.issueTicket(for: "MailTool", operationType: .send, parameters: originalParams)

        // Attempt to execute with altered parameters
        do {
            _ = try await manager.validateAndConsume(ticketId: ticket.ticketId, toolName: "MailTool", parameters: tamperedParams)
            XCTFail("Parameter tampering must be caught by SHA-256 digest check")
        } catch let err as ConfirmationError {
            XCTAssertEqual(err, .parameterMismatch)
        }
    }

    func testToolMismatchThrows() async throws {
        let manager = ConfirmationManager()
        let params: [String: Any] = ["action": "clear"]

        let ticket = await manager.issueTicket(for: "EventKitTool", operationType: .destructive, parameters: params)

        do {
            _ = try await manager.validateAndConsume(ticketId: ticket.ticketId, toolName: "SystemInfoTool", parameters: params)
            XCTFail("Tool mismatch must throw ConfirmationError.toolMismatch")
        } catch let err as ConfirmationError {
            if case .toolMismatch(let expected, let actual) = err {
                XCTAssertEqual(expected, "EventKitTool")
                XCTAssertEqual(actual, "SystemInfoTool")
            } else {
                XCTFail("Unexpected error: \(err)")
            }
        }
    }

    func testExpiredTicketThrows() async throws {
        let manager = ConfirmationManager()
        let params: [String: Any] = ["test": "val"]

        // Issue ticket with negative TTL (already expired)
        let ticket = await manager.issueTicket(for: "TestTool", parameters: params, ttl: -10.0)
        XCTAssertTrue(ticket.isExpired)

        do {
            _ = try await manager.validateAndConsume(ticketId: ticket.ticketId, toolName: "TestTool", parameters: params)
            XCTFail("Expired ticket must throw ConfirmationError.expiredTicket")
        } catch let err as ConfirmationError {
            XCTAssertEqual(err, .expiredTicket)
        }
    }

    func testOperationTypeEvaluation() async {
        let permissionManager = PermissionManager(requireConfirmationForSend: true)

        let searchTool = WebSearchTool()
        let searchDecision = await permissionManager.evaluate(tool: searchTool, arguments: ["query": "latest AI news"])
        if case .allowImmediate = searchDecision {
            // Expected for read operation
        } else {
            XCTFail("Read operations should allow immediate execution")
        }

        let mailTool = MailTool()
        let checkDecision = await permissionManager.evaluate(tool: mailTool, arguments: ["action": "check_inbox"])
        if case .allowImmediate = checkDecision {
            // Expected for read operation
        } else {
            XCTFail("check_inbox should allow immediate execution")
        }

        let draftDecision = await permissionManager.evaluate(
            tool: mailTool,
            arguments: ["action": "compose_mail", "recipient": "test@example.com"]
        )
        if case .allowImmediate = draftDecision {
            // Expected for draft operation
        } else {
            XCTFail("compose_mail draft should allow immediate execution")
        }

        let sendDecision = await permissionManager.evaluate(
            tool: mailTool,
            arguments: ["action": "send_email", "recipient": "test@example.com", "subject": "Hi"]
        )
        if case .requiresConfirmation(let ticket) = sendDecision {
            XCTAssertEqual(ticket.operationType, .send)
            XCTAssertEqual(ticket.toolName, "MailTool")
        } else {
            XCTFail("send_email must require confirmation")
        }
    }
}
