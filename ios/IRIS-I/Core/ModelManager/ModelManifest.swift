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

public enum ModelFamily: String, Codable, Sendable {
    case qwen2_5 = "qwen2.5"     // Primary intended target for IRIS-I (ChatML template)
    case llama3  = "llama3"      // Engine verification & generic smoke test only
    case generic = "generic"
}

public enum ChatTemplateType: String, Codable, Sendable {
    case chatML  // <|im_start|>system\n{system}<|im_end|>\n<|im_start|>user\n{prompt}<|im_end|>\n<|im_start|>assistant\n
    case llama3  // <|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n{system}<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n{prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n
    case raw     // Pass-through without wrapping
}

public struct ModelManifest: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let displayName: String
    public let modelFamily: ModelFamily
    public let chatTemplate: ChatTemplateType
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

    public var requiredDiskBytes: Int64 {
        estimatedSizeBytes
    }

    public init(
        id: String,
        displayName: String,
        modelFamily: ModelFamily = .qwen2_5,
        chatTemplate: ChatTemplateType = .chatML,
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
        self.modelFamily = modelFamily
        self.chatTemplate = chatTemplate
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

    /// Formats a user message and optional system prompt according to the manifest's chat template
    public func formatPrompt(systemPrompt: String? = nil, userMessage: String) -> String {
        switch chatTemplate {
        case .chatML:
            var prompt = ""
            if let sys = systemPrompt, !sys.isEmpty {
                prompt += "<|im_start|>system\n\(sys)<|im_end|>\n"
            }
            prompt += "<|im_start|>user\n\(userMessage)<|im_end|>\n<|im_start|>assistant\n"
            return prompt

        case .llama3:
            var prompt = "<|begin_of_text|>"
            if let sys = systemPrompt, !sys.isEmpty {
                prompt += "<|start_header_id|>system<|end_header_id|>\n\n\(sys)<|eot_id|>"
            }
            prompt += "<|start_header_id|>user<|end_header_id|>\n\n\(userMessage)<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n"
            return prompt

        case .raw:
            if let sys = systemPrompt, !sys.isEmpty {
                return "\(sys)\n\n\(userMessage)"
            }
            return userMessage
        }
    }
}
