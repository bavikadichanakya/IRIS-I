//
//  SystemInfoToolTests.swift
//  IRIS_ITests
//
//  Verifies SystemInfoTool outputs for time, date, battery, and memory telemetry.
//

import XCTest
#if canImport(IRIS_ICore)
@testable import IRIS_ICore
#elseif canImport(IRIS_I)
@testable import IRIS_I
#endif

final class SystemInfoToolTests: XCTestCase {

    let tool = SystemInfoTool()

    func testTimeActionReturnsValidTime() async {
        let result = await tool.execute(arguments: ["action": "time"])
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.outcome, .completedVerified)
        XCTAssertNotNil(result.outputPayload["current_time"])
    }

    func testDateActionReturnsValidDate() async {
        let result = await tool.execute(arguments: ["action": "date"])
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.outcome, .completedVerified)
        XCTAssertNotNil(result.outputPayload["current_date"])
    }

    func testBatteryActionReturnsExpectedMetrics() async {
        let result = await tool.execute(arguments: ["action": "battery"])
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.outcome, .completedVerified)
        XCTAssertNotNil(result.outputPayload["battery_state"])
    }

    func testTelemetryActionReportsPhysicalFootprint() async {
        let result = await tool.execute(arguments: ["action": "telemetry"])
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.outcome, .completedVerified)
        XCTAssertNotNil(result.outputPayload["app_physical_footprint_mb"])
        XCTAssertNotNil(result.outputPayload["safety_ceiling_mb"])
    }

    func testInvalidActionFailsGracefully() async {
        let result = await tool.execute(arguments: ["action": "unsupported_command"])
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.outcome, .failed)
    }
}

