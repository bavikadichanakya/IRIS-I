//
//  AppOpenerTool.swift
//  IRIS-I
//
//  Tool interfacing with AppLaunchRegistry to open verified apps and system settings.
//

import Foundation
import UIKit

public struct AppOpenerTool: IRISAgentTool {
    public let name = "AppOpenerTool"
    public let description = "Opens verified iOS applications (e.g. Maps, Spotify, YouTube, Settings) using standard URL schemes."
    public let category = "navigation"
    public let permissionLevel = PermissionLevel.protectedLevel

    public let parametersSchema = ToolParameterSchema(
        type: "object",
        properties: [
            "app_name": ToolPropertySchema(
                type: "string",
                description: "Name of the app to launch (e.g., 'Maps', 'Spotify', 'YouTube', 'Settings', 'Messages')"
            ),
            "parameter": ToolPropertySchema(
                type: "string",
                description: "Optional query or deep link parameter (e.g., location query for Maps)"
            )
        ],
        required: ["app_name"]
    )

    public init() {}

    public func operationType(for arguments: [String: Any]) -> ActionOperationType {
        return .read
    }

    public func execute(arguments: [String: Any]) async -> AgentExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        guard let appName = arguments["app_name"] as? String, !appName.isEmpty else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Missing required 'app_name' parameter.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        let parameter = arguments["parameter"] as? String

        do {
            let url = try await AppLaunchRegistry.shared.launchApp(name: appName, parameter: parameter)
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            return AgentExecutionResult.success(
                tool: name,
                verified: false, // Dispatched to OS; internal outcome within target app is unobservable
                payload: [
                    "app_name": appName,
                    "dispatched_url": url.absoluteString,
                    "message": "Opened \(appName) on your device."
                ],
                durationMs: duration
            )
        } catch let err as AppLaunchError {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return AgentExecutionResult.failure(
                tool: name,
                error: err.localizedDescription,
                outcome: .deniedPolicy,
                durationMs: duration
            )
        } catch {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return AgentExecutionResult.failure(
                tool: name,
                error: "Failed to open \(appName): \(error.localizedDescription)",
                durationMs: duration
            )
        }
    }
}

