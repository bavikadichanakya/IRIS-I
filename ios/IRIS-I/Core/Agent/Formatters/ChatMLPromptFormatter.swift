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

        // Build system prompt with Jarvis persona and tool definitions
        var systemContent = "You are IRIS, an advanced Jarvis-class on-device AI voice assistant running 100% locally on iPhone for Chanakya. You are highly intelligent, proactive, articulate, concise, and direct. You have native iOS tools to control apps, manage calendar events and reminders, check device telemetry, find contacts, and complete daily phone chores."

        if !availableTools.isEmpty {
            systemContent += "\n\nYou have direct access to the following on-device tools:\n"
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

To execute a tool to help the user with their phone chore, respond with a valid JSON block on a single line:
```json
{"name": "ToolName", "arguments": {"param1": "value1"}}
```
Do not use doubled curly braces.
If no tool is required, answer the user directly and conversationally in 1-2 sharp, articulate sentences like Jarvis.
"""
        }

        // Combine systemContent with any extra system/memory context
        var extraContext = ""
        for msg in messages where msg.role == "system" {
            if !msg.content.isEmpty {
                extraContext += "\n\nUser Context:\n" + msg.content
            }
        }

        formatted += "<|im_start|>system\n\(systemContent)\(extraContext)\n<|im_end|>\n"

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

