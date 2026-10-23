//
//  TelemetryBarView.swift
//  IRIS-I
//
//  Compact real-time hardware and inference telemetry bar.
//

import SwiftUI

public struct TelemetryBarView: View {
    public let telemetry: InferenceTelemetry
    public let memory: MemoryTelemetry
    public let thermalState: String

    public init(telemetry: InferenceTelemetry, memory: MemoryTelemetry, thermalState: String) {
        self.telemetry = telemetry
        self.memory = memory
        self.thermalState = thermalState
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Mode Banner
            HStack {
                Circle()
                    .fill(telemetry.isMockEngine ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)

                Text(telemetry.isMockEngine ? "TEST HARNESS (MOCK ENGINE)" : "PHYSICAL INFERENCE (A19 METAL)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(telemetry.isMockEngine ? .orange : .green)

                Spacer()

                Text("Thermal: \(thermalState)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Metrics Grid
            HStack(spacing: 16) {
                MetricItem(
                    title: "TTFT",
                    value: telemetry.timeToFirstTokenMs > 0 ? String(format: "%.0f ms", telemetry.timeToFirstTokenMs) : "--"
                )

                Divider().frame(height: 24)

                MetricItem(
                    title: "SPEED",
                    value: telemetry.generationTokensPerSecond > 0 ? String(format: "%.1f tps", telemetry.generationTokensPerSecond) : "--"
                )

                Divider().frame(height: 24)

                MetricItem(
                    title: "FOOTPRINT",
                    value: memory.physicalFootprintMB > 0 ? String(format: "%.0f MB", memory.physicalFootprintMB) : "--",
                    highlight: memory.isNearCeiling ? .red : .primary
                )

                Divider().frame(height: 24)

                MetricItem(
                    title: "TOKENS",
                    value: "\(telemetry.generatedTokenCount)"
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

private struct MetricItem: View {
    let title: String
    let value: String
    var highlight: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(highlight)
        }
    }
}
