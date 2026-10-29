//
//  FastIntentRouterTests.swift
//  IRIS_ITests
//
//  Verifies sub-10ms deterministic routing for direct queries.
//

import XCTest
@testable import IRIS_ICore

final class FastIntentRouterTests: XCTestCase {

    let router = FastIntentRouter()

    func testTimeQueryRoutingSpeed() {
        let result = router.route(query: "Hey IRIS, what is the time?")
        switch result {
        case .matched(let toolName, let args, let routingDurationMs):
            XCTAssertEqual(toolName, "SystemInfoTool")
            XCTAssertEqual(args["action"] as? String, "time")
            XCTAssertLessThan(routingDurationMs, 10.0, "Routing must complete in <10ms")
        case .unmatched:
            XCTFail("Expected 'what is the time' to match FastIntentRouter")
        }
    }

    func testBatteryQueryRoutingSpeed() {
        let result = router.route(query: "Check battery status")
        switch result {
        case .matched(let toolName, let args, let routingDurationMs):
            XCTAssertEqual(toolName, "SystemInfoTool")
            XCTAssertEqual(args["action"] as? String, "battery")
            XCTAssertLessThan(routingDurationMs, 10.0, "Routing must complete in <10ms")
        case .unmatched:
            XCTFail("Expected 'battery status' to match FastIntentRouter")
        }
    }

    func testMemoryTelemetryRoutingSpeed() {
        let result = router.route(query: "What is my current RAM memory usage?")
        switch result {
        case .matched(let toolName, let args, let routingDurationMs):
            XCTAssertEqual(toolName, "SystemInfoTool")
            XCTAssertEqual(args["action"] as? String, "telemetry")
            XCTAssertLessThan(routingDurationMs, 10.0, "Routing must complete in <10ms")
        case .unmatched:
            XCTFail("Expected 'memory usage' to match FastIntentRouter")
        }
    }

    func testAppOpenDirectRoutingSpeed() {
        let result = router.route(query: "open Spotify")
        switch result {
        case .matched(let toolName, let args, let routingDurationMs):
            XCTAssertEqual(toolName, "AppOpenerTool")
            XCTAssertEqual(args["app_name"] as? String, "spotify")
            XCTAssertLessThan(routingDurationMs, 10.0, "Routing must complete in <10ms")
        case .unmatched:
            XCTFail("Expected 'open Spotify' to match FastIntentRouter")
        }
    }

    func testAmbiguousQueryFallsThroughToLLM() {
        let result = router.route(query: "Can you explain quantum computing and give me a summary?")
        switch result {
        case .matched:
            XCTFail("Ambiguous complex query should NOT match fast intent router")
        case .unmatched(let routingDurationMs):
            XCTAssertLessThan(routingDurationMs, 10.0, "Fall-through decision must complete in <10ms")
        }
    }
}

