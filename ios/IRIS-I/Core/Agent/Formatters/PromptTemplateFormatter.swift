//
//  PromptTemplateFormatter.swift
//  IRIS-I
//
//  Model-agnostic prompt formatter protocol.
//  Decouples chat templating and tool definitions from the core orchestrator.
//

import Foundation

public struct ChatMessage: Sendable {
    public let role: String // "system", "user", "assistant", "tool"
    public let content: String
    public let toolName: String?

    public init(role: String, content: String, toolName: String? = nil) {
        self.role = role
        self.content = content
        self.toolName = toolName
    }
}

public protocol PromptTemplateFormatter: Sendable {
    func formatChat(messages: [ChatMessage], availableTools: [ToolDefinition]) -> String
    func formatToolFeedback(toolName: String, resultJson: String) -> ChatMessage
}

public struct PromptTemplateFormatterFactory {
    public static func formatter(for manifest: ModelManifest) -> any PromptTemplateFormatter {
        switch manifest.chatTemplate {
        case .chatML:
            return ChatMLPromptFormatter()
        case .llama3:
            return Llama3PromptFormatter()
        case .raw:
            return ChatMLPromptFormatter()
        }
    }
}

