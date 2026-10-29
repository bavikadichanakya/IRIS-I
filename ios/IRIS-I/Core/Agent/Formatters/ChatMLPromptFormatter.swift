//
//  ChatMLPromptFormatter.swift
//  IRIS-I
//
//  ChatML template formatter for Qwen 2.5 and SmolLM3 models.
//

import Foundation

public struct ChatMLPromptFormatter: PromptTemplateFormatter {

    public init() {}

    public func formatChat(messages: [ChatMessage], availableTools: [ToolDefinition]) -> String {
        var formatted = ""

        // Build system prompt with tool definitions if tools exist
        var systemContent = "You are IRIS, an intelligent on-device AI assistant operating 100% locally on iPhone."

        if !availableTools.isEmpty {
            systemContent += "\n\nYou have access to the following on-device tools:\n"
            for tool in availableTools {
                let schemaJson: String
                if let data = try? JSONEncoder().encode(tool.parameters),
                   let str = String(data: data, encoding: .utf8) {
                    schemaJson = str
                } else {
                    schemaJson = "{}"
                }
                systemContent += "\n- Tool: \(tool.name)\n  Description: \(tool.description)\n  Parameters: \(schemaJson)\n"
            }

            systemContent += """

To execute a tool, respond with a valid JSON block on a single line:
```json
{"name": "ToolName", "arguments": {"param1": "value1"}}
```
Do not use doubled curly braces.
If no tool is required, answer the user directly and conversationally in 1-2 sentences.
"""
        }

        // Add system message first if not already present in messages
        var hasSystem = false
        for msg in messages {
            if msg.role == "system" {
                hasSystem = true
                formatted += "<|im_start|>system\n\(msg.content)\n<|im_end|>\n"
            }
        }

        if !hasSystem {
            formatted += "<|im_start|>system\n\(systemContent)\n<|im_end|>\n"
        }

        // Add user, assistant, and tool turns
        for msg in messages {
            if msg.role == "system" { continue }

            if msg.role == "tool" {
                formatted += "<|im_start|>tool\n\(msg.content)\n<|im_end|>\n"
            } else {
                formatted += "<|im_start|>\(msg.role)\n\(msg.content)\n<|im_end|>\n"
            }
        }

        // Prime the assistant turn
        formatted += "<|im_start|>assistant\n"
        return formatted
    }

    public func formatToolFeedback(toolName: String, resultJson: String) -> ChatMessage {
        ChatMessage(
            role: "tool",
            content: "{\"tool\": \"\(toolName)\", \"result\": \(resultJson)}",
            toolName: toolName
        )
    }
}

