//
//  ModelManifest.swift
//  IRIS-I
//
//  Defines model configuration manifests and hardware profiles.
//

import Foundation

public enum ProfileTier: String, Codable, Sendable {
    case baseline     // 3B Q4_K_M: Fully supported default for iPhone 17 (A19, 8GB)
    case experimental // 7B: Strictly experimental, requires explicit user confirmation
}

public enum ParameterScale: String, Codable, Sendable {
    case threeB = "3B"
    case sevenB = "7B"
}

public struct ModelManifest: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let displayName: String
    public let parameterScale: ParameterScale
    public let quantization: String
    public let profileTier: ProfileTier
    public let filename: String
    public let estimatedSizeBytes: Int64
    public let defaultContextSize: Int
    public let maxContextSize: Int
    public let expectedSHA256: String?
    public let verifiedDownloadURL: URL?
    public let summary: String

    public var isExperimental: Bool {
        profileTier == .experimental
    }

    public init(
        id: String,
        displayName: String,
        parameterScale: ParameterScale,
        quantization: String = "Q4_K_M",
        profileTier: ProfileTier,
        filename: String,
        estimatedSizeBytes: Int64,
        defaultContextSize: Int = 2048,
        maxContextSize: Int = 4096,
        expectedSHA256: String? = nil,
        verifiedDownloadURL: URL? = nil,
        summary: String
    ) {
        self.id = id
        self.displayName = displayName
        self.parameterScale = parameterScale
        self.quantization = quantization
        self.profileTier = profileTier
        self.filename = filename
        self.estimatedSizeBytes = estimatedSizeBytes
        self.defaultContextSize = defaultContextSize
        self.maxContextSize = maxContextSize
        self.expectedSHA256 = expectedSHA256
        self.verifiedDownloadURL = verifiedDownloadURL
        self.summary = summary
    }
}
