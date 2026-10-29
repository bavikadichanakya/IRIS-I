//
//  Llama3PromptFormatter.swift
//  IRIS-I
//
//  Llama 3 template formatter.
//

import Foundation

public struct Llama3PromptFormatter: PromptTemplateFormatter {

    public init() {}

    public func formatChat(messages: [ChatMessage], availableTools: [ToolDefinition]) -> String {
        var formatted = "<|begin_of_text|>"

        var systemContent = "You are IRIS, an intelligent on-device AI assistant operating 100% locally on iPhone."

        if !availableTools.isEmpty {
            systemContent += "\n\nAvailable tools:\n"
            for tool in availableTools {
                let schemaJson: String
                if let data = try? JSONEncoder().encode(tool.parameters),
                   let str = String(data: data, encoding: .utf8) {
                    schemaJson = str
                } else {
                    schemaJson = "{}"
                }
                systemContent += "\n- \(tool.name): \(tool.description) Parameters: \(schemaJson)"
            }
            systemContent += "\n\nTo use a tool, respond with: {\"name\": \"ToolName\", \"arguments\": {...}}\n"
        }

        var hasSystem = false
        for msg in messages {
            if msg.role == "system" {
                hasSystem = true
                formatted += "<|start_header_id|>system<|end_header_id|>\n\n\(msg.content)<|eot_id|>"
            }
        }

        if !hasSystem {
            formatted += "<|start_header_id|>system<|end_header_id|>\n\n\(systemContent)<|eot_id|>"
        }

        for msg in messages {
            if msg.role == "system" { continue }
            formatted += "<|start_header_id|>\(msg.role)<|end_header_id|>\n\n\(msg.content)<|eot_id|>"
        }

        formatted += "<|start_header_id|>assistant<|end_header_id|>\n\n"
        return formatted
    }

    public func formatToolFeedback(toolName: String, resultJson: String) -> ChatMessage {
        ChatMessage(
            role: "user",
            content: "Tool output for \(toolName): \(resultJson)",
            toolName: toolName
        )
    }
}

