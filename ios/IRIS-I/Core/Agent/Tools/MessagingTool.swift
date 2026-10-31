//
//  MessagingTool.swift
//  IRIS-I
//
//  Standalone tool for composing text messages on iOS via standard sms: scheme.
//  Integrates Contacts resolution, recipient validation, and native composer handoff.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import Contacts

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
        required: ["recipient", "message"]
    )

    public init() {}

    public func operationType(for arguments: [String: Any]) -> ActionOperationType {
        // External message dispatch represents a sensitive send action
        return .send
    }

    public func execute(arguments: [String: Any]) async -> AgentExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let rawRecipient = (arguments["recipient"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !rawRecipient.isEmpty else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Missing required 'recipient' destination argument.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        guard let message = (arguments["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Missing required 'message' text argument.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        // 1. Resolve recipient if it contains alphabetic characters (contact name)
        var resolvedNumber = rawRecipient
        let hasLetters = rawRecipient.rangeOfCharacter(from: CharacterSet.letters) != nil
        if hasLetters {
            let contactsTool = ContactsTool()
            let searchRes = await contactsTool.execute(arguments: ["action": "search_contacts", "query": rawRecipient])
            if let countStr = searchRes.outputPayload["matches_count"] as? String, let count = Int(countStr) {
                if count == 0 {
                    return AgentExecutionResult.failure(
                        tool: name,
                        error: "Could not find any contact matching '\(rawRecipient)'. Please provide a phone number or exact contact name.",
                        durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                    )
                } else if count > 1 {
                    let desc = (searchRes.outputPayload["message"] as? String) ?? "Multiple contacts found."
                    return AgentExecutionResult.failure(
                        tool: name,
                        error: "\(desc). Please specify the full name.",
                        durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                    )
                } else if let phone = searchRes.outputPayload["primary_phone"] as? String, !phone.isEmpty {
                    resolvedNumber = phone
                } else {
                    return AgentExecutionResult.failure(
                        tool: name,
                        error: "Contact '\(rawRecipient)' was found but has no phone number.",
                        durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                    )
                }
            }
        }

        // Sanitize phone digits
        let cleanNumber = resolvedNumber.components(separatedBy: CharacterSet(charactersIn: "0123456789+").inverted).joined()

        // 2. Build documented Apple URL scheme using URLComponents with proper query delimiter
        var components = URLComponents()
        components.scheme = "sms"
        components.path = cleanNumber.isEmpty ? resolvedNumber : cleanNumber
        components.queryItems = [
            URLQueryItem(name: "body", value: message)
        ]

        guard let smsURL = components.url else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Failed to construct valid SMS URL.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        #if canImport(UIKit)
        let opened = await MainActor.run {
            if UIApplication.shared.canOpenURL(smsURL) {
                UIApplication.shared.open(smsURL)
                return true
            }
            return false
        }
        #else
        let opened = false
        #endif

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        if opened {
            // External handoff: Messages app opened draft, internal user send action is unverifiable
            return AgentExecutionResult(
                success: true,
                toolName: name,
                outcome: .completedUnverified,
                outputPayload: [
                    "recipient": rawRecipient,
                    "resolved_number": cleanNumber.isEmpty ? resolvedNumber : cleanNumber,
                    "message": "Opened native Messages composer with draft: \"\(message)\". Review and tap Send."
                ],
                durationMs: duration,
                verified: false
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
