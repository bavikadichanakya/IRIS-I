//
//  EventKitTool.swift
//  IRIS-I
//
//  Native on-device Reminders and Calendar tool using EventKit.
//  Integrated with NaturalDateInterpreter for deterministic date parsing.
//  Fully compatible with iOS 16 and modern iOS 17+ granular permissions.
//

import Foundation
import EventKit

public struct EventKitTool: IRISAgentTool {
    public let name = "EventKitTool"
    public let description = "Creates, queries, and manages Apple Reminders and Calendar events on iOS."
    public let category = "organization"
    public let permissionLevel = PermissionLevel.protectedLevel

    public let parametersSchema = ToolParameterSchema(
        type: "object",
        properties: [
            "action": ToolPropertySchema(
                type: "string",
                description: "Action: 'create_reminder', 'create_event', 'list_reminders', 'list_events', or 'delete_events'",
                enumValues: ["create_reminder", "create_event", "list_reminders", "list_events", "delete_events"]
            ),
            "title": ToolPropertySchema(
                type: "string",
                description: "Title or query filter for the reminder or calendar event"
            ),
            "due_date": ToolPropertySchema(
                type: "string",
                description: "Due date/time description (e.g. 'tomorrow at 4:30 PM', 'in 45 minutes', 'next Monday at 10 AM')"
            ),
            "notes": ToolPropertySchema(
                type: "string",
                description: "Optional notes or location details"
            )
        ],
        required: ["action"]
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
        let title = (arguments["title"] as? String) ?? "Untitled"
        let dueDateStr = arguments["due_date"] as? String

        switch action {
        case "create_reminder":
            let authorized = await requestReminderAuthorization()
            guard authorized else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Access to Reminders was denied by the user. Please enable Reminders in iOS Settings.",
                    outcome: .deniedPolicy,
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = title
            reminder.notes = arguments["notes"] as? String
            reminder.calendar = eventStore.defaultCalendarForNewReminders()

            var parsedDesc = "No specific due date"
            if let dateStr = dueDateStr, let parsed = NaturalDateInterpreter.parse(dateStr) {
                reminder.dueDateComponents = parsed.dateComponents
                let df = DateFormatter()
                df.dateStyle = .medium
                df.timeStyle = parsed.isTimeSpecified ? .short : .none
                parsedDesc = df.string(from: parsed.date)

                if parsed.isTimeSpecified {
                    let alarm = EKAlarm(absoluteDate: parsed.date)
                    reminder.addAlarm(alarm)
                }
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
                        "due_date": parsedDesc,
                        "status": "created",
                        "message": "Created reminder '\(title)' for \(parsedDesc)."
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
            event.calendar = eventStore.defaultCalendarForNewEvents

            var startDate = Date().addingTimeInterval(3600)
            if let dateStr = dueDateStr, let parsed = NaturalDateInterpreter.parse(dateStr) {
                startDate = parsed.date
            }
            event.startDate = startDate
            event.endDate = startDate.addingTimeInterval(3600) // 1 hour duration default

            do {
                try eventStore.save(event, span: .thisEvent, commit: true)
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                let df = DateFormatter()
                df.dateStyle = .medium
                df.timeStyle = .short

                return AgentExecutionResult.success(
                    tool: name,
                    verified: true,
                    payload: [
                        "event_id": event.eventIdentifier ?? UUID().uuidString,
                        "title": title,
                        "scheduled_time": df.string(from: startDate),
                        "message": "Scheduled calendar event '\(title)' at \(df.string(from: startDate))."
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

        case "list_reminders":
            let authorized = await requestReminderAuthorization()
            guard authorized else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Reminders access denied.",
                    outcome: .deniedPolicy,
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
            let reminders = await withCheckedContinuation { (continuation: CheckedContinuation<[EKReminder], Never>) in
                eventStore.fetchReminders(matching: predicate) { list in
                    continuation.resume(returning: list ?? [])
                }
            }

            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            if reminders.isEmpty {
                return AgentExecutionResult.success(
                    tool: name,
                    verified: true,
                    payload: [
                        "count": "0",
                        "message": "No incomplete reminders found."
                    ],
                    durationMs: duration
                )
            }

            let topReminders = reminders.prefix(5).map { $0.title ?? "Untitled" }.joined(separator: ", ")
            return AgentExecutionResult.success(
                tool: name,
                verified: true,
                payload: [
                    "count": "\(reminders.count)",
                    "reminders": topReminders,
                    "message": "You have \(reminders.count) pending reminder(s): \(topReminders)"
                ],
                durationMs: duration
            )

        case "list_events":
            let authorized = await requestCalendarAuthorization()
            guard authorized else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Calendar access denied.",
                    outcome: .deniedPolicy,
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            let now = Date()
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            let predicate = eventStore.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
            let events = eventStore.events(matching: predicate)

            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            if events.isEmpty {
                return AgentExecutionResult.success(
                    tool: name,
                    verified: true,
                    payload: [
                        "count": "0",
                        "message": "No scheduled events on your calendar for today."
                    ],
                    durationMs: duration
                )
            }

            let summary = events.prefix(5).map { "\($0.title ?? "Event") at \(formatTime($0.startDate))" }.joined(separator: "; ")
            return AgentExecutionResult.success(
                tool: name,
                verified: true,
                payload: [
                    "count": "\(events.count)",
                    "events": summary,
                    "message": "Upcoming events today: \(summary)"
                ],
                durationMs: duration
            )

        case "delete_events":
            return AgentExecutionResult.failure(
                tool: name,
                error: "Deleting calendar events is a sensitive operation requiring explicit user confirmation.",
                outcome: .confirmationRequired,
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )

        default:
            return AgentExecutionResult.failure(
                tool: name,
                error: "Unsupported EventKit action: '\(action)'. Supported: create_reminder, create_event, list_reminders, list_events.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }
    }

    private func formatTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        return df.string(from: date)
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
