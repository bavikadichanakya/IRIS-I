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

    private static let validGreetingQueries: Set<String> = [
        "hello", "hi", "hey", "hey iris", "iris",
        "good morning", "good afternoon", "good evening",
        "how are you", "how are you doing", "what's up", "whats up"
    ]

    private static let validCapabilitiesQueries: Set<String> = [
        "who are you", "what are you", "what can you do", "help",
        "what are your capabilities", "what can iris do", "what is iris",
        "capabilities", "how do you work"
    ]

    private static let validDirectMediaQueries: Set<String> = [
        "play music", "play some music", "play songs", "play a song",
        "music", "apple music", "open music", "open apple music"
    ]

    private static let validDirectCameraQueries: Set<String> = [
        "take a photo", "take photo", "take a picture", "take picture",
        "camera", "open camera", "take photos"
    ]

    private static let validSingleAppNames: [String: String] = [
        "youtube": "YouTube",
        "spotify": "Spotify",
        "settings": "Settings",
        "camera": "Camera",
        "photos": "Photos",
        "maps": "Maps",
        "messages": "Messages",
        "notes": "Notes",
        "calendar": "Calendar",
        "reminders": "Reminders",
        "whatsapp": "WhatsApp",
        "telegram": "Telegram",
        "facetime": "FaceTime",
        "chatgpt": "ChatGPT",
        "twitter": "Twitter",
        "instagram": "Instagram",
        "tiktok": "TikTok",
        "slack": "Slack",
        "discord": "Discord",
        "reddit": "Reddit",
        "safari": "Safari",
        "calculator": "Calculator",
        "calc": "Calculator",
        "clock": "Clock",
        "podcasts": "Podcasts"
    ]

    private static let wakeAndCourtesyPrefixes: [String] = [
        "hey iris, ", "hey iris ", "iris, ", "iris ",
        "please tell me ", "tell me ", "can you tell me ", "could you tell me ",
        "can you check ", "could you check ", "check ",
        "show me ", "get me "
    ]

    private static let launchVerbPrefixes: [String] = [
        "open up ", "open ",
        "launch ",
        "start ",
        "take me to ",
        "bring up ",
        "switch to ",
        "go to ",
        "jump to ",
        "show me ",
        "can you open ", "could you open ", "please open ",
        "can you launch ", "could you launch ", "please launch ",
        "can you take me to ", "please take me to ",
        "i want to open ", "i want to use "
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

        // 5. Greeting queries
        if Self.validGreetingQueries.contains(clean) {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "SystemInfoTool",
                arguments: ["action": "greeting"],
                routingDurationMs: duration
            )
        }

        // 6. Capabilities queries
        if Self.validCapabilitiesQueries.contains(clean) {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "SystemInfoTool",
                arguments: ["action": "capabilities"],
                routingDurationMs: duration
            )
        }

        // 7. Direct media / music phrases
        if Self.validDirectMediaQueries.contains(clean) {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "AppOpenerTool",
                arguments: ["app_name": "Music"],
                routingDurationMs: duration
            )
        }

        // 8. Direct camera / photo phrases
        if Self.validDirectCameraQueries.contains(clean) {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "AppOpenerTool",
                arguments: ["app_name": "Camera"],
                routingDurationMs: duration
            )
        }

        // 9. Direct single-app names
        if let canonicalName = Self.validSingleAppNames[clean] {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return .matched(
                toolName: "AppOpenerTool",
                arguments: ["app_name": canonicalName],
                routingDurationMs: duration
            )
        }

        // 10. Generalized app opening patterns
        var appCandidate = ""
        for prefix in Self.launchVerbPrefixes {
            if clean.hasPrefix(prefix) {
                appCandidate = String(clean.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        if appCandidate.hasPrefix("the ") {
            appCandidate = String(appCandidate.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        } else if appCandidate.hasPrefix("my ") {
            appCandidate = String(appCandidate.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }

        if appCandidate.hasSuffix(" app") {
            appCandidate = String(appCandidate.dropLast(4)).trimmingCharacters(in: .whitespaces)
        }

        if !appCandidate.isEmpty && appCandidate.count <= 30 {
            let words = appCandidate.split(separator: " ").map(String.init)
            let containsStopword = words.contains { Self.invalidAppStopwords.contains($0) }

            // Guard against arbitrary physical sentences like "open the door" or "open a debate"
            if !containsStopword && words.count <= 3 {
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
