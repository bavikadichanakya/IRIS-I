//
//  MailToolTests.swift
//  IRIS_ITests
//
//  Verifies MailTool behavior for disconnected state, operation type mapping,
//  and provider forwarding.
//

import XCTest
@testable import IRIS_ICore

// Mock mail provider for deterministic testing
final class MockMailProvider: MailProviderProtocol, @unchecked Sendable {
    var state: ConnectorState
    var mockMessages: [EmailMessage] = []
    var sentRecipient: String?

    init(state: ConnectorState = .disconnected) {
        self.state = state
    }

    func searchMessages(query: String, maxResults: Int) async throws -> [EmailMessage] {
        return mockMessages
    }

    func getMessage(id: String) async throws -> EmailMessage {
        if let msg = mockMessages.first(where: { $0.id == id }) {
            return msg
        }
        throw URLError(.fileDoesNotExist)
    }

    func createDraft(recipient: String, subject: String, body: String) async throws -> String {
        return "draft_123"
    }

    func sendEmail(recipient: String, subject: String, body: String) async throws -> String {
        self.sentRecipient = recipient
        return "sent_msg_456"
    }
}

final class MailToolTests: XCTestCase {

    func testDisconnectedStateReturnsExplicitNotConnected() async {
        let mockProvider = MockMailProvider(state: .disconnected)
        let tool = MailTool(provider: mockProvider)

        let result = await tool.execute(arguments: ["action": "check_inbox"])
        XCTAssertEqual(result.outcome, .failed)
        XCTAssertEqual(result.outputPayload["status"] as? String, "not_connected")
        XCTAssertNotNil(result.error)
    }

    func testOperationTypeClassification() {
        let tool = MailTool()

        XCTAssertEqual(tool.operationType(for: ["action": "check_inbox"]), .read)
        XCTAssertEqual(tool.operationType(for: ["action": "compose_mail"]), .draft)
        XCTAssertEqual(tool.operationType(for: ["action": "create_draft"]), .draft)
        XCTAssertEqual(tool.operationType(for: ["action": "send_email"]), .send)
    }

    func testConnectedProviderReturnsEmails() async {
        let mockProvider = MockMailProvider(state: .connected(accountEmail: "user@example.com"))
        mockProvider.mockMessages = [
            EmailMessage(
                id: "msg_openai",
                sender: "OpenAI <support@openai.com>",
                recipients: ["user@example.com"],
                subject: "Your API Usage Update",
                snippet: "Here is your summary of activity this month."
            )
        ]

        let tool = MailTool(provider: mockProvider)
        let result = await tool.execute(arguments: [
            "action": "check_inbox",
            "sender_filter": "OpenAI"
        ])

        XCTAssertEqual(result.outcome, .completed)
        XCTAssertEqual(result.outputPayload["found_count"] as? Int, 1)
        let message = result.outputPayload["message"] as? String
        XCTAssertTrue(message?.contains("OpenAI") == true)
    }

    func testSendEmailCallsProviderWhenConnected() async {
        let mockProvider = MockMailProvider(state: .connected(accountEmail: "user@example.com"))
        let tool = MailTool(provider: mockProvider)

        let result = await tool.execute(arguments: [
            "action": "send_email",
            "recipient": "partner@example.com",
            "subject": "Project Status",
            "body": "All stages completed."
        ])

        XCTAssertEqual(result.outcome, .completed)
        XCTAssertEqual(result.outputPayload["message_id"] as? String, "sent_msg_456")
        XCTAssertEqual(mockProvider.sentRecipient, "partner@example.com")
    }

    func testMissingRecipientForSendFails() async {
        let mockProvider = MockMailProvider(state: .connected(accountEmail: "user@example.com"))
        let tool = MailTool(provider: mockProvider)

        let result = await tool.execute(arguments: [
            "action": "send_email",
            "subject": "Missing recipient"
        ])

        XCTAssertEqual(result.outcome, .failed)
        XCTAssertNotNil(result.error)
    }
}
