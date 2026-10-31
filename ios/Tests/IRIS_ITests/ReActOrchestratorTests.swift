//
//  ReActOrchestratorTests.swift
//  IRIS_ITests
//
//  Verifies end-to-end ReAct dispatching, fast-path routing, direct ticket execution,
//  cancellation, and regression tests for authoritative execution record aggregation.
//

import XCTest
#if canImport(IRIS_ICore)
@testable import IRIS_ICore
#elseif canImport(IRIS_I)
@testable import IRIS_I
#endif

final class ReActOrchestratorTests: XCTestCase {

    let orchestrator = ReActOrchestrator.shared

    func testFastIntentInstantDispatchForTime() async {
        let response = await orchestrator.process(userPrompt: "What is the time?")
        XCTAssertFalse(response.textResponse.isEmpty)
        XCTAssertTrue(response.executedTools.contains("SystemInfoTool"))
        XCTAssertLessThan(response.routingDurationMs, 10.0, "Deterministic routing must execute in <10ms")
        XCTAssertEqual(response.stepCount, 1)
    }

    func testFastIntentInstantDispatchForBattery() async {
        let response = await orchestrator.process(userPrompt: "What is my battery level?")
        XCTAssertFalse(response.textResponse.isEmpty)
        XCTAssertTrue(response.executedTools.contains("SystemInfoTool"))
        XCTAssertLessThan(response.routingDurationMs, 10.0, "Deterministic routing must execute in <10ms")
    }

    func testExecuteConfirmedActionDirectly() async {
        let params: [String: Any] = ["action": "time"]
        let ticket = await ConfirmationManager.shared.issueTicket(
            for: "SystemInfoTool",
            operationType: .send,
            parameters: params
        )

        let response = await orchestrator.executeConfirmedAction(
            ticketId: ticket.ticketId,
            parameters: params
        )

        XCTAssertFalse(response.requiresConfirmation)
        XCTAssertTrue(response.executedTools.contains("SystemInfoTool"))
        XCTAssertFalse(response.textResponse.isEmpty)
    }

    func testExecuteConfirmedActionRejectsTamperedParameters() async {
        let originalParams: [String: Any] = ["action": "time"]
        let tamperedParams: [String: Any] = ["action": "delete_all"]

        let ticket = await ConfirmationManager.shared.issueTicket(
            for: "SystemInfoTool",
            operationType: .send,
            parameters: originalParams
        )

        let response = await orchestrator.executeConfirmedAction(
            ticketId: ticket.ticketId,
            parameters: tamperedParams
        )

        XCTAssertTrue(response.textResponse.contains("Security violation"))
        XCTAssertTrue(response.executedTools.isEmpty)
    }

    func testCancellationStopsProcessing() async {
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
            await orchestrator.cancel()
        }

        let response = await orchestrator.process(userPrompt: "Write a 500 page book about galaxies and astrophysics.")
        XCTAssertNotNil(response.textResponse)
    }

    // MARK: - Regression Tests for Execution Record Aggregation

    func testConversationalResponseWithoutToolCalls() {
        let record = ReActOrchestrator.aggregateExecutionRecord(
            userPrompt: "Hello IRIS, how are you?",
            executedToolNames: [],
            executedToolSnapshots: [],
            finalAssistantText: "I am functioning normally, sir.",
            totalDuration: 125.0
        )

        XCTAssertNil(record.selectedTool, "Conversational response must have selectedTool = nil")
        XCTAssertNil(record.toolOutcome, "Conversational response must not claim a tool outcome")
        XCTAssertEqual(record.executionState, .notStarted, "Conversational response must not claim tool execution completed")
        XCTAssertFalse(record.isVerified, "Conversational response must not claim verified tool execution")
        XCTAssertEqual(record.resultPayload["response"], "I am functioning normally, sir.")
    }

    func testOneSuccessfulToolCallExecutionRecord() {
        let successResult = AgentExecutionResult(
            success: true,
            toolName: "SystemInfoTool",
            outcome: .completedVerified,
            outputPayload: ["time": "18:30:00"],
            durationMs: 5.0,
            verified: true
        )

        let record = ReActOrchestrator.aggregateExecutionRecord(
            userPrompt: "What is the time?",
            executedToolNames: ["SystemInfoTool"],
            executedToolSnapshots: [(tool: "SystemInfoTool", arguments: ["action": "time"], result: successResult)],
            finalAssistantText: "The time is 6:30 PM.",
            totalDuration: 42.0
        )

        XCTAssertEqual(record.selectedTool, "SystemInfoTool")
        XCTAssertEqual(record.executionState, .completedVerified)
        XCTAssertEqual(record.toolOutcome, .completedVerified)
        XCTAssertTrue(record.isVerified)
        XCTAssertEqual(record.resultPayload["time"], "18:30:00")
    }

    func testOneFailedToolCallExecutionRecord() {
        let failedResult = AgentExecutionResult.failure(
            tool: "WeatherTool",
            error: "Service unavailable",
            outcome: .failed
        )

        let record = ReActOrchestrator.aggregateExecutionRecord(
            userPrompt: "Check weather",
            executedToolNames: ["WeatherTool"],
            executedToolSnapshots: [(tool: "WeatherTool", arguments: ["city": "Cupertino"], result: failedResult)],
            finalAssistantText: "Could not retrieve weather.",
            totalDuration: 55.0
        )

        XCTAssertEqual(record.selectedTool, "WeatherTool")
        XCTAssertEqual(record.executionState, .failed)
        XCTAssertEqual(record.toolOutcome, .failed)
        XCTAssertFalse(record.isVerified)
        XCTAssertEqual(record.errorDetails, "Service unavailable")
    }

    func testMultipleToolsWithMixedOutcomesPrioritizesFailure() {
        let successResult = AgentExecutionResult(
            success: true,
            toolName: "SystemInfoTool",
            outcome: .completedVerified,
            outputPayload: ["battery": "80%"],
            durationMs: 4.0,
            verified: true
        )
        let failedResult = AgentExecutionResult.failure(
            tool: "MessagingTool",
            error: "Missing contact",
            outcome: .failed
        )

        let snapshots: [(tool: String, arguments: [String: Any], result: AgentExecutionResult)] = [
            (tool: "SystemInfoTool", arguments: ["action": "battery"], result: successResult),
            (tool: "MessagingTool", arguments: [:], result: failedResult)
        ]

        let record = ReActOrchestrator.aggregateExecutionRecord(
            userPrompt: "Check battery and text it to Bob",
            executedToolNames: ["SystemInfoTool", "MessagingTool"],
            executedToolSnapshots: snapshots,
            finalAssistantText: "Battery checked but could not send text.",
            totalDuration: 88.0
        )

        XCTAssertEqual(record.selectedTool, "MessagingTool")
        XCTAssertEqual(record.executionState, .failed, "Mixed outcome with a failure must not report false success")
        XCTAssertEqual(record.toolOutcome, .failed)
        XCTAssertFalse(record.isVerified)
    }

    func testExternalAppHandoffExecutionRecord() {
        let handoffResult = AgentExecutionResult(
            success: true,
            toolName: "AppOpenerTool",
            outcome: .completedUnverified,
            outputPayload: ["opened": "YouTube"],
            durationMs: 12.0,
            verified: false
        )

        let record = ReActOrchestrator.aggregateExecutionRecord(
            userPrompt: "Open YouTube",
            executedToolNames: ["AppOpenerTool"],
            executedToolSnapshots: [(tool: "AppOpenerTool", arguments: ["app_name": "youtube"], result: handoffResult)],
            finalAssistantText: "Launching YouTube.",
            totalDuration: 25.0
        )

        XCTAssertEqual(record.selectedTool, "AppOpenerTool")
        XCTAssertEqual(record.executionState, .completedUnverified)
        XCTAssertEqual(record.toolOutcome, .completedUnverified)
        XCTAssertFalse(record.isVerified, "External app handoff must remain unverified")
    }
}
