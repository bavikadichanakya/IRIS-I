//
//  MockModelEngine.swift
//  IRIS-I
//
//  Deterministic in-process mock engine for unit testing and simulator runs without model weights.
//  Explicitly flags all emitted telemetry with isMockEngine = true.
//

import Foundation

public actor MockModelEngine: ModelEngineProtocol {
    public let isMockEngine: Bool = true

    private var currentManifest: ModelManifest?
    private var currentContextSize: Int = 2048
    private var isCancelled: Bool = false
    private var lastTelemetry: InferenceTelemetry = .zero

    public init() {}

    public var isLoaded: Bool {
        currentManifest != nil
    }

    public var loadedManifest: ModelManifest? {
        currentManifest
    }

    public var activeContextSize: Int {
        currentContextSize
    }

    public func load(
        manifest: ModelManifest,
        fileURL: URL,
        contextSize: Int,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        progress?(0.2)
        try await Task.sleep(nanoseconds: 80_000_000)
        progress?(0.6)
        try await Task.sleep(nanoseconds: 80_000_000)
        self.currentManifest = manifest
        self.currentContextSize = contextSize
        progress?(1.0)
    }

    public func unload() async {
        self.currentManifest = nil
        self.currentContextSize = 0
    }

    public func cancel() async {
        self.isCancelled = true
    }

    public func generateStream(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        self.isCancelled = false

        return AsyncThrowingStream { continuation in
            Task {
                guard self.isLoaded else {
                    continuation.finish(throwing: EngineError.uninitialized)
                    return
                }

                let startTime = Date()
                let simulatedTTFTMs: Double = 120.0
                try? await Task.sleep(nanoseconds: UInt64(simulatedTTFTMs * 1_000_000))

                // Determine appropriate deterministic response based on prompt
                let responseTokens: [String]
                let low = prompt.lowercased()

                if low.contains("remind me") {
                    responseTokens = [
                        "{\n",
                        "  \"thought\": \"User wants to create a reminder.\",\n",
                        "  \"action\": {\n",
                        "    \"tool\": \"EventKitTool\",\n",
                        "    \"parameters\": {\n",
                        "      \"action\": \"create_reminder\",\n",
                        "      \"title\": \"check the server logs\",\n",
                        "      \"due_date\": \"tomorrow 09:00\"\n",
                        "    }\n",
                        "  }\n",
                        "}"
                    ]
                } else if low.contains("lights are on") {
                    responseTokens = [
                        "{\n",
                        "  \"thought\": \"Checking status of living room light.\",\n",
                        "  \"action\": {\n",
                        "    \"tool\": \"HomeAssistantTool\",\n",
                        "    \"parameters\": {\n",
                        "      \"domain\": \"light\",\n",
                        "      \"action\": \"status\",\n",
                        "      \"entity_id\": \"light.living_room\"\n",
                        "    }\n",
                        "  }\n",
                        "}"
                    ]
                } else if low.contains("delete all") {
                    responseTokens = [
                        "{\n",
                        "  \"thought\": \"Action is sensitive and requires confirmation.\",\n",
                        "  \"action\": {\n",
                        "    \"tool\": \"PlanManager\",\n",
                        "    \"parameters\": {\n",
                        "      \"summary\": \"Delete calendar events\",\n",
                        "      \"requires_confirmation\": true\n",
                        "    }\n",
                        "  }\n",
                        "}"
                    ]
                } else {
                    responseTokens = [
                        "IRIS-I ", "Local ", "Orchestrator ", "active ", "on ", "iPhone ", "17 ", "(A19). ",
                        "Running ", "100% ", "on-device ", "with ", "zero ", "cloud ", "fallback. ",
                        "Hardware ", "telemetry ", "is ", "nominal."
                    ]
                }

                var generatedCount = 0

                for token in responseTokens {
                    if self.isCancelled {
                        continuation.finish(throwing: EngineError.generationCancelled)
                        return
                    }

                    continuation.yield(token)
                    generatedCount += 1
                    try? await Task.sleep(nanoseconds: 35_000_000) // ~28 tokens/sec simulated
                }

                let totalDuration = Date().timeIntervalSince(startTime)
                let tps = totalDuration > 0 ? Double(generatedCount) / totalDuration : 0.0
                let mem = HardwareTelemetry.shared.currentMemoryUsage()

                self.lastTelemetry = InferenceTelemetry(
                    timeToFirstTokenMs: simulatedTTFTMs,
                    generationTokensPerSecond: tps,
                    promptTokenCount: prompt.split(separator: " ").count,
                    generatedTokenCount: generatedCount,
                    durationSeconds: totalDuration,
                    physicalMemoryMB: mem.physicalFootprintMB,
                    thermalState: .nominal,
                    isMockEngine: true // Explicitly marked as mock test engine
                )

                continuation.finish()
            }
        }
    }

    public func latestTelemetry() async -> InferenceTelemetry {
        self.lastTelemetry
    }
}
