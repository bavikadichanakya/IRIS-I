//
//  RealEngineIntegrationTests.swift
//  IRIS-ITests
//
//  Tests verifying actual LlamaCppEngine local inference, Metal GPU offloading,
//  real cancellation, and native memory release with physical GGUF weights.
//  Strictly separated from MockModelEngine tests. Never substitutes mock results.
//

import XCTest
#if canImport(IRIS_ICore)
@testable import IRIS_ICore
#elseif canImport(IRIS_I)
@testable import IRIS_I
#endif

final class RealEngineIntegrationTests: XCTestCase {
    var engine: LlamaCppEngine!
    var realModelURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        engine = LlamaCppEngine()
        let catalog = ModelCatalog.shared
        realModelURL = ModelStorageManager.shared.fileURL(for: catalog.baseline3B.filename)
    }

    override func tearDown() async throws {
        if await engine.isLoaded {
            await engine.unload()
        }
        engine = nil
        try await super.tearDown()
    }

    func testRealLlamaCppEngineLoadingAndInference() async throws {
        // Skip explicitly if real GGUF weights have not been imported onto the device yet
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: realModelURL.path),
            "Physical GGUF model weights not found at: \(realModelURL.path). Import a real GGUF model to execute physical inference validation."
        )

        let catalog = ModelCatalog.shared

        // 1. Physical Model Load
        try await engine.load(
            manifest: catalog.baseline3B,
            fileURL: realModelURL,
            contextSize: 2048
        )

        XCTAssertTrue(await engine.isLoaded, "Real LlamaCppEngine must report isLoaded = true")
        XCTAssertFalse(await engine.isMockEngine, "Real engine must never report isMockEngine = true")

        // 2. Real Prompt Streaming Generation (Network-Free)
        let prompt = "Respond in one sentence: What is IRIS-I?"
        let stream = await engine.generateStream(prompt: prompt, maxTokens: 64, temperature: 0.7)

        var generatedText = ""
        var tokenCount = 0

        for try await chunk in stream {
            generatedText += chunk
            tokenCount += 1
        }

        XCTAssertGreaterThan(tokenCount, 0, "Real engine must generate output tokens")
        XCTAssertFalse(generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Generated text must not be empty")

        // 3. Real Telemetry Verification
        let telemetry = await engine.latestTelemetry()
        XCTAssertFalse(telemetry.isMockEngine, "Telemetry must confirm physical inference")
        XCTAssertGreaterThan(telemetry.generationTokensPerSecond, 0, "Tokens per second must be recorded from real inference")
        XCTAssertGreaterThan(telemetry.physicalMemoryMB, 0, "Physical footprint must be recorded from task_vm_info")

        // 4. Real Model Unload & Resource Release
        await engine.unload()
        XCTAssertFalse(await engine.isLoaded, "Real engine must be unloaded cleanly")
        XCTAssertNil(await engine.loadedManifest, "Loaded manifest must be cleared")
    }

    func testRealEngineCancellationAndSubsequentInference() async throws {
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: realModelURL.path),
            "Physical GGUF model weights not found at: \(realModelURL.path). Skipping real cancellation test."
        )

        let catalog = ModelCatalog.shared
        try await engine.load(
            manifest: catalog.baseline3B,
            fileURL: realModelURL,
            contextSize: 2048
        )

        // Cancel mid-generation
        let stream = await engine.generateStream(prompt: "Write a long essay about quantum computing", maxTokens: 512, temperature: 0.7)

        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            await engine.cancel()
        }

        var cancelledCount = 0
        do {
            for try await _ in stream {
                cancelledCount += 1
            }
        } catch {}

        XCTAssertLessThan(cancelledCount, 512, "Real engine stream must halt on cancellation")

        // Subsequent inference must proceed cleanly without engine deadlock or memory leak
        let recoveredStream = await engine.generateStream(prompt: "Say hello", maxTokens: 16, temperature: 0.1)
        var recoveredTokens = 0
        for try await _ in recoveredStream {
            recoveredTokens += 1
        }
        XCTAssertGreaterThan(recoveredTokens, 0, "Real engine must execute subsequent prompt after cancellation")
    }
}
