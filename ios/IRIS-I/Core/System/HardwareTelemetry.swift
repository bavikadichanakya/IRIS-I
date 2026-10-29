//
//  HardwareTelemetry.swift
//  IRIS-I
//
//  Gathers physical memory footprint via task_info, thermal states, and inference metrics.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import Darwin

public struct MemoryTelemetry: Sendable {
    public let physicalFootprintMB: Double // The exact metric iOS Jetsam uses for OOM termination
    public let residentSizeMB: Double
    public let maxRecommendedFootprintMB: Double // Baseline safety ceiling (~3500 MB on 8GB base)

    public var isNearCeiling: Bool {
        physicalFootprintMB > (maxRecommendedFootprintMB * 0.85)
    }
}

public struct InferenceTelemetry: Sendable {
    public let timeToFirstTokenMs: Double
    public let generationTokensPerSecond: Double
    public let promptTokenCount: Int
    public let generatedTokenCount: Int
    public let durationSeconds: Double
    public let physicalMemoryMB: Double
    public let thermalState: ProcessInfo.ThermalState
    public let isMockEngine: Bool // Strictly distinguishes mocked tests from physical Metal inference

    public static let zero = InferenceTelemetry(
        timeToFirstTokenMs: 0,
        generationTokensPerSecond: 0,
        promptTokenCount: 0,
        generatedTokenCount: 0,
        durationSeconds: 0,
        physicalMemoryMB: 0,
        thermalState: .nominal,
        isMockEngine: false
    )
}

public final class HardwareTelemetry: Sendable {
    public static let shared = HardwareTelemetry()

    /// Reads real physical memory footprint directly from Darwin kernel task_vm_info
    public func currentMemoryUsage() -> MemoryTelemetry {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)

        let kerr = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let footprintBytes = Double(info.phys_footprint)
            let residentBytes = Double(info.resident_size)
            let footprintMB = footprintBytes / (1024.0 * 1024.0)
            let residentMB = residentBytes / (1024.0 * 1024.0)

            return MemoryTelemetry(
                physicalFootprintMB: footprintMB,
                residentSizeMB: residentMB,
                maxRecommendedFootprintMB: 3500.0 // Conservative safe ceiling for iPhone 17 (8GB)
            )
        }

        return MemoryTelemetry(
            physicalFootprintMB: 0,
            residentSizeMB: 0,
            maxRecommendedFootprintMB: 3500.0
        )
    }

    public var thermalState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }

    public var thermalDescription: String {
        switch thermalState {
        case .nominal: return "Nominal (Optimal)"
        case .fair: return "Fair (Mild Load)"
        case .serious: return "Serious (Throttling Active)"
        case .critical: return "Critical (Immediate Cooldown Required)"
        @unknown default: return "Unknown"
        }
    }
}
