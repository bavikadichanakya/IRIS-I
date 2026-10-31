//
//  TaskScheduler.swift
//  IRIS-I
//
//  Autonomous task scheduler generating daily briefings and proactive assistant alerts
//  by querying EventKit, HardwareTelemetry, and PersonalMemoryStore.
//

import Foundation

public struct DailyBriefing: Sendable {
    public let greeting: String
    public let batteryStatus: String
    public let upcomingEventsCount: Int
    public let pendingRemindersCount: Int
    public let summaryText: String
    public let timestamp: Date
}

public final class TaskScheduler: @unchecked Sendable {
    public static let shared = TaskScheduler()

    private let notifications = NotificationManager.shared
    private let memory = PersonalMemoryStore.shared
    private let eventKitTool = EventKitTool()

    private init() {}

    /// Compiles a comprehensive daily briefing from local device telemetry, calendar, and reminders
    public func generateDailyBriefing() async -> DailyBriefing {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        if hour < 12 {
            greeting = "Good morning"
        } else if hour < 17 {
            greeting = "Good afternoon"
        } else {
            greeting = "Good evening"
        }

        let battery = await HardwareTelemetry.shared.getTelemetry()
        let batteryDesc = "\(Int(battery.batteryLevel * 100))% (\(battery.batteryState))"

        // Query upcoming events
        let eventsResult = await eventKitTool.execute(arguments: ["action": "list_events"])
        let eventsDesc = (eventsResult.outputPayload["message"] as? String) ?? "Calendar clear"
        let eventsCount = Int((eventsResult.outputPayload["count"] as? String) ?? "0") ?? 0

        // Query pending reminders
        let remindersResult = await eventKitTool.execute(arguments: ["action": "list_reminders"])
        let remindersDesc = (remindersResult.outputPayload["message"] as? String) ?? "No pending tasks"
        let remindersCount = Int((remindersResult.outputPayload["count"] as? String) ?? "0") ?? 0

        var summary = "\(greeting)! Battery is at \(batteryDesc). \(eventsDesc). \(remindersDesc)."

        let briefing = DailyBriefing(
            greeting: greeting,
            batteryStatus: batteryDesc,
            upcomingEventsCount: eventsCount,
            pendingRemindersCount: remindersCount,
            summaryText: summary,
            timestamp: Date()
        )

        return briefing
    }

    /// Triggers a proactive briefing and posts a local notification
    public func triggerProactiveBriefing() async {
        let briefing = await generateDailyBriefing()

        // Schedule immediate local notification
        try? await notifications.scheduleNotification(
            identifier: "iris.briefing.\(UUID().uuidString.prefix(8))",
            title: "\(briefing.greeting), Sir",
            body: briefing.summaryText,
            timeInterval: 1.0
        )
    }
}
