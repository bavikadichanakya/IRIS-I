//
//  MessagingTool.swift
//  IRIS-I
//
//  Standalone tool for composing and sending text messages on iOS via standard sms: scheme.
//

import Foundation
import UIKit

public struct MessagingTool: IRISAgentTool {
    public let name = "MessagingTool"
    public let description = "Composes SMS or iMessage text messages to contacts or phone numbers."
    public let category = "communication"
    public let permissionLevel = PermissionLevel.protectedLevel

    public let parametersSchema = ToolParameterSchema(
        type: "object",
        properties: [
            "recipient": ToolPropertySchema(
                type: "string",
                description: "Phone number or contact name"
            ),
            "message": ToolPropertySchema(
                type: "string",
                description: "Body text of the message to send"
            )
        ],
        required: ["message"]
    )

    public init() {}

    public func operationType(for arguments: [String: Any]) -> ActionOperationType {
        // External message dispatch represents a sensitive send action
        return .send
    }

    public func execute(arguments: [String: Any]) async -> AgentExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        guard let message = arguments["message"] as? String, !message.isEmpty else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Missing required 'message' text argument.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        let recipient = arguments["recipient"] as? String ?? ""

        // Build documented sms: URL scheme
        var urlString = "sms:"
        if !recipient.isEmpty {
            urlString += recipient
        }
        let encodedBody = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? message
        urlString += "&body=\(encodedBody)"

        guard let smsURL = URL(string: urlString) else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Failed to construct valid SMS URL.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        let opened = await MainActor.run {
            if UIApplication.shared.canOpenURL(smsURL) {
                UIApplication.shared.open(smsURL)
                return true
            }
            return false
        }

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        if opened {
            return AgentExecutionResult.success(
                tool: name,
                verified: false, // Handoff completed, outcome inside Messages app unobservable
                payload: [
                    "recipient": recipient,
                    "message": "Dispatched message draft to iOS Messages: \"\(message)\""
                ],
                durationMs: duration
            )
        } else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "iOS Messages app is not available on this device (e.g. simulator without cellular/iMessage).",
                durationMs: duration
            )
        }
    }
}

