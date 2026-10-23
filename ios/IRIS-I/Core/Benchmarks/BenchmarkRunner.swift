//
//  BenchmarkRunner.swift
//  IRIS-I
//
//  Executes physical and mock benchmark suites and captures telemetry.
//

import Foundation

public actor BenchmarkRunner {
    public static let shared = BenchmarkRunner()

    public func runSuite(
        scenarios: [BenchmarkScenario] = BenchmarkScenario.standardSuite,
        runner: LocalModelRunner = .shared
    ) async -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        for scenario in scenarios {
            let start = Date()
            var accumulated = ""
            var passed = false
            var reason = ""

            let isMock = await runner.isUsingMockEngine

            do {
                let stream = await runner.generateStream(prompt: scenario.prompt, maxTokens: 128, temperature: 0.1)
                for try await token in stream {
                    accumulated += token
                }

                (passed, reason) = scenario.validator(accumulated)
            } catch {
                passed = false
                reason = "Execution error: \(error.localizedDescription)"
            }

            let duration = Date().timeIntervalSince(start) * 1000.0
            let mem = HardwareTelemetry.shared.currentMemoryUsage()

            results.append(
                BenchmarkResult(
                    id: UUID().uuidString,
                    scenarioId: scenario.id,
                    scenarioName: scenario.name,
                    prompt: scenario.prompt,
                    rawOutput: accumulated,
                    passed: passed,
                    reason: reason,
                    durationMs: duration,
                    memoryMB: mem.physicalFootprintMB,
                    isMockEngine: isMock
                )
            )
        }

        // Test TC-5: Cancellation Responsiveness
        let cancelStart = Date()
        let isMock = await runner.isUsingMockEngine
        var cancelPassed = false
        var cancelReason = ""

        let stream = await runner.generateStream(prompt: "Generate a 1000 word essay about artificial intelligence.", maxTokens: 512, temperature: 0.7)

        Task {
            try? await Task.sleep(nanoseconds: 80_000_000) // 80 ms
            await runner.cancelGeneration()
        }

        do {
            var tokenCount = 0
            for try await _ in stream {
                tokenCount += 1
            }
            // If it finishes without cancellation throwing or finishes early
            cancelPassed = tokenCount < 50
            cancelReason = "Cancelled after \(tokenCount) tokens."
        } catch {
            cancelPassed = true
            cancelReason = "Cancellation stopped stream cleanly: \(error.localizedDescription)"
        }

        let cancelDuration = Date().timeIntervalSince(cancelStart) * 1000.0
        let mem = HardwareTelemetry.shared.currentMemoryUsage()

        results.append(
            BenchmarkResult(
                id: UUID().uuidString,
                scenarioId: "TC-5",
                scenarioName: "Cancellation Responsiveness",
                prompt: "Generate long essay -> cancel after 80ms",
                rawOutput: "Stream aborted as requested.",
                passed: cancelPassed,
                reason: cancelReason,
                durationMs: cancelDuration,
                memoryMB: mem.physicalFootprintMB,
                isMockEngine: isMock
            )
        )

        return results
    }
}
