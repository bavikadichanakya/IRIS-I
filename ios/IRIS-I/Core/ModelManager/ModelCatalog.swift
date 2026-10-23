//
//  ModelCatalog.swift
//  IRIS-I
//
//  Registry of officially supported model profiles for iPhone 17.
//

import Foundation

public final class ModelCatalog: Sendable {
    public static let shared = ModelCatalog()

    // 1. BASELINE: 3B Q4_K_M profile (Supported on iPhone 17 Base, A19, 8GB)
    public let baseline3B = ModelManifest(
        id: "iris-baseline-3b",
        displayName: "IRIS-3B Baseline (Abliterated)",
        parameterScale: .threeB,
        quantization: "Q4_K_M",
        profileTier: .baseline,
        filename: "iris-3b-q4km.gguf",
        estimatedSizeBytes: 1_950_000_000, // ~1.95 GB
        defaultContextSize: 2048,
        maxContextSize: 4096,
        expectedSHA256: nil, // Must be supplied by verified artifact manifest or import
        verifiedDownloadURL: nil, // Kept nil until independently verified against trusted release
        summary: "Primary supported local model for iPhone 17 (A19). Fast reasoning, low memory pressure, reliable structured tool calling."
    )

    // 2. EXPERIMENTAL: 7B Q4_K_M profile (Experimental evaluation only)
    public let experimental7B = ModelManifest(
        id: "iris-experimental-7b",
        displayName: "IRIS-7B Experimental (Abliterated)",
        parameterScale: .sevenB,
        quantization: "Q4_K_M",
        profileTier: .experimental,
        filename: "iris-7b-q4km.gguf",
        estimatedSizeBytes: 4_350_000_000, // ~4.35 GB
        defaultContextSize: 2048,
        maxContextSize: 3072,
        expectedSHA256: nil,
        verifiedDownloadURL: nil,
        summary: "High-capacity experimental model. Requires ~4.5 GB RAM. May trigger iOS memory warnings on base models."
    )

    public var allProfiles: [ModelManifest] {
        [baseline3B, experimental7B]
    }

    public func profile(for id: String) -> ModelManifest? {
        allProfiles.first { $0.id == id }
    }
}
