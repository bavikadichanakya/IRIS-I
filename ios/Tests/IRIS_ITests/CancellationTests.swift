//
//  CancellationTests.swift
//  IRIS-ITests
//
//  Unit tests verifying generation streaming, prompt cancellation, actor recovery,
//  and subsequent inference.
//

import XCTest
@testable import IRIS_I

final class CancellationTests: XCTestCase {
    var runner: LocalModelRunner!

    override func setUp() async throws {
        try await super.setUp()
        runner = LocalModelRunner()
        try await runner.loadModel(manifest: ModelCatalog.shared.baseline3B, contextSize: 2048, forceMockEngine: true)
    }

    override func tearDown() async throws {
        await runner.unloadModel()
        runner = nil
        try await super.tearDown()
    }

    func testStreamingGenerationCompletesNormally() async throws {
        let stream = await runner.generateStream(prompt: "Hello IRIS", maxTokens: 64, temperature: 0.7)
        var tokenCount = 0

        for try await _ in stream {
            tokenCount += 1
        }

        XCTAssertGreaterThan(tokenCount, 0, "Should emit tokens")
        let telemetry = await runner.latestTelemetry()
        XCTAssertGreaterThan(telemetry.generationTokensPerSecond, 0)
        XCTAssertTrue(telemetry.isMockEngine, "Must be flagged as mock engine")
    }

    func testCancelHaltsGenerationStream() async throws {
        let stream = await runner.generateStream(prompt: "Tell me a very long story about robotics", maxTokens: 256, temperature: 0.7)

        Task {
            try? await Task.sleep(nanoseconds: 30_000_000) // 30 ms
            await runner.cancelGeneration()
        }

        var tokensBeforeCancel = 0
        do {
            for try await _ in stream {
                tokensBeforeCancel += 1
            }
        } catch {
            // Expected cancellation or clean halt
        }

        XCTAssertLessThan(tokensBeforeCancel, 256, "Stream must halt early when cancelled")

        // Critical verification: Runner MUST recover cleanly and immediately execute subsequent prompt
        let nextStream = await runner.generateStream(prompt: "Subsequent prompt after cancel", maxTokens: 16, temperature: 0.1)
        var recoveredTokens = 0
        for try await _ in nextStream {
            recoveredTokens += 1
        }
        XCTAssertGreaterThan(recoveredTokens, 0, "Actor must recover and execute subsequent prompt cleanly")
    }

    func testRepeatedCancellationsAndSubsequentRuns() async throws {
        for _ in 1...3 {
            let stream = await runner.generateStream(prompt: "Quick cancel test", maxTokens: 128, temperature: 0.7)
            await runner.cancelGeneration()

            do {
                for try await _ in stream {}
            } catch {}

            // Immediate subsequent prompt
            let subsequent = await runner.generateStream(prompt: "Recovery", maxTokens: 8, temperature: 0.1)
            var count = 0
            for try await _ in subsequent {
                count += 1
            }
            XCTAssertGreaterThan(count, 0)
        }
    }

    func testUnloadDuringActiveInferenceHaltsCleanly() async throws {
        let stream = await runner.generateStream(prompt: "Long generation", maxTokens: 256, temperature: 0.7)

        Task {
            try? await Task.sleep(nanoseconds: 20_000_000)
            await runner.unloadModel()
        }

        do {
            for try await _ in stream {}
        } catch {
            // Stream should terminate
        }

        XCTAssertFalse(await runner.isModelLoaded, "Model must be cleanly unloaded")
    }
}
