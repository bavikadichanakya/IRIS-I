//
//  ToolCallParserTests.swift
//  IRIS_ITests
//
//  Unit tests verifying resilient tool call parsing from noisy model streams.
//

import XCTest
#if canImport(IRIS_ICore)
@testable import IRIS_ICore
#elseif canImport(IRIS_I)
@testable import IRIS_I
#endif

final class ToolCallParserTests: XCTestCase {

    func testStandardJsonToolCall() {
        let input = """
        ```json
        {
          "name": "SystemInfoTool",
          "arguments": {
            "action": "time"
          }
        }
        ```
        """
        let parsed = ToolCallParser.parse(content: input)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.toolName, "SystemInfoTool")
        XCTAssertEqual(parsed?.arguments["action"] as? String, "time")
    }

    func testDoubledCurlyBracesNormalization() {
        // Models frequently output {{ "name": "..." }} when generating json
        let input = "{{ \"name\": \"WebSearchTool\", \"arguments\": {{ \"query\": \"latest AI news\" }} }}"
        let parsed = ToolCallParser.parse(content: input)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.toolName, "WebSearchTool")
        XCTAssertEqual(parsed?.arguments["query"] as? String, "latest AI news")
    }

    func testOuterQuotesAndUnescaping() {
        let input = "\"{\\\"name\\\": \\\"MailTool\\\", \\\"arguments\\\": {\\\"action\\\": \\\"check_inbox\\\", \\\"sender_filter\\\": \\\"OpenAI\\\"}}\""
        let parsed = ToolCallParser.parse(content: input)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.toolName, "MailTool")
        XCTAssertEqual(parsed?.arguments["sender_filter"] as? String, "OpenAI")
    }

    func testEmbeddedJsonInsideConversationalText() {
        let input = "Sure, let me check that for you right away. {\"tool\": \"SystemInfoTool\", \"parameters\": {\"action\": \"battery\"}} Hope this helps!"
        let parsed = ToolCallParser.parse(content: input)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.toolName, "SystemInfoTool")
        XCTAssertEqual(parsed?.arguments["action"] as? String, "battery")
    }

    func testNestedThoughtActionFormat() {
        let input = """
        {
          "thought": "User wants to create a reminder.",
          "action": {
            "tool": "EventKitTool",
            "parameters": {
              "action": "create_reminder",
              "title": "check the server logs",
              "due_date": "tomorrow 09:00"
            }
          }
        }
        """
        let parsed = ToolCallParser.parse(content: input)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.toolName, "EventKitTool")
        XCTAssertEqual(parsed?.arguments["title"] as? String, "check the server logs")
    }

    func testPureConversationalReturnsNil() {
        let input = "The capital of France is Paris. How else can I assist you?"
        let parsed = ToolCallParser.parse(content: input)
        XCTAssertNil(parsed)
    }
}

