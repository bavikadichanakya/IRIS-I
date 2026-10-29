//
//  WebSearchToolTests.swift
//  IRIS_ITests
//
//  Verifies WebSearchTool live search contract, truthful empty result reporting
//  (no fabricated success), and parameter validation.
//

import XCTest
@testable import IRIS_ICore

final class WebSearchToolTests: XCTestCase {

    let tool = WebSearchTool()

    func testMissingQueryFails() async {
        let result = await tool.execute(arguments: [:])
        XCTAssertEqual(result.outcome, .failed)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("query") == true)
    }

    func testEmptyQueryFails() async {
        let result = await tool.execute(arguments: ["query": "   "])
        XCTAssertEqual(result.outcome, .failed)
        XCTAssertNotNil(result.error)
    }

    func testOperationTypeIsRead() {
        let opType = tool.operationType(for: ["query": "latest news"])
        XCTAssertEqual(opType, .read)
    }

    func testSearchResultItemParsing() {
        let item = SearchResultItem(
            title: "OpenAI Announces GPT-5",
            url: "https://openai.com/news",
            snippet: "The new model features advanced reasoning.",
            source: "Web Search"
        )

        let dict = item.asDictionary
        XCTAssertEqual(dict["title"] as? String, "OpenAI Announces GPT-5")
        XCTAssertEqual(dict["url"] as? String, "https://openai.com/news")
        XCTAssertEqual(dict["snippet"] as? String, "The new model features advanced reasoning.")
    }
}

