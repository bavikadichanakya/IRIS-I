//
//  ToolCallParser.swift
//  IRIS-I
//
//  Resilient parser for local model outputs.
//  Normalizes doubled braces, strips code fences, handles unescaped quotes,
//  and extracts structured tool calls even from noisy output streams.
//

import Foundation

public struct ParsedToolCall: Sendable, Equatable {
    public let toolName: String
    public let arguments: [String: Any]
    public let rawPayload: String

    public init(toolName: String, arguments: [String: Any], rawPayload: String) {
        self.toolName = toolName
        self.arguments = arguments
        self.rawPayload = rawPayload
    }

    public static func == (lhs: ParsedToolCall, rhs: ParsedToolCall) -> Bool {
        lhs.toolName == rhs.toolName && lhs.rawPayload == rhs.rawPayload
    }
}

public struct ToolCallParser {

    /// Parses assistant text for structured tool calls. Returns nil if purely conversational.
    public static func parse(content: String) -> ParsedToolCall? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        var buffer = trimmed

        // 1. Strip markdown code fences (```json ... ``` or ``` ... ```)
        if buffer.contains("```json") {
            if let start = buffer.range(of: "```json")?.upperBound {
                let afterStart = String(buffer[start...])
                if let end = afterStart.range(of: "```")?.lowerBound {
                    buffer = String(afterStart[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    buffer = afterStart.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } else if buffer.contains("```") {
            if let start = buffer.range(of: "```")?.upperBound {
                let afterStart = String(buffer[start...])
                if let end = afterStart.range(of: "```")?.lowerBound {
                    buffer = String(afterStart[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // 2. Unescape escaped double quotes and trim outer quotes if string-wrapped
        if (buffer.hasPrefix("\"") && buffer.hasSuffix("\"")) || (buffer.hasPrefix("'") && buffer.hasSuffix("'")) {
            buffer = String(buffer.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        buffer = buffer.replacingOccurrences(of: "\\\"", with: "\"")

        // 3. Try direct JSON parsing on cleaned buffer before any aggressive mutations
        if let call = parseJsonBuffer(buffer) {
            return call
        }

        // 4. Try regex extraction for embedded JSON block before alterations
        let jsonPattern = #"\{[\s\S]*\}"#
        if let regex = try? NSRegularExpression(pattern: jsonPattern, options: []),
           let match = regex.firstMatch(in: buffer, options: [], range: NSRange(location: 0, length: buffer.utf16.count)) {
            if let range = Range(match.range, in: buffer) {
                let candidate = String(buffer[range])
                if let call = parseJsonBuffer(candidate) {
                    return call
                }
            }
        }

        // 5. Model quirk remediation: Normalize doubled braces without corrupting valid nested JSON
        var alteredBuffer = buffer
        if alteredBuffer.contains("{{") {
            alteredBuffer = alteredBuffer.replacingOccurrences(of: "{{", with: "{")
        }
        // Only strip duplicate closing braces if closing braces exceed opening braces
        var openCount = alteredBuffer.filter { $0 == "{" }.count
        var closeCount = alteredBuffer.filter { $0 == "}" }.count
        while closeCount > openCount && alteredBuffer.contains("}}") {
            if let range = alteredBuffer.range(of: "}}") {
                alteredBuffer.replaceSubrange(range, with: "}")
                closeCount -= 1
            } else {
                break
            }
        }

        if let call = parseJsonBuffer(alteredBuffer) {
            return call
        }

        if let regex = try? NSRegularExpression(pattern: jsonPattern, options: []),
           let match = regex.firstMatch(in: alteredBuffer, options: [], range: NSRange(location: 0, length: alteredBuffer.utf16.count)) {
            if let range = Range(match.range, in: alteredBuffer) {
                let candidate = String(alteredBuffer[range])
                if let call = parseJsonBuffer(candidate) {
                    return call
                }
            }
        }

        // 6. Regex fallback for function syntax: ToolName(key="value", ...) or ToolName({...})
        let fnPattern = #"(\w*(?:Tool|Action|Skill|Opener|Reader|Manager))\s*\(([\s\S]*?)\)"#
        if let regex = try? NSRegularExpression(pattern: fnPattern, options: []),
           let match = regex.firstMatch(in: buffer, options: [], range: NSRange(location: 0, length: buffer.utf16.count)) {
            if let nameRange = Range(match.range(at: 1), in: buffer),
               let argsRange = Range(match.range(at: 2), in: buffer) {
                let toolName = String(buffer[nameRange])
                let rawArgs = String(buffer[argsRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                var parsedArgs: [String: Any] = [:]
                if rawArgs.hasPrefix("{") && rawArgs.hasSuffix("}"),
                   let data = rawArgs.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    parsedArgs = dict
                } else if !rawArgs.isEmpty {
                    parsedArgs["query"] = rawArgs
                }

                return ParsedToolCall(toolName: toolName, arguments: parsedArgs, rawPayload: buffer)
            }
        }

        return nil
    }

    private static func parseJsonBuffer(_ jsonString: String) -> ParsedToolCall? {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Check for nested action structure: {"thought": "...", "action": {"tool": "...", "parameters": {...}}}
        if let actionObj = dict["action"] as? [String: Any] {
            let toolName = (actionObj["tool"] ?? actionObj["name"] ?? actionObj["tool_name"]) as? String
            if let toolName = toolName {
                let args = (actionObj["parameters"] ?? actionObj["arguments"] ?? actionObj["args"]) as? [String: Any] ?? [:]
                return ParsedToolCall(toolName: toolName, arguments: args, rawPayload: jsonString)
            }
        }

        // Standard tool call format: {"name": "...", "arguments": {...}} or {"tool": "...", "parameters": {...}}
        let nameCandidate = dict["name"] ?? dict["tool"] ?? dict["tool_name"] ?? dict["function"]
        var toolName: String? = nil

        if let str = nameCandidate as? String {
            toolName = str
        } else if let fnDict = nameCandidate as? [String: Any], let str = fnDict["name"] as? String {
            toolName = str
        }

        guard let validName = toolName, !validName.isEmpty else {
            return nil
        }

        var arguments: [String: Any] = [:]
        if let argsObj = dict["arguments"] as? [String: Any] {
            arguments = argsObj
        } else if let argsObj = dict["parameters"] as? [String: Any] {
            arguments = argsObj
        } else if let argsObj = dict["args"] as? [String: Any] {
            arguments = argsObj
        } else if let argsStr = dict["arguments"] as? String,
                  let argData = argsStr.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: argData) as? [String: Any] {
            arguments = parsed
        }

        return ParsedToolCall(toolName: validName, arguments: arguments, rawPayload: jsonString)
    }
}
