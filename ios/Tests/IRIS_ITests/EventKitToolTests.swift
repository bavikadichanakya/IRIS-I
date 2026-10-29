//
//  EventKitToolTests.swift
//  IRIS_ITests
//
//  Verifies operation type classification and confirmation requirements for EventKitTool.
//

import XCTest
@testable import IRIS_ICore

final class EventKitToolTests: XCTestCase {

    let tool = EventKitTool()

    func testDeleteEventsClassifiedAsDestructive() {
        let opType = tool.operationType(for: ["action": "delete_events"])
        XCTAssertEqual(opType, .destructive, "delete_events must be classified as destructive")
    }

    func testCreateReminderClassifiedAsDraft() {
        let opType = tool.operationType(for: ["action": "create_reminder"])
        XCTAssertEqual(opType, .draft, "create_reminder should be classified as draft")
    }

    func testListRemindersClassifiedAsRead() {
        let opType = tool.operationType(for: ["action": "list_reminders"])
        XCTAssertEqual(opType, .read, "list_reminders should be classified as read")
    }

    func testDeleteEventsRequiresConfirmation() async {
        let result = await tool.execute(arguments: ["action": "delete_events"])
        XCTAssertEqual(result.outcome, .confirmationRequired)
        XCTAssertFalse(result.success)
    }
}
