//
//  LocalModelRunner.swift
//  IRIS-I
//
//  Isolated Swift actor orchestrating on-device model lifecycle, streaming inference,
//  cancellation, model switching, memory-pressure eviction, and telemetry.
//  Strictly enforces single model residency and never silently falls back to mock or remote models.
//

import Foundation

public actor LocalModelRunner {
    public static let shared = LocalModelRunner()

    private var activeEngine: (any ModelEngineProtocol)?
    private var activeManifest: ModelManifest?
    private var activeContextSize: Int = 2048
    private var lifecycleState: ModelLifecycleState = .uninstalled

    private var memoryPressureMonitor: MemoryPressureMonitor?
    private var thermalStateMonitor: ThermalStateMonitor?

    public init() {
        setupSystemMonitors()
    }

    private func setupSystemMonitors() {
        self.memoryPressureMonitor = MemoryPressureMonitor(
            onWarning: { [weak self] in
                Task { [weak self] in
                    await self?.handleMemoryPressureWarning()
                }
            },
            onCritical: { [weak self] in
                Task { [weak self] in
                    await self?.handleMemoryPressureCritical()
                }
            }
        )

        self.thermalStateMonitor = ThermalStateMonitor(
            onStateChanged: { [weak self] state in
                Task { [weak self] in
                    await self?.handleThermalStateChange(state)
                }
            }
        )
    }

    // MARK: - State Introspection

    public var state: ModelLifecycleState {
        lifecycleState
    }

    public var currentManifest: ModelManifest? {
        activeManifest
    }

    public var currentContextSize: Int {
        activeContextSize
    }

    public var isModelLoaded: Bool {
        activeEngine != nil && lifecycleState.isLoaded
    }

    public var isUsingMockEngine: Bool {
        activeEngine?.isMockEngine ?? false
    }

    // MARK: - Model Loading & Lifecycle

    /// Loads a model into memory. Strictly enforces single-model residency.
    /// Never falls back to a mock engine unless `forceMockEngine` is explicitly requested by tests.
    public func loadModel(
        manifest: ModelManifest,
        contextSize: Int = 2048,
        forceMockEngine: Bool = false,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        // Enforce single-model residency
        if isModelLoaded {
            await unloadModel()
        }

        self.lifecycleState = .loading(progress: 0.0)
        let storage = ModelStorageManager.shared
        let fileURL = storage.fileURL(for: manifest.filename)

        // Safety check: Context scaling check
        let mem = HardwareTelemetry.shared.currentMemoryUsage()
        if contextSize > 2048 && mem.isNearCeiling {
            self.lifecycleState = .failed(error: "Context scaling to \(contextSize) blocked: memory near safety limit (\(Int(mem.physicalFootprintMB)) MB)")
            throw EngineError.memoryPressureTermination
        }

        let engine: any ModelEngineProtocol
        if forceMockEngine {
            engine = MockModelEngine()
        } else {
            // Real inference requires an actual GGUF file
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                let err = "Model file not found on disk at: \(fileURL.path). Import a compatible GGUF first."
                self.lifecycleState = .failed(error: err)
                throw EngineError.failedToLoadModel(fileURL.path)
            }
            engine = LlamaCppEngine()
        }

        do {
            try await engine.load(
                manifest: manifest,
                fileURL: fileURL,
                contextSize: contextSize,
                progress: { p in
                    progressHandler?(p)
                }
            )

            self.activeEngine = engine
            self.activeManifest = manifest
            self.activeContextSize = contextSize
            self.lifecycleState = .ready(contextSize: contextSize)
        } catch {
            // Ensure no stale pointers or misleading READY state
            await engine.unload()
            self.activeEngine = nil
            self.activeManifest = nil
            self.activeContextSize = 0
            self.lifecycleState = .failed(error: error.localizedDescription)
            throw error
        }
    }

    /// Safely unloads the active model and releases native resources
    public func unloadModel() async {
        self.lifecycleState = .unloading
        if let engine = activeEngine {
            await engine.unload()
        }
        self.activeEngine = nil

        if let manifest = activeManifest, ModelStorageManager.shared.isModelInstalled(manifest) {
            let size = ModelStorageManager.shared.fileSize(for: manifest) ?? 0
            let url = ModelStorageManager.shared.fileURL(for: manifest.filename)
            self.lifecycleState = .installed(fileURL: url, fileSize: size)
        } else {
            self.lifecycleState = .uninstalled
        }

        self.activeManifest = nil
        self.activeContextSize = 0
    }

    /// Atomically switches between models; if target fails to load, cleans state and reports failure
    public func switchModel(
        to newManifest: ModelManifest,
        contextSize: Int = 2048,
        forceMockEngine: Bool = false
    ) async throws {
        // Unload previous active model first
        await unloadModel()

        do {
            try await loadModel(
                manifest: newManifest,
                contextSize: contextSize,
                forceMockEngine: forceMockEngine
            )
        } catch {
            self.lifecycleState = .failed(error: "Model switch failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Streaming Generation & Cancellation

    public func generateStream(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) async -> AsyncThrowingStream<String, Error> {
        guard let engine = activeEngine, lifecycleState.isLoaded else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: EngineError.uninitialized)
            }
        }

        self.lifecycleState = .inferring(promptSnippet: String(prompt.prefix(40)))

        let stream = await engine.generateStream(
            prompt: prompt,
            maxTokens: maxTokens,
            temperature: temperature
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }
                    self.lifecycleState = .ready(contextSize: self.activeContextSize)
                    continuation.finish()
                } catch {
                    self.lifecycleState = .ready(contextSize: self.activeContextSize)
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func cancelGeneration() async {
        if let engine = activeEngine {
            await engine.cancel()
        }
        self.lifecycleState = .ready(contextSize: self.activeContextSize)
    }

    public func latestTelemetry() async -> InferenceTelemetry {
        if let engine = activeEngine {
            return await engine.latestTelemetry()
        }
        return .zero
    }

    // MARK: - Memory Pressure & Thermal Handlers

    private func handleMemoryPressureWarning() async {
        print("[LocalModelRunner] OS Memory Pressure WARNING received.")
    }

    private func handleMemoryPressureCritical() async {
        print("[LocalModelRunner] CRITICAL Memory Pressure! Halting engine to protect from Jetsam OOM.")
        await cancelGeneration()
        await unloadModel()
        self.lifecycleState = .failed(error: "Model evicted to protect iOS stability under critical memory pressure.")
    }

    private func handleThermalStateChange(_ state: ProcessInfo.ThermalState) async {
        if state == .critical {
            print("[LocalModelRunner] CRITICAL Thermal State! Pausing inference.")
            await cancelGeneration()
        }
    }
}
