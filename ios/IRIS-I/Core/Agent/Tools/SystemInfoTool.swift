//
//  SystemInfoTool.swift
//  IRIS-I
//
//  Native on-device tool reporting current system time, date, battery,
//  application memory footprint (Jetsam metric), and device thermal state.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct SystemInfoTool: IRISAgentTool {
    public let name = "SystemInfoTool"
    public let description = "Returns real-time system clock, date, device battery status, application RAM footprint, and thermal status."
    public let category = "system"
    public let permissionLevel = PermissionLevel.publicLevel

    public let parametersSchema = ToolParameterSchema(
        type: "object",
        properties: [
            "action": ToolPropertySchema(
                type: "string",
                description: "The information to retrieve: 'time', 'date', 'battery', or 'telemetry'",
                enumValues: ["time", "date", "battery", "telemetry"]
            )
        ],
        required: ["action"]
    )

    public init() {}

    public func operationType(for arguments: [String: Any]) -> ActionOperationType {
        return .read
    }

    public func execute(arguments: [String: Any]) async -> AgentExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let action = (arguments["action"] as? String)?.lowercased() ?? "time"

        switch action {
        case "time":
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            formatter.dateStyle = .none
            let timeStr = formatter.string(from: Date())
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            return AgentExecutionResult.success(
                tool: name,
                verified: true,
                payload: [
                    "current_time": timeStr,
                    "message": "The current time is \(timeStr)."
                ],
                durationMs: duration
            )

        case "date":
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .none
            let dateStr = formatter.string(from: Date())
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            return AgentExecutionResult.success(
                tool: name,
                verified: true,
                payload: [
                    "current_date": dateStr,
                    "message": "Today is \(dateStr)."
                ],
                durationMs: duration
            )

        case "battery":
            #if canImport(UIKit)
            let (level, stateStr) = await MainActor.run {
                UIDevice.current.isBatteryMonitoringEnabled = true
                let lvl = Int(UIDevice.current.batteryLevel * 100)
                let st: String
                switch UIDevice.current.batteryState {
                case .charging: st = "Charging"
                case .full: st = "Full"
                case .unplugged: st = "Unplugged (On Battery)"
                default: st = "Unknown"
                }
                return (lvl, st)
            }
            #else
            let level = 100
            let stateStr = "External Power"
            #endif
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            let batteryMsg = level >= 0 ? "Battery is at \(level)%, status: \(stateStr)." : "Battery level unavailable in simulator."

            return AgentExecutionResult.success(
                tool: name,
                verified: true,
                payload: [
                    "battery_level_percent": max(0, level),
                    "battery_state": stateStr,
                    "message": batteryMsg
                ],
                durationMs: duration
            )

        case "telemetry":
            let mem = HardwareTelemetry.shared.currentMemoryUsage()
            let thermal = HardwareTelemetry.shared.thermalDescription
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            let msg = "App physical footprint: \(Int(mem.physicalFootprintMB)) MB (Jetsam safety limit: \(Int(mem.maxRecommendedFootprintMB)) MB). Thermal state: \(thermal)."

            return AgentExecutionResult.success(
                tool: name,
                verified: true,
                payload: [
                    "app_physical_footprint_mb": mem.physicalFootprintMB,
                    "resident_size_mb": mem.residentSizeMB,
                    "safety_ceiling_mb": mem.maxRecommendedFootprintMB,
                    "thermal_state": thermal,
                    "message": msg
                ],
                durationMs: duration
            )

        default:
            return AgentExecutionResult.failure(
                tool: name,
                error: "Unknown action '\(action)'. Supported actions: time, date, battery, telemetry.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }
    }
}

