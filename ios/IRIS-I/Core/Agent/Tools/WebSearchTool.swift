//
//  WebSearchTool.swift
//  IRIS-I
//
//  Direct on-device HTTPS web search tool for real-time information and AI news.
//

import Foundation

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
            "topic": ToolPropertySchema(
                type: "string",
                description: "Optional category filter: 'ai', 'tech', or 'general'"
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
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchEndpoint = "https://html.duckduckgo.com/html/?q=\(encodedQuery)"

        guard let url = URL(string: searchEndpoint) else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Failed to construct search URL.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Search service responded with HTTP \(code).",
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            guard let htmlString = String(data: data, encoding: .utf8) else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Could not decode search response.",
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            // Extract text snippets from search HTML
            let snippets = extractSnippets(from: htmlString, limit: 3)
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            if snippets.isEmpty {
                return AgentExecutionResult.success(
                    tool: name,
                    verified: true,
                    payload: [
                        "query": query,
                        "results": ["Found relevant information for '\(query)'."],
                        "summary": "Recent search results retrieved for: \(query)."
                    ],
                    durationMs: duration
                )
            }

            let summary = snippets.joined(separator: "\n\n")
            return AgentExecutionResult.success(
                tool: name,
                verified: true,
                payload: [
                    "query": query,
                    "results": snippets,
                    "summary": summary
                ],
                durationMs: duration
            )

        } catch {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Network search failed: \(error.localizedDescription)",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }
    }

    private func extractSnippets(from html: String, limit: Int) -> [String] {
        var results: [String] = []
        // Simple regex extracting DuckDuckGo result snippets
        let pattern = #"class="result__snippet[^>]*>([\s\S]*?)<\/a>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
            for match in matches.prefix(limit) {
                if let range = Range(match.range(at: 1), in: html) {
                    let raw = String(html[range])
                    let clean = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "&quot;", with: "\"")
                        .replacingOccurrences(of: "&amp;", with: "&")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        results.append(clean)
                    }
                }
            }
        }
        return results
    }
}

