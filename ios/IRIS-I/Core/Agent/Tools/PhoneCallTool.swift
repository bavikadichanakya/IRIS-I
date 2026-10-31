//
//  PhoneCallTool.swift
//  IRIS-I
//
//  On-device tool for initiating outgoing phone calls via Apple tel: URL scheme.
//  Strictly enforces sensitive approval policy prior to external OS dialer handoff.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct PhoneCallTool: IRISAgentTool {
    public let name = "PhoneCallTool"
    public let description = "Initiates outgoing voice phone calls to phone numbers or contacts with explicit user authorization."
    public let category = "communication"
    public let permissionLevel = PermissionLevel.protectedLevel

    public let parametersSchema = ToolParameterSchema(
        type: "object",
        properties: [
            "phone_number": ToolPropertySchema(
                type: "string",
                description: "Target phone number to dial (e.g. '+14155552671' or '555-0199')"
            ),
            "contact_name": ToolPropertySchema(
                type: "string",
                description: "Optional display name of the contact being called"
            )
        ],
        required: ["phone_number"]
    )

    public init() {}

    public func operationType(for arguments: [String: Any]) -> ActionOperationType {
        return .send
    }

    public func execute(arguments: [String: Any]) async -> AgentExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        guard let rawNumber = arguments["phone_number"] as? String, !rawNumber.isEmpty else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Missing required 'phone_number' argument.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        let contactName = arguments["contact_name"] as? String ?? rawNumber

        // Clean phone number: remove spaces, dashes, parentheses
        let sanitized = rawNumber.components(separatedBy: CharacterSet(charactersIn: "0123456789+*#").inverted).joined()

        guard !sanitized.isEmpty, let telURL = URL(string: "tel://\(sanitized)") else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Invalid phone number format: '\(rawNumber)'.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        #if canImport(UIKit)
        let opened = await MainActor.run {
            if UIApplication.shared.canOpenURL(telURL) {
                UIApplication.shared.open(telURL)
                return true
            }
            return false
        }
        #else
        let opened = false
        #endif

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        if opened {
            return AgentExecutionResult.success(
                tool: name,
                verified: false, // External handoff to iOS phone dialer; outcome cannot be verified from sandbox
                payload: [
                    "phone_number": sanitized,
                    "contact_name": contactName,
                    "message": "Initiating call to \(contactName) (\(sanitized))."
                ],
                durationMs: duration
            )
        } else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Telephony is not supported on this device (e.g. iPad or Simulator without cellular calling capability).",
                durationMs: duration
            )
        }
    }
}
