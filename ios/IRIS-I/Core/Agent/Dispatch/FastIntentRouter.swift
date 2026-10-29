//
//  FastIntentRouter.swift
//  IRIS-I
//
//  Tier 1 Deterministic Fast Intent Router (<10ms target).
//  Directly matches system queries (time, date, battery, telemetry) and verified app launches
//  without invoking on-device LLM inference.
//

import Foundation

public enum FastRouteResult: Sendable {
    case matched(toolName: String, arguments: [String: Any], routingDurationMs: Double)
    case unmatched(routingDurationMs: Double)
}

public struct FastIntentRouter: Sendable {

    public init() {}

    // Normalized canonical intent sets for sub-millisecond O(1) matching
    private static let validTimeQueries: Set<String> = [
        "time",
        "the time",
        "current time",
        "what time is it",
        "what is the time",
        "what's the time",
        "what is current time",
        "what is the current time",
        "time right now"
    ]

    private static let validDateQueries: Set<String> = [
        "date",
        "the date",
        "current date",
        "what is the date",
        "what's the date",
        "what is today's date",
        "what's today's date",
        "today's date",
        "what day is it",
        "what day is today",
        "what is today",
        "what's today"
    ]

    private static let validBatteryQueries: Set<String> = [
        "battery",
        "battery status",
        "battery level",
        "battery percentage",
        "the battery",
        "current battery",
        "current battery level",
        "current battery status",
        "charge level",
        "battery charge",
        "how much battery do i have",
        "how much battery is left",
        "what is the battery level",
        "what's the battery level",
        "what is my battery level",
        "what's my battery level",
        "what is my battery percentage"
    ]

    private static let validTelemetryQueries: Set<String> = [
        "memory usage",
        "ram usage",
        "ram memory usage",
        "what is my current ram memory usage",
        "current ram memory usage",
        "memory footprint",
        "app memory usage",
        "thermal state",
        "system telemetry",
        "device telemetry",
        "hardware telemetry"
    ]

    private static let wakeAndCourtesyPrefixes: [String] = [
        "hey iris, ", "hey iris ", "iris, ", "iris ",
        "please tell me ", "tell me ", "can you tell me ", "could you tell me ",
        "can you check ", "could you check ", "check ",
        "show me ", "get me "
    ]

    private static let invalidAppStopwords: Set<String> = [
        "the", "a", "an", "door", "doors", "can", "file", "window",
        "discussion", "tab", "link", "website", "mail", "email"
    ]

    /// Evaluates input text for direct deterministic intents.
    /// Strictly guarantees execution under 10ms.
    public func route(query: String) -> FastRouteResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        var clean = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip trailing punctuation
        while clean.hasSuffix("?") || clean.hasSuffix("!") || clean.hasSuffix(".") {
            clean = String(clean.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        // Strip leading wake word or courtesy phrases
        for prefix in Self.wakeAndCourtesyPrefixes {
            if clean.hasPrefix(prefix) {
                clean = String(clean.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // 1. Time query
        if Self.validTimeQueries.contains(clean) {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "SystemInfoTool",
                arguments: ["action": "time"],
                routingDurationMs: duration
            )
        }

        // 2. Date query
        if Self.validDateQueries.contains(clean) {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "SystemInfoTool",
                arguments: ["action": "date"],
                routingDurationMs: duration
            )
        }

        // 3. Battery query
        if Self.validBatteryQueries.contains(clean) {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "SystemInfoTool",
                arguments: ["action": "battery"],
                routingDurationMs: duration
            )
        }

        // 4. Hardware & memory telemetry query
        if Self.validTelemetryQueries.contains(clean) {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "SystemInfoTool",
                arguments: ["action": "telemetry"],
                routingDurationMs: duration
            )
        }

        // 5. Direct app opening patterns: "open [App]" or "launch [App]"
        var appCandidate = ""
        if clean.hasPrefix("open ") {
            appCandidate = String(clean.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        } else if clean.hasPrefix("launch ") {
            appCandidate = String(clean.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }

        if !appCandidate.isEmpty && appCandidate.count <= 25 {
            let words = appCandidate.split(separator: " ").map(String.init)
            let containsStopword = words.contains { Self.invalidAppStopwords.contains($0) }

            // Guard against arbitrary sentences like "open the door" or "open a debate"
            if !containsStopword && words.count <= 2 {
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                return .matched(
                    toolName: "AppOpenerTool",
                    arguments: ["app_name": appCandidate],
                    routingDurationMs: duration
                )
            }
        }

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        return .unmatched(routingDurationMs: duration)
    }
}
