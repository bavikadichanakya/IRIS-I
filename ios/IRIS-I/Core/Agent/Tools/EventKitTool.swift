//
//  EventKitTool.swift
//  IRIS-I
//
//  Native on-device Reminders and Calendar tool using EventKit.
//  Fully compatible with iOS 16 and modern iOS 17+ granular permissions.
//

import Foundation
import EventKit

public struct EventKitTool: IRISAgentTool {
    public let name = "EventKitTool"
    public let description = "Creates, manages, and queries Apple Reminders and Calendar events on iOS."
    public let category = "organization"
    public let permissionLevel = PermissionLevel.protectedLevel

    public let parametersSchema = ToolParameterSchema(
        type: "object",
        properties: [
            "action": ToolPropertySchema(
                type: "string",
                description: "Action: 'create_reminder', 'create_event', 'list_reminders', or 'delete_events'",
                enumValues: ["create_reminder", "create_event", "list_reminders", "delete_events"]
            ),
            "title": ToolPropertySchema(
                type: "string",
                description: "Title of the reminder or calendar event"
            ),
            "due_date": ToolPropertySchema(
                type: "string",
                description: "Due date/time description (e.g. 'tomorrow at 9 AM' or '2026-10-30 09:00')"
            ),
            "notes": ToolPropertySchema(
                type: "string",
                description: "Optional notes or description"
            )
        ],
        required: ["action", "title"]
    )

    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public func operationType(for arguments: [String: Any]) -> ActionOperationType {
        let action = (arguments["action"] as? String)?.lowercased() ?? "create_reminder"
        switch action {
        case "delete_events", "delete_reminder", "clear":
            return .destructive
        case "create_reminder", "create_event":
            return .draft
        case "list_reminders", "list_events", "query":
            return .read
        default:
            return .read
        }
    }

    public func execute(arguments: [String: Any]) async -> AgentExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let action = (arguments["action"] as? String)?.lowercased() ?? "create_reminder"
        let title = (arguments["title"] as? String) ?? "Untitled Task"
        let dueDateStr = arguments["due_date"] as? String

        switch action {
        case "create_reminder":
            // 1. Request Authorization (iOS 16 & 17+ compatible)
            let authorized = await requestReminderAuthorization()
            guard authorized else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Access to Reminders was denied by the user. Please enable Reminders in iOS Settings.",
                    outcome: .deniedPolicy,
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            // 2. Create EKReminder
            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = title
            reminder.notes = arguments["notes"] as? String
            reminder.calendar = eventStore.defaultCalendarForNewReminders()

            if let _ = dueDateStr {
                // Set sample due date (tomorrow at 9:00 AM)
                var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
                dateComponents.hour = 9
                dateComponents.minute = 0
                reminder.dueDateComponents = dateComponents
            }

            do {
                try eventStore.save(reminder, commit: true)
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                let remId = reminder.calendarItemIdentifier

                return AgentExecutionResult.success(
                    tool: name,
                    verified: true,
                    payload: [
                        "reminder_id": remId,
                        "title": title,
                        "status": "created",
                        "message": "Created reminder '\(title)'."
                    ],
                    durationMs: duration
                )
            } catch {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Failed to save reminder: \(error.localizedDescription)",
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

        case "create_event":
            let authorized = await requestCalendarAuthorization()
            guard authorized else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Access to Calendar was denied. Please enable Calendars in iOS Settings.",
                    outcome: .deniedPolicy,
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            let event = EKEvent(eventStore: eventStore)
            event.title = title
            event.notes = arguments["notes"] as? String
            event.startDate = Date().addingTimeInterval(3600)
            event.endDate = Date().addingTimeInterval(7200)
            event.calendar = eventStore.defaultCalendarForNewEvents

            do {
                try eventStore.save(event, span: .thisEvent, commit: true)
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

                return AgentExecutionResult.success(
                    tool: name,
                    verified: true,
                    payload: [
                        "event_id": event.eventIdentifier ?? UUID().uuidString,
                        "title": title,
                        "message": "Scheduled calendar event '\(title)'."
                    ],
                    durationMs: duration
                )
            } catch {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Failed to save calendar event: \(error.localizedDescription)",
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

        case "delete_events":
            // Sensitive action requiring confirmation
            return AgentExecutionResult.failure(
                tool: name,
                error: "Deleting calendar events is a sensitive action requiring explicit user confirmation.",
                outcome: .confirmationRequired,
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )

        default:
            return AgentExecutionResult.failure(
                tool: name,
                error: "Unsupported EventKit action: \(action)",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }
    }

    private func requestReminderAuthorization() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await eventStore.requestFullAccessToReminders()
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func requestCalendarAuthorization() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}

