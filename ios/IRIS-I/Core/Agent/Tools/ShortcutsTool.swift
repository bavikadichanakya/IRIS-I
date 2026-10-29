//
//  ShortcutsTool.swift
//  IRIS-I
//
//  Executes user-configured Apple Shortcuts via shortcuts:// scheme to pull or push
//  data across third-party applications (Notes, Spotify, WhatsApp, HomeKit, etc.).
//

import Foundation
import UIKit

public struct ShortcutsTool: IRISAgentTool {
    public let name = "ShortcutsTool"
    public let description = "Executes Apple Siri Shortcuts to trigger multi-app workflows, pull notes, or control services."
    public let category = "automation"
    public let permissionLevel = PermissionLevel.protectedLevel

    public let parametersSchema = ToolParameterSchema(
        type: "object",
        properties: [
            "shortcut_name": ToolPropertySchema(
                type: "string",
                description: "The exact name of the shortcut in your iOS Shortcuts library"
            ),
            "input_text": ToolPropertySchema(
                type: "string",
                description: "Optional text or parameters to pass into the shortcut"
            )
        ],
        required: ["shortcut_name"]
    )

    public init() {}

    public func execute(arguments: [String: Any]) async -> AgentExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        guard let name = arguments["shortcut_name"] as? String, !name.isEmpty else {
            return AgentExecutionResult.failure(
                tool: self.name,
                error: "Missing required 'shortcut_name' parameter.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        let input = arguments["input_text"] as? String

        var targetString = "shortcuts://run-shortcut?name=" + (name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)
        if let input = input, !input.isEmpty {
            let encodedInput = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
            targetString += "&input=text&text=\(encodedInput)"
        }

        guard let url = URL(string: targetString) else {
            return AgentExecutionResult.failure(
                tool: self.name,
                error: "Failed to construct valid Shortcuts URL.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        let opened = await MainActor.run {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return true
            }
            return false
        }

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        if opened {
            return AgentExecutionResult.success(
                tool: self.name,
                verified: false,
                payload: [
                    "shortcut_name": name,
                    "message": "Triggered Apple Shortcut '\(name)'."
                ],
                durationMs: duration
            )
        } else {
            return AgentExecutionResult.failure(
                tool: self.name,
                error: "Apple Shortcuts app is not accessible or installed on this device.",
                durationMs: duration
            )
        }
    }
}

