//
//  ModelEngineProtocol.swift
//  IRIS-I
//
//  Defines the contract for in-process LLM inference backends.
//

import Foundation

public enum EngineError: LocalizedError, Sendable {
    case uninitialized
    case alreadyLoaded(String)
    case failedToLoadModel(String)
    case failedToCreateContext(Int)
    case contextWindowExceeded(current: Int, max: Int)
    case generationCancelled
    case memoryPressureTermination
    case tokenizationFailed

    public var errorDescription: String? {
        switch self {
        case .uninitialized:
            return "Inference engine is not initialized or model is unloaded."
        case .alreadyLoaded(let name):
            return "Model '\(name)' is already loaded. Unload it before loading another."
        case .failedToLoadModel(let path):
            return "Failed to load model file from: \(path)."
        case .failedToCreateContext(let ctx):
            return "Could not allocate Metal context for window size \(ctx)."
        case .contextWindowExceeded(let cur, let max):
            return "Prompt length (\(cur) tokens) exceeds context limit of \(max)."
        case .generationCancelled:
            return "Generation was cancelled by the user."
        case .memoryPressureTermination:
            return "Inference halted due to critical OS memory pressure (Jetsam protection)."
        case .tokenizationFailed:
            return "Failed to tokenize input prompt."
        }
    }
}

public protocol ModelEngineProtocol: AnyObject, Sendable {
    var isLoaded: Bool { get async }
    var isMockEngine: Bool { get }
    var loadedManifest: ModelManifest? { get async }
    var activeContextSize: Int { get async }

    func load(
        manifest: ModelManifest,
        fileURL: URL,
        contextSize: Int,
        progress: (@Sendable (Double) -> Void)?
    ) async throws

    func unload() async

    func generateStream(
        prompt: String,
        maxTokens: Int,
        temperature: Float
    ) async -> AsyncThrowingStream<String, Error>

    func cancel() async
    func latestTelemetry() async -> InferenceTelemetry
}
