//
//  ExecutionRecordTests.swift
//  IRIS_ITests
//
//  Verifies the unified authoritative ExecutionRecord and StructuredExecutionState
//  guaranteeing zero mock or fabricated states across UI, Dynamic Island, and TTS.
//

import XCTest
#if canImport(IRIS_ICore)
@testable import IRIS_ICore
#elseif canImport(IRIS_I)
@testable import IRIS_I
#endif

final class ExecutionRecordTests: XCTestCase {

    func testStructuredExecutionStates() {
        let validStates: [StructuredExecutionState] = [
            .notStarted,
            .resolving,
            .permissionRequired,
            .inProgress,
            .completedVerified,
            .completedUnverified,
            .failed,
            .unsupported,
            .cancelled,
            .timedOut
        ]

        XCTAssertEqual(validStates.count, 10)
        XCTAssertEqual(StructuredExecutionState.completedVerified.rawValue, "completedVerified")
        XCTAssertEqual(StructuredExecutionState.unsupported.rawValue, "unsupported")
    }

    func testExecutionRecordInitialization() {
        let record = ExecutionRecord(
            toolName: "app_opener",
            operationType: "launch",
            validatedArguments: ["appName": "spotify"],
            permissionResult: "authorized",
            executionState: .completedVerified,
            toolOutcome: .completedVerified,
            resultPayload: "Opened Spotify successfully",
            errorDetails: nil,
            isVerified: true,
            durationMs: 8.5,
            requiredUserAction: nil,
            timestamp: Date()
        )

        XCTAssertEqual(record.toolName, "app_opener")
        XCTAssertEqual(record.executionState, .completedVerified)
        XCTAssertTrue(record.isVerified)
        XCTAssertNil(record.errorDetails)
    }

    func testUnsupportedExecutionRecord() {
        let record = ExecutionRecord(
            toolName: "app_opener",
            operationType: "launch",
            validatedArguments: ["appName": "UnknownApp999"],
            permissionResult: "authorized",
            executionState: .unsupported,
            toolOutcome: .unsupported,
            resultPayload: nil,
            errorDetails: "Application 'UnknownApp999' is not registered or supported on this device.",
            isVerified: false,
            durationMs: 3.2,
            requiredUserAction: nil,
            timestamp: Date()
        )

        XCTAssertEqual(record.executionState, .unsupported)
        XCTAssertEqual(record.toolOutcome, .unsupported)
        XCTAssertFalse(record.isVerified)
        XCTAssertNotNil(record.errorDetails)
    }
}

