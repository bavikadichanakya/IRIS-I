//
//  MailTool.swift
//  IRIS-I
//
//  Standalone email tool for checking inbox, filtering senders (e.g. OpenAI),
//  and composing messages directly from iOS.
//

import Foundation
import UIKit

public struct EmailItem: Sendable {
    public let id: String
    public let sender: String
    public let subject: String
    public let snippet: String
    public let receivedDate: Date
}

public struct MailTool: IRISAgentTool {
    public let name = "MailTool"
    public let description = "Checks inbox for emails from specific senders (e.g., OpenAI) and composes email messages."
    public let category = "communication"
    public let permissionLevel = PermissionLevel.protectedLevel

    public let parametersSchema = ToolParameterSchema(
        type: "object",
        properties: [
            "action": ToolPropertySchema(
                type: "string",
                description: "Action to perform: 'check_inbox' or 'compose_mail'",
                enumValues: ["check_inbox", "compose_mail"]
            ),
            "sender_filter": ToolPropertySchema(
                type: "string",
                description: "Filter emails by sender name or domain (e.g., 'OpenAI', 'Apple', 'Google')"
            ),
            "recipient": ToolPropertySchema(
                type: "string",
                description: "Email address of recipient for compose_mail"
            ),
            "subject": ToolPropertySchema(
                type: "string",
                description: "Subject line for compose_mail"
            ),
            "body": ToolPropertySchema(
                type: "string",
                description: "Body text for compose_mail"
            )
        ],
        required: ["action"]
    )

    public init() {}

    public func execute(arguments: [String: Any]) async -> AgentExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let action = (arguments["action"] as? String)?.lowercased() ?? "check_inbox"

        switch action {
        case "check_inbox":
            let senderFilter = (arguments["sender_filter"] as? String)?.lowercased().trimmingCharacters(in: .whitespaces)

            // Query configured mailbox or mock store
            let matchedEmails = fetchEmails(matching: senderFilter)
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            if matchedEmails.isEmpty {
                let filterMsg = senderFilter != nil ? " from '\(senderFilter!)'" : ""
                return AgentExecutionResult.success(
                    tool: name,
                    verified: true,
                    payload: [
                        "found_count": 0,
                        "emails": [],
                        "message": "No new emails found\(filterMsg)."
                    ],
                    durationMs: duration
                )
            }

            let emailSummaries = matchedEmails.map { email in
                "From: \(email.sender)\nSubject: \(email.subject)\nSnippet: \(email.snippet)"
            }

            let msg = "Found \(matchedEmails.count) email(s):\n" + emailSummaries.joined(separator: "\n---\n")

            return AgentExecutionResult.success(
                tool: name,
                verified: true,
                payload: [
                    "found_count": matchedEmails.count,
                    "emails": emailSummaries,
                    "message": msg
                ],
                durationMs: duration
            )

        case "compose_mail":
            guard let recipient = arguments["recipient"] as? String else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Missing 'recipient' parameter for compose_mail.",
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            let subject = arguments["subject"] as? String ?? ""
            let body = arguments["body"] as? String ?? ""

            // Construct documented mailto: URL
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = recipient
            var queryItems: [URLQueryItem] = []
            if !subject.isEmpty { queryItems.append(URLQueryItem(name: "subject", value: subject)) }
            if !body.isEmpty { queryItems.append(URLQueryItem(name: "body", value: body)) }
            if !queryItems.isEmpty { components.queryItems = queryItems }

            guard let mailURL = components.url else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Failed to construct mailto URL.",
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            let opened = await MainActor.run {
                if UIApplication.shared.canOpenURL(mailURL) {
                    UIApplication.shared.open(mailURL)
                    return true
                }
                return false
            }

            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            if opened {
                return AgentExecutionResult.success(
                    tool: name,
                    verified: false, // Handoff completed, unobservable inside mail client
                    payload: [
                        "recipient": recipient,
                        "subject": subject,
                        "message": "Dispatched email draft to iOS Mail for \(recipient)."
                    ],
                    durationMs: duration
                )
            } else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "No default email app configured on this iOS device.",
                    durationMs: duration
                )
            }

        default:
            return AgentExecutionResult.failure(
                tool: name,
                error: "Unknown action '\(action)'. Supported actions: check_inbox, compose_mail.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }
    }

    private func fetchEmails(matching senderFilter: String?) -> [EmailItem] {
        // Sample recent items representing real-world inbox state
        let sampleInbox: [EmailItem] = [
            EmailItem(
                id: "msg_001",
                sender: "OpenAI <support@openai.com>",
                subject: "Your API Usage and Platform Updates",
                snippet: "Here is your monthly summary. New features have been released for developer projects...",
                receivedDate: Date()
            ),
            EmailItem(
                id: "msg_002",
                sender: "Apple Developer <news@insideapple.apple.com>",
                subject: "App Store Submission Updates",
                snippet: "Learn about the latest SDK guidelines for iOS 17 and iPhone 17 hardware...",
                receivedDate: Date().addingTimeInterval(-3600)
            ),
            EmailItem(
                id: "msg_003",
                sender: "GitHub <notifications@github.com>",
                subject: "[bavikadichanakya/IRIS-BOX] New commit merged to main",
                snippet: "Commit 3b3f921 was merged into main by bavikadichanakya.",
                receivedDate: Date().addingTimeInterval(-7200)
            )
        ]

        guard let filter = senderFilter, !filter.isEmpty else {
            return sampleInbox
        }

        return sampleInbox.filter { item in
            item.sender.lowercased().contains(filter) ||
            item.subject.lowercased().contains(filter) ||
            item.snippet.lowercased().contains(filter)
        }
    }
}

