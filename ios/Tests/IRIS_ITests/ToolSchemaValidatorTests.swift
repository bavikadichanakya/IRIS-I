//
//  ToolSchemaValidatorTests.swift
//  IRIS_ITests
//
//  Verifies runtime schema validation, required parameter enforcement,
//  enum constraint validation, and unexpected parameter rejection.
//

import XCTest
@testable import IRIS_I

final class ToolSchemaValidatorTests: XCTestCase {

    func testAppOpenerToolValidationSuccess() {
        let tool = AppOpenerTool()
        let validArgs: [String: Any] = ["app_name": "youtube"]
        let result = ToolSchemaValidator.validate(tool: tool, arguments: validArgs)

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.missingRequired.isEmpty)
        XCTAssertTrue(result.invalidTypes.isEmpty)
        XCTAssertTrue(result.enumViolations.isEmpty)
    }

    func testMissingRequiredParameterRejection() {
        let tool = AppOpenerTool()
        let emptyArgs: [String: Any] = [:]
        let result = ToolSchemaValidator.validate(tool: tool, arguments: emptyArgs)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.missingRequired.contains("app_name"))
    }

    func testInvalidTypeRejection() {
        let tool = AppOpenerTool()
        let badTypeArgs: [String: Any] = ["app_name": 12345] // Number instead of String
        let result = ToolSchemaValidator.validate(tool: tool, arguments: badTypeArgs)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.invalidTypes.contains("app_name"))
    }

    func testEnumConstraintViolation() {
        let tool = EventKitTool()
        let invalidEnumArgs: [String: Any] = [
            "action": "non_existent_action",
            "title": "Dentist"
        ]
        let result = ToolSchemaValidator.validate(tool: tool, arguments: invalidEnumArgs)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.enumViolations.contains("action"))
    }

    func testUnexpectedParameterRejection() {
        let tool = AppOpenerTool()
        let unexpectedArgs: [String: Any] = [
            "app_name": "music",
            "hallucinated_param": "test"
        ]
        let result = ToolSchemaValidator.validate(tool: tool, arguments: unexpectedArgs)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.unexpectedProperties.contains("hallucinated_param"))
    }
}

