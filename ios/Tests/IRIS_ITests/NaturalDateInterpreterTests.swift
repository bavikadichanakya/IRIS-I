//
//  NaturalDateInterpreterTests.swift
//  IRIS_ITests
//
//  Verifies deterministic natural date and time parsing across relative
//  offsets, day expressions, and meridiem time strings.
//

import XCTest
@testable import IRIS_I

final class NaturalDateInterpreterTests: XCTestCase {

    func testTomorrowMorningParsing() {
        let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 12, minute: 0))!
        let parsed = NaturalDateInterpreter.parse("tomorrow at 9:00 AM", referenceDate: reference)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.dateComponents.year, 2026)
        XCTAssertEqual(parsed?.dateComponents.month, 11)
        XCTAssertEqual(parsed?.dateComponents.day, 1)
        XCTAssertEqual(parsed?.dateComponents.hour, 9)
        XCTAssertEqual(parsed?.dateComponents.minute, 0)
        XCTAssertTrue(parsed?.isTimeSpecified == true)
    }

    func testRelativeMinutesOffset() {
        let reference = Date(timeIntervalSince1970: 1700000000)
        let parsed = NaturalDateInterpreter.parse("in 45 minutes", referenceDate: reference)

        XCTAssertNotNil(parsed)
        let expectedTime = reference.addingTimeInterval(45 * 60)
        XCTAssertEqual(parsed?.date.timeIntervalSince1970 ?? 0, expectedTime.timeIntervalSince1970, accuracy: 1.0)
    }

    func testRelativeHoursOffset() {
        let reference = Date(timeIntervalSince1970: 1700000000)
        let parsed = NaturalDateInterpreter.parse("in 2 hours", referenceDate: reference)

        XCTAssertNotNil(parsed)
        let expectedTime = reference.addingTimeInterval(2 * 3600)
        XCTAssertEqual(parsed?.date.timeIntervalSince1970 ?? 0, expectedTime.timeIntervalSince1970, accuracy: 1.0)
    }

    func testTonightParsing() {
        let reference = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 10, minute: 0))!
        let parsed = NaturalDateInterpreter.parse("tonight at 8pm", referenceDate: reference)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.dateComponents.day, 31)
        XCTAssertEqual(parsed?.dateComponents.hour, 20)
    }

    func testIsoDateParsing() {
        let parsed = NaturalDateInterpreter.parse("2026-11-15 14:30")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.dateComponents.year, 2026)
        XCTAssertEqual(parsed?.dateComponents.month, 11)
        XCTAssertEqual(parsed?.dateComponents.day, 15)
        XCTAssertEqual(parsed?.dateComponents.hour, 14)
        XCTAssertEqual(parsed?.dateComponents.minute, 30)
    }
}
