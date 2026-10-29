//
//  WebSearchTool.swift
//  IRIS-I
//
//  Direct on-device HTTPS web search tool for real-time information and AI news.
//  Accurately returns structured titles, URLs, snippets, and empty/error states without fabricated success.
//

import Foundation

public struct SearchResultItem: Codable, Sendable {
    public let title: String
    public let url: String
    public let snippet: String
    public let date: String?

    public init(title: String, url: String, snippet: String, date: String? = nil) {
        self.title = title
        self.url = url
        self.snippet = snippet
        self.date = date
    }

    public var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "title": title,
            "url": url,
            "snippet": snippet
        ]
        if let date = date {
            dict["date"] = date
        }
        return dict
    }
}

public struct WebSearchTool: IRISAgentTool {
    public let name = "WebSearchTool"
    public let description = "Searches the live web for recent news, AI updates, and real-time facts."
    public let category = "web"
    public let permissionLevel = PermissionLevel.publicLevel

    public let parametersSchema = ToolParameterSchema(
        type: "object",
        properties: [
            "query": ToolPropertySchema(
                type: "string",
                description: "The search terms or question, e.g. 'latest AI news' or 'Qwen 2.5 release'"
            ),
            "limit": ToolPropertySchema(
                type: "integer",
                description: "Maximum number of results to return (default: 3, max: 10)"
            )
        ],
        required: ["query"]
    )

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func execute(arguments: [String: Any]) async -> AgentExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        guard let query = arguments["query"] as? String, !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Missing required 'query' argument.",
                outcome: .failed,
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        let limit = min(10, max(1, (arguments["limit"] as? Int) ?? 3))
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        // Try DuckDuckGo Instant Answer API first for fast, structured summaries
        let apiEndpoint = "https://api.duckduckgo.com/?q=\(encodedQuery)&format=json&no_html=1&skip_disambig=1"
        if let apiUrl = URL(string: apiEndpoint) {
            var apiRequest = URLRequest(url: apiUrl)
            apiRequest.timeoutInterval = 5.0
            apiRequest.setValue("IRIS-I-Assistant/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

            if let (apiData, apiResponse) = try? await session.data(for: apiRequest),
               let httpResp = apiResponse as? HTTPURLResponse, httpResp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: apiData) as? [String: Any] {

                let abstract = (json["AbstractText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let heading = (json["Heading"] as? String) ?? query
                let sourceUrl = (json["AbstractURL"] as? String) ?? ""

                if !abstract.isEmpty {
                    let item = SearchResultItem(title: heading, url: sourceUrl, snippet: abstract)
                    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                    return AgentExecutionResult.success(
                        tool: name,
                        verified: true,
                        payload: [
                            "query": query,
                            "found_count": 1,
                            "results": [item.snippet],
                            "summary": "\(heading): \(abstract)"
                        ],
                        durationMs: duration
                    )
                }
            }
        }

        // Fallback to HTML Search Endpoint
        let htmlEndpoint = "https://html.duckduckgo.com/html/?q=\(encodedQuery)"
        guard let url = URL(string: htmlEndpoint) else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Failed to construct valid search URL.",
                outcome: .failed,
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Invalid network response from search service.",
                    outcome: .failed,
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            if httpResponse.statusCode == 429 || httpResponse.statusCode == 403 {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Search provider temporarily rate-limited or blocked request (HTTP \(httpResponse.statusCode)).",
                    outcome: .failed,
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            guard httpResponse.statusCode == 200 else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Search service returned HTTP \(httpResponse.statusCode).",
                    outcome: .failed,
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            guard let htmlString = String(data: data, encoding: .utf8) else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Failed to decode search response body.",
                    outcome: .failed,
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            let structuredItems = extractStructuredResults(from: htmlString, limit: limit)
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            // If empty, truthfully return 0 results without fabricating fake success text
            if structuredItems.isEmpty {
                return AgentExecutionResult(
                    success: true,
                    toolName: name,
                    outcome: .completedVerified,
                    outputPayload: [
                        "query": query,
                        "found_count": 0,
                        "results": [],
                        "message": "No search results found for '\(query)'."
                    ],
                    error: nil,
                    confirmationToken: nil,
                    executionDurationMs: duration
                )
            }

            let snippets = structuredItems.map { "\($0.title)\n\($0.snippet)\nSource: \($0.url)" }
            let summary = snippets.joined(separator: "\n\n")

            return AgentExecutionResult.success(
                tool: name,
                verified: true,
                payload: [
                    "query": query,
                    "found_count": structuredItems.count,
                    "results": snippets,
                    "summary": summary
                ],
                durationMs: duration
            )

        } catch is CancellationError {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Web search was cancelled by user.",
                outcome: .cancelled,
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        } catch let urlError as URLError where urlError.code == .cancelled {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Web search network request was cancelled.",
                outcome: .cancelled,
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        } catch let urlError as URLError where urlError.code == .timedOut {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Web search request timed out.",
                outcome: .timedOut,
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        } catch {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Network search failed: \(error.localizedDescription)",
                outcome: .failed,
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }
    }

    private func extractStructuredResults(from html: String, limit: Int) -> [SearchResultItem] {
        var items: [SearchResultItem] = []

        // Extract individual result blocks
        let resultBlockPattern = #"<div class="result[^"]*">([\s\S]*?)<\/div>\s*<\/div>"#
        guard let blockRegex = try? NSRegularExpression(pattern: resultBlockPattern, options: []) else {
            return []
        }

        let matches = blockRegex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
        for match in matches.prefix(limit) {
            guard let blockRange = Range(match.range(at: 1), in: html) else { continue }
            let block = String(html[blockRange])

            // 1. Extract title and URL
            var title = ""
            var url = ""
            let titlePattern = #"<a class="result__url"[^>]*href="([^"]*)"[^>]*>([\s\S]*?)<\/a>"#
            if let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: []),
               let titleMatch = titleRegex.firstMatch(in: block, options: [], range: NSRange(location: 0, length: block.utf16.count)) {
                if let uRange = Range(titleMatch.range(at: 1), in: block) {
                    url = String(block[uRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let tRange = Range(titleMatch.range(at: 2), in: block) {
                    title = cleanHtml(String(block[tRange]))
                }
            }

            // 2. Extract snippet
            var snippet = ""
            let snippetPattern = #"class="result__snippet[^>]*>([\s\S]*?)<\/a>"#
            if let snippetRegex = try? NSRegularExpression(pattern: snippetPattern, options: []),
               let sMatch = snippetRegex.firstMatch(in: block, options: [], range: NSRange(location: 0, length: block.utf16.count)),
               let sRange = Range(sMatch.range(at: 1), in: block) {
                snippet = cleanHtml(String(block[sRange]))
            }

            if !snippet.isEmpty {
                items.append(SearchResultItem(
                    title: title.isEmpty ? "Search Result" : title,
                    url: url,
                    snippet: snippet
                ))
            }
        }

        return items
    }

    private func cleanHtml(_ raw: String) -> String {
        raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
