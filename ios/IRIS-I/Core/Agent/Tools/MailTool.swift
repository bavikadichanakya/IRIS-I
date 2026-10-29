//
//  MailTool.swift
//  IRIS-I
//
//  Standalone email tool for searching inboxes (e.g. OpenAI emails), creating drafts,
//  and sending authenticated emails directly from iOS via linked providers (Gmail).
//  Explicitly distinguishes local drafts from sent messages and returns 'not_connected'
//  when no mail account is linked.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct MailTool: IRISAgentTool {
    public let name = "MailTool"
    public let description = "Accesses authenticated mailboxes to check inbox, search emails (e.g., from OpenAI), create drafts, or send messages."
    public let category = "communication"
    public let permissionLevel = PermissionLevel.protectedLevel

    public let parametersSchema = ToolParameterSchema(
        type: "object",
        properties: [
            "action": ToolPropertySchema(
                type: "string",
                description: "Action to perform: 'check_inbox', 'compose_mail', 'create_draft', or 'send_email'",
                enumValues: ["check_inbox", "compose_mail", "create_draft", "send_email"]
            ),
            "sender_filter": ToolPropertySchema(
                type: "string",
                description: "Filter emails by sender name or domain (e.g., 'OpenAI', 'Apple', 'Google')"
            ),
            "recipient": ToolPropertySchema(
                type: "string",
                description: "Email address of recipient for compose_mail, create_draft, or send_email"
            ),
            "subject": ToolPropertySchema(
                type: "string",
                description: "Subject line for the email"
            ),
            "body": ToolPropertySchema(
                type: "string",
                description: "Body content of the email"
            )
        ],
        required: ["action"]
    )

    private let provider: any MailProviderProtocol

    public init(provider: any MailProviderProtocol = GmailConnector.shared) {
        self.provider = provider
    }

    public func operationType(for arguments: [String: Any]) -> ActionOperationType {
        let action = (arguments["action"] as? String)?.lowercased() ?? "check_inbox"
        switch action {
        case "check_inbox", "search":
            return .read
        case "compose_mail", "create_draft":
            return .draft
        case "send_email", "send":
            return .send
        default:
            return .read
        }
    }

    public func execute(arguments: [String: Any]) async -> AgentExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let action = (arguments["action"] as? String)?.lowercased() ?? "check_inbox"

        switch action {
        case "check_inbox":
            let senderFilter = (arguments["sender_filter"] as? String)?.trimmingCharacters(in: .whitespaces)

            let state = await provider.state
            guard state.isConnected else {
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                return AgentExecutionResult(
                    success: false,
                    toolName: name,
                    outcome: .failed,
                    outputPayload: [
                        "status": "not_connected",
                        "message": "No email account is linked. To check your email or search for messages, please link your Gmail account in IRIS-I Settings."
                    ],
                    error: "Mail provider is not connected.",
                    confirmationToken: nil,
                    executionDurationMs: duration
                )
            }

            var query = ""
            if let filter = senderFilter, !filter.isEmpty {
                query = "from:\(filter)"
            }

            do {
                let messages = try await provider.searchMessages(query: query, maxResults: 5)
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

                if messages.isEmpty {
                    let filterMsg = senderFilter != nil ? " from '\(senderFilter!)'" : ""
                    return AgentExecutionResult.success(
                        tool: name,
                        verified: true,
                        payload: [
                            "found_count": 0,
                            "emails": [],
                            "message": "No new emails found\(filterMsg) in your connected mailbox."
                        ],
                        durationMs: duration
                    )
                }

                let emailSummaries = messages.map { email in
                    "From: \(email.sender)\nSubject: \(email.subject)\nSnippet: \(email.snippet)"
                }

                let summaryText = "Found \(messages.count) email(s):\n" + emailSummaries.joined(separator: "\n---\n")

                return AgentExecutionResult.success(
                    tool: name,
                    verified: true,
                    payload: [
                        "found_count": messages.count,
                        "emails": emailSummaries,
                        "message": summaryText
                    ],
                    durationMs: duration
                )
            } catch {
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Failed to search inbox: \(error.localizedDescription)",
                    durationMs: duration
                )
            }

        case "compose_mail":
            // System mailto URL scheme (draft handoff)
            guard let recipient = arguments["recipient"] as? String, !recipient.isEmpty else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Missing 'recipient' parameter for compose_mail.",
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            let subject = arguments["subject"] as? String ?? ""
            let body = arguments["body"] as? String ?? ""

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
                    error: "Failed to construct valid mailto URL.",
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            #if canImport(UIKit)
            let opened = await MainActor.run {
                if UIApplication.shared.canOpenURL(mailURL) {
                    UIApplication.shared.open(mailURL)
                    return true
                }
                return false
            }
            #else
            let opened = false
            #endif

            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            if opened {
                return AgentExecutionResult(
                    success: true,
                    toolName: name,
                    outcome: .completedUnverified,
                    outputPayload: [
                        "status": "handed_off_unverified",
                        "recipient": recipient,
                        "subject": subject,
                        "message": "Opened email draft in default iOS Mail app for \(recipient). Note: Completion within Mail app cannot be verified."
                    ],
                    error: nil,
                    confirmationToken: nil,
                    executionDurationMs: duration
                )
            } else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "No default email app configured on this iOS device.",
                    durationMs: duration
                )
            }

        case "create_draft":
            guard let recipient = arguments["recipient"] as? String, !recipient.isEmpty else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Missing 'recipient' parameter for create_draft.",
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            let subject = arguments["subject"] as? String ?? "(No Subject)"
            let body = arguments["body"] as? String ?? ""

            let state = await provider.state
            guard state.isConnected else {
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                return AgentExecutionResult(
                    success: false,
                    toolName: name,
                    outcome: .failed,
                    outputPayload: [
                        "status": "not_connected",
                        "message": "No email account is linked. Please link your Gmail account in IRIS-I Settings to create cloud drafts."
                    ],
                    error: "Mail provider is not connected.",
                    confirmationToken: nil,
                    executionDurationMs: duration
                )
            }

            do {
                let draftId = try await provider.createDraft(recipient: recipient, subject: subject, body: body)
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                return AgentExecutionResult.success(
                    tool: name,
                    verified: true,
                    payload: [
                        "draft_id": draftId,
                        "recipient": recipient,
                        "subject": subject,
                        "message": "Draft created successfully in your linked Gmail account (Draft ID: \(draftId))."
                    ],
                    durationMs: duration
                )
            } catch {
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Failed to create draft: \(error.localizedDescription)",
                    durationMs: duration
                )
            }

        case "send_email":
            guard let recipient = arguments["recipient"] as? String, !recipient.isEmpty else {
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Missing 'recipient' parameter for send_email.",
                    durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                )
            }

            let subject = arguments["subject"] as? String ?? ""
            let body = arguments["body"] as? String ?? ""

            let state = await provider.state
            guard state.isConnected else {
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                return AgentExecutionResult(
                    success: false,
                    toolName: name,
                    outcome: .failed,
                    outputPayload: [
                        "status": "not_connected",
                        "message": "No email account is linked. Please link your Gmail account in IRIS-I Settings to send emails."
                    ],
                    error: "Mail provider is not connected.",
                    confirmationToken: nil,
                    executionDurationMs: duration
                )
            }

            do {
                let messageId = try await provider.sendEmail(recipient: recipient, subject: subject, body: body)
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                return AgentExecutionResult.success(
                    tool: name,
                    verified: true,
                    payload: [
                        "message_id": messageId,
                        "recipient": recipient,
                        "subject": subject,
                        "message": "Email sent successfully via Gmail API to \(recipient) (Message ID: \(messageId))."
                    ],
                    durationMs: duration
                )
            } catch {
                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                return AgentExecutionResult.failure(
                    tool: name,
                    error: "Failed to send email: \(error.localizedDescription)",
                    durationMs: duration
                )
            }

        default:
            return AgentExecutionResult.failure(
                tool: name,
                error: "Unknown action '\(action)'. Supported actions: check_inbox, compose_mail, create_draft, send_email.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }
    }
}
