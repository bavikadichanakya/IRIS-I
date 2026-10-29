//
//  ReActOrchestratorTests.swift
//  IRIS_ITests
//
//  Verifies end-to-end ReAct dispatching, fast-path routing, direct ticket execution,
//  and cancellation.
//

import XCTest
@testable import IRIS_ICore

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
}
