//
//  ModelCatalog.swift
//  IRIS-I
//
//  Registry of officially supported model profiles for iPhone 17.
//

import Foundation

public final class ModelCatalog: Sendable {
    public static let shared = ModelCatalog()

    // 1. PRIMARY BASELINE: Qwen 2.5 3B Instruct (Supported on iPhone 17 Base, A19, 8GB)
    public let baseline3B = ModelManifest(
        id: "iris-baseline-qwen-3b",
        displayName: "IRIS-3B (Qwen 2.5 Instruct / Abliterated)",
        modelFamily: .qwen2_5,
        chatTemplate: .chatML,
        parameterScale: .threeB,
        quantization: "Q4_K_M",
        profileTier: .baseline,
        filename: "qwen2.5-3b-instruct-q4_k_m.gguf",
        estimatedSizeBytes: 1_997_879_712, // ~1.99 GB
        defaultContextSize: 2048,
        maxContextSize: 4096,
        expectedSHA256: "670d82d0fbee6289b661eb323612c65bd2e97ec8c65cdbd9131aa44d30e9816a", // Official HuggingFace Qwen LFS SHA-256
        verifiedDownloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"),
        summary: "Primary supported local model for iPhone 17 (A19). Qwen 2.5 architecture, ChatML template, fast reasoning, low memory pressure, reliable structured tool calling."
    )

    // 2. GENERIC ENGINE SMOKE TEST: Llama 3.2 3B Instruct (Engine smoke test only)
    public let smokeTestLlama3B = ModelManifest(
        id: "iris-smoketest-llama-3b",
        displayName: "Llama 3.2 3B Instruct (Engine Smoke Test Only)",
        modelFamily: .llama3,
        chatTemplate: .llama3,
        parameterScale: .threeB,
        quantization: "Q4_K_M",
        profileTier: .baseline,
        filename: "llama-3.2-3b-instruct-q4_k_m.gguf",
        estimatedSizeBytes: 2_020_000_000, // ~2.02 GB
        defaultContextSize: 2048,
        maxContextSize: 4096,
        expectedSHA256: nil,
        verifiedDownloadURL: nil,
        summary: "Generic engine smoke test profile. Used to verify engine compatibility against standard Meta Llama 3.2 GGUF artifacts."
    )

    // 3. EXPERIMENTAL: Qwen 2.5 7B Instruct (Experimental evaluation only)
    public let experimental7B = ModelManifest(
        id: "iris-experimental-qwen-7b",
        displayName: "IRIS-7B (Qwen 2.5 Instruct / Abliterated)",
        modelFamily: .qwen2_5,
        chatTemplate: .chatML,
        parameterScale: .sevenB,
        quantization: "Q4_K_M",
        profileTier: .experimental,
        filename: "qwen2.5-7b-instruct-q4_k_m.gguf",
        estimatedSizeBytes: 4_350_000_000, // ~4.35 GB
        defaultContextSize: 2048,
        maxContextSize: 3072,
        expectedSHA256: nil,
        verifiedDownloadURL: nil,
        summary: "High-capacity experimental model. Requires ~4.5 GB RAM. May trigger iOS memory warnings on base models."
    )

    public var allProfiles: [ModelManifest] {
        [baseline3B]
    }

    public func profile(for id: String) -> ModelManifest? {
        allProfiles.first { $0.id == id }
    }
}
