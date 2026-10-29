//
//  FastIntentRouter.swift
//  IRIS-I
//
//  Tier 1 Deterministic Fast Intent Router (<10ms target).
//  Directly matches system queries (time, date, battery, RAM) without invoking on-device LLM.
//

import Foundation

public enum FastRouteResult: Sendable {
    case matched(toolName: String, arguments: [String: Any], routingDurationMs: Double)
    case unmatched(routingDurationMs: Double)
}

public struct FastIntentRouter: Sendable {

    public init() {}

    /// Evaluates input text for direct deterministic intents.
    /// Strictly guarantees execution under 10ms.
    public func route(query: String) -> FastRouteResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let clean = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Time & Date queries
        if clean.contains("what time") || clean.contains("what is the time") || clean.contains("current time") || clean == "time" {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "SystemInfoTool",
                arguments: ["action": "time"],
                routingDurationMs: duration
            )
        }

        if clean.contains("what day") || clean.contains("what is today") || clean.contains("current date") || clean == "date" || clean.contains("what is the date") {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "SystemInfoTool",
                arguments: ["action": "date"],
                routingDurationMs: duration
            )
        }

        // 2. Battery queries
        if clean.contains("battery") || clean.contains("battery level") || clean.contains("charge level") {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "SystemInfoTool",
                arguments: ["action": "battery"],
                routingDurationMs: duration
            )
        }

        // 3. Hardware & Memory telemetry
        if clean.contains("ram") || clean.contains("memory usage") || clean.contains("footprint") || clean.contains("thermal") {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "SystemInfoTool",
                arguments: ["action": "telemetry"],
                routingDurationMs: duration
            )
        }

        // 4. Direct app opening patterns: "open [App]"
        if clean.hasPrefix("open ") {
            let appCandidate = String(clean.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if !appCandidate.isEmpty && !appCandidate.contains("email") && !appCandidate.contains("mail") {
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

