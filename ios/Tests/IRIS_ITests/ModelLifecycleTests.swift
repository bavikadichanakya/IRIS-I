//
//  ModelLifecycleTests.swift
//  IRIS-ITests
//
//  Unit tests verifying single-model residency, loading, unloading,
//  failed load handling, repeated load/unload cycles, and model switching failure.
//

import XCTest
#if canImport(IRIS_ICore)
@testable import IRIS_ICore
#elseif canImport(IRIS_I)
@testable import IRIS_I
#endif

final class ModelLifecycleTests: XCTestCase {
    var runner: LocalModelRunner!

    override func setUp() async throws {
        try await super.setUp()
        runner = LocalModelRunner()
    }

    override func tearDown() async throws {
        await runner.unloadModel()
        runner = nil
        try await super.tearDown()
    }

    func testInitialStateIsUnloaded() async {
        let isLoaded = await runner.isModelLoaded
        let state = await runner.state
        XCTAssertFalse(isLoaded, "Engine should initially be unloaded")
        XCTAssertEqual(state, .uninstalled)
    }

    func testLoadBaselineModelTransitionsToReady() async throws {
        let catalog = ModelCatalog.shared
        try await runner.loadModel(manifest: catalog.baseline3B, contextSize: 2048, forceMockEngine: true)

        let isLoaded = await runner.isModelLoaded
        let state = await runner.state
        let ctx = await runner.currentContextSize
        let isMock = await runner.isUsingMockEngine

        XCTAssertTrue(isLoaded)
        XCTAssertEqual(state, .ready(contextSize: 2048))
        XCTAssertEqual(ctx, 2048)
        XCTAssertTrue(isMock, "Mock engine must be explicitly flagged")
    }

    func testFailedModelLoadWhenFileNotFound() async throws {
        let catalog = ModelCatalog.shared

        // Attempting to load without forceMockEngine when no GGUF file is installed must throw
        do {
            try await runner.loadModel(manifest: catalog.baseline3B, contextSize: 2048, forceMockEngine: false)
            XCTFail("Should have thrown failedToLoadModel when no GGUF file exists on disk")
        } catch {
            let isLoaded = await runner.isModelLoaded
            let state = await runner.state

            XCTAssertFalse(isLoaded, "Must not report loaded on failure")
            if case .failed(let msg) = state {
                XCTAssertTrue(msg.contains("not found") || msg.contains("failed"), "State must record failure reason: \(msg)")
            } else {
                XCTFail("State must be .failed on load error, got: \(state)")
            }
        }
    }

    func testRepeatedLoadAndUnloadCycles() async throws {
        let catalog = ModelCatalog.shared

        for cycle in 1...10 {
            try await runner.loadModel(manifest: catalog.baseline3B, contextSize: 2048, forceMockEngine: true)
            XCTAssertTrue(await runner.isModelLoaded, "Cycle \(cycle): Must be loaded")

            await runner.unloadModel()
            XCTAssertFalse(await runner.isModelLoaded, "Cycle \(cycle): Must be unloaded cleanly")
            XCTAssertNil(await runner.currentManifest, "Cycle \(cycle): Manifest must be nil after unload")
        }
    }

    func testSingleModelResidencyEnforcedOnSwitch() async throws {
        let catalog = ModelCatalog.shared

        // Load Baseline 3B
        try await runner.loadModel(manifest: catalog.baseline3B, contextSize: 2048, forceMockEngine: true)
        let firstManifest = await runner.currentManifest
        XCTAssertEqual(firstManifest?.id, catalog.baseline3B.id)

        // Switch to Experimental 7B
        try await runner.switchModel(to: catalog.experimental7B, contextSize: 2048, forceMockEngine: true)
        let secondManifest = await runner.currentManifest
        XCTAssertEqual(secondManifest?.id, catalog.experimental7B.id)
        XCTAssertNotEqual(firstManifest?.id, secondManifest?.id)

        let isLoaded = await runner.isModelLoaded
        XCTAssertTrue(isLoaded)
    }

    func testModelSwitchingFailureCleansState() async throws {
        let catalog = ModelCatalog.shared

        // Start with a loaded baseline mock
        try await runner.loadModel(manifest: catalog.baseline3B, contextSize: 2048, forceMockEngine: true)
        XCTAssertTrue(await runner.isModelLoaded)

        // Attempt switch to real engine with non-existent file
        do {
            try await runner.switchModel(to: catalog.experimental7B, contextSize: 2048, forceMockEngine: false)
            XCTFail("Switching to missing model file must throw")
        } catch {
            let isLoaded = await runner.isModelLoaded
            let state = await runner.state

            XCTAssertFalse(isLoaded, "Must not leave previous or new model loaded on failure")
            if case .failed(let err) = state {
                XCTAssertTrue(err.contains("Model switch failed"))
            } else {
                XCTFail("State must be .failed on switch failure")
            }
        }
    }

    func testUnloadFreesState() async throws {
        let catalog = ModelCatalog.shared
        try await runner.loadModel(manifest: catalog.baseline3B, contextSize: 2048, forceMockEngine: true)
        XCTAssertTrue(await runner.isModelLoaded)

        await runner.unloadModel()
        XCTAssertFalse(await runner.isModelLoaded)
        XCTAssertNil(await runner.currentManifest)
    }
}
