//
//  FastIntentRouterTests.swift
//  IRIS_ITests
//
//  Verifies sub-10ms deterministic routing for direct queries and negative
//  test fall-throughs for ambiguous or natural language requests.
//

import XCTest
#if canImport(IRIS_ICore)
@testable import IRIS_ICore
#elseif canImport(IRIS_I)
@testable import IRIS_I
#endif

final class FastIntentRouterTests: XCTestCase {

    let router = FastIntentRouter()

    func testTimeQueryRoutingSpeed() {
        let queries = [
            "Hey IRIS, what is the time?",
            "tell me the time",
            "what's the time",
            "current time",
            "time right now"
        ]

        for query in queries {
            let result = router.route(query: query)
            switch result {
            case .matched(let toolName, let args, let routingDurationMs):
                XCTAssertEqual(toolName, "SystemInfoTool")
                XCTAssertEqual(args["action"] as? String, "time")
                XCTAssertLessThan(routingDurationMs, 10.0, "Routing must complete in <10ms for '\(query)'")
            case .unmatched:
                XCTFail("Expected '\(query)' to match FastIntentRouter time intent")
            }
        }
    }

    func testBatteryQueryRoutingSpeed() {
        let queries = [
            "Check battery status",
            "battery percentage",
            "current battery level",
            "how much battery is left"
        ]

        for query in queries {
            let result = router.route(query: query)
            switch result {
            case .matched(let toolName, let args, let routingDurationMs):
                XCTAssertEqual(toolName, "SystemInfoTool")
                XCTAssertEqual(args["action"] as? String, "battery")
                XCTAssertLessThan(routingDurationMs, 10.0, "Routing must complete in <10ms for '\(query)'")
            case .unmatched:
                XCTFail("Expected '\(query)' to match FastIntentRouter battery intent")
            }
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

    func testInstagramAndGeneralizedPhrasingsRouting() {
        let testCases = [
            ("open Instagram", "instagram"),
            ("Hey IRIS, open Instagram", "instagram"),
            ("take me to Instagram", "instagram"),
            ("can you open Instagram", "instagram"),
            ("switch to YouTube", "youtube"),
            ("bring up Spotify", "spotify"),
            ("start TikTok", "tiktok"),
            ("go to Apple Music", "apple music")
        ]

        for (query, expectedApp) in testCases {
            let result = router.route(query: query)
            switch result {
            case .matched(let toolName, let args, let routingDurationMs):
                XCTAssertEqual(toolName, "AppOpenerTool", "Query '\(query)' should route to AppOpenerTool")
                XCTAssertEqual(args["app_name"] as? String, expectedApp, "Expected app '\(expectedApp)' for query '\(query)'")
                XCTAssertLessThan(routingDurationMs, 10.0, "Routing must complete in <10ms for '\(query)'")
            case .unmatched:
                XCTFail("Expected '\(query)' to match generalized app launch routing")
            }
        }
    }

    // MARK: - Negative Fall-Through Tests

    func testNegativeTimeQueriesFallThrough() {
        let negativeQueries = [
            "Is it time to leave for the airport?",
            "What time did the package arrive yesterday?",
            "In ancient Rome, how did they measure time?"
        ]

        for query in negativeQueries {
            let result = router.route(query: query)
            switch result {
            case .matched:
                XCTFail("Negative time query '\(query)' must NOT match fast router")
            case .unmatched(let routingDurationMs):
                XCTAssertLessThan(routingDurationMs, 10.0)
            }
        }
    }

    func testNegativeDateQueriesFallThrough() {
        let negativeQueries = [
            "What was the date of the French Revolution?",
            "Save the date for the wedding next month",
            "What date did Neil Armstrong land on the moon?"
        ]

        for query in negativeQueries {
            let result = router.route(query: query)
            switch result {
            case .matched:
                XCTFail("Negative date query '\(query)' must NOT match fast router")
            case .unmatched(let routingDurationMs):
                XCTAssertLessThan(routingDurationMs, 10.0)
            }
        }
    }

    func testNegativeBatteryQueriesFallThrough() {
        let negativeQueries = [
            "Why does a cold battery drain faster?",
            "Explain the chemistry of lithium iron phosphate batteries",
            "Warm battery packs during fast charging"
        ]

        for query in negativeQueries {
            let result = router.route(query: query)
            switch result {
            case .matched:
                XCTFail("Negative battery query '\(query)' must NOT match fast router")
            case .unmatched(let routingDurationMs):
                XCTAssertLessThan(routingDurationMs, 10.0)
            }
        }
    }

    func testNegativeTelemetryQueriesFallThrough() {
        let negativeQueries = [
            "Explain computer program memory management",
            "How does DRAM compare to SRAM in modern computers?",
            "Write a Python program to parse a diagram"
        ]

        for query in negativeQueries {
            let result = router.route(query: query)
            switch result {
            case .matched:
                XCTFail("Negative telemetry query '\(query)' must NOT match fast router")
            case .unmatched(let routingDurationMs):
                XCTAssertLessThan(routingDurationMs, 10.0)
            }
        }
    }

    func testNegativeAppOpenQueriesFallThrough() {
        let negativeQueries = [
            "open the pod bay doors",
            "open a discussion on artificial intelligence",
            "open a can of soup",
            "open email from openai"
        ]

        for query in negativeQueries {
            let result = router.route(query: query)
            switch result {
            case .matched:
                XCTFail("Negative app open query '\(query)' must NOT match fast router")
            case .unmatched(let routingDurationMs):
                XCTAssertLessThan(routingDurationMs, 10.0)
            }
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

    func testSafariAndCalculatorRoutingSpeed() {
        for (query, expectedApp) in [("open safari", "Safari"), ("launch calculator", "Calculator"), ("open clock", "Clock")] {
            let result = router.route(query: query)
            switch result {
            case .matched(let toolName, let args, let duration):
                XCTAssertEqual(toolName, "AppOpenerTool")
                XCTAssertEqual(args["app_name"] as? String, expectedApp)
                XCTAssertLessThan(duration, 10.0)
            case .unmatched:
                XCTFail("Expected '\(query)' to match FastIntentRouter")
            }
        }
    }
}
