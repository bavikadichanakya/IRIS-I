//
//  ToolSchemaValidator.swift
//  IRIS-I
//
//  Runtime validation layer for agent tool execution.
//  Enforces JSON schema conformance, required parameter presence, type safety,
//  enum constraints, unexpected property detection, and communication recipient checks.
//

import Foundation

public enum ToolValidationError: Error, CustomStringConvertible, Sendable, Equatable {
    case toolNotFound(toolName: String)
    case missingRequired(field: String, tool: String)
    case typeMismatch(field: String, expectedType: String, actualType: String, tool: String)
    case invalidEnumValue(field: String, value: String, allowed: [String], tool: String)
    case unexpectedProperty(field: String, tool: String)
    case emptyValue(field: String, tool: String)
    case malformedArguments(reason: String)

    public var description: String {
        switch self {
        case .toolNotFound(let name):
            return "Tool '\(name)' is not registered or unavailable."
        case .missingRequired(let field, let tool):
            return "Missing required parameter '\(field)' for tool '\(tool)'."
        case .typeMismatch(let field, let expected, let actual, let tool):
            return "Parameter '\(field)' in '\(tool)' expected type '\(expected)' but received '\(actual)'."
        case .invalidEnumValue(let field, let value, let allowed, let tool):
            return "Invalid value '\(value)' for parameter '\(field)' in '\(tool)'. Allowed values: [\(allowed.joined(separator: ", "))]."
        case .unexpectedProperty(let field, let tool):
            return "Unexpected parameter '\(field)' is not supported by tool '\(tool)'."
        case .emptyValue(let field, let tool):
            return "Parameter '\(field)' in tool '\(tool)' cannot be empty."
        case .malformedArguments(let reason):
            return "Malformed tool arguments: \(reason)"
        }
    }
}

public enum ToolValidationResult: Sendable {
    case valid(sanitizedArguments: [String: Any])
    case invalid(errors: [ToolValidationError])

    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    public var errors: [ToolValidationError] {
        if case .invalid(let errs) = self { return errs }
        return []
    }

    public var missingRequired: [String] {
        errors.compactMap {
            if case .missingRequired(let field, _) = $0 { return field }
            return nil
        }
    }

    public var invalidTypes: [String] {
        errors.compactMap {
            if case .typeMismatch(let field, _, _, _) = $0 { return field }
            return nil
        }
    }

    public var enumViolations: [String] {
        errors.compactMap {
            if case .invalidEnumValue(let field, _, _, _) = $0 { return field }
            return nil
        }
    }

    public var unexpectedProperties: [String] {
        errors.compactMap {
            if case .unexpectedProperty(let field, _) = $0 { return field }
            return nil
        }
    }

    public var feedbackJsonString: String {
        switch self {
        case .valid:
            return "{\"status\": \"valid\"}"
        case .invalid(let errors):
            let errorMessages = errors.map { $0.description }
            let payload: [String: Any] = [
                "error": "Tool call schema validation failed",
                "details": errorMessages
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return "{\"error\": \"Schema validation failed: \(errorMessages.joined(separator: "; "))\"}"
        }
    }
}

public struct ToolSchemaValidator: Sendable {

    /// Validates raw arguments against the tool's published parameters schema.
    public static func validate(
        tool: any IRISAgentTool,
        arguments: [String: Any],
        allowUnexpectedProperties: Bool = false
    ) -> ToolValidationResult {
        var errors: [ToolValidationError] = []
        var sanitized: [String: Any] = [:]

        let schema = tool.parametersSchema
        let properties = schema.properties

        // 1. Check all required parameters exist and are not empty
        for reqKey in schema.required {
            guard let val = arguments[reqKey] else {
                errors.append(.missingRequired(field: reqKey, tool: tool.name))
                continue
            }

            if let strVal = val as? String, strVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyValue(field: reqKey, tool: tool.name))
                continue
            }
        }

        // 2. Validate supplied properties against property schemas
        for (key, value) in arguments {
            guard let propSchema = properties[key] else {
                if !allowUnexpectedProperties {
                    errors.append(.unexpectedProperty(field: key, tool: tool.name))
                } else {
                    sanitized[key] = value
                }
                continue
            }

            // Type verification
            let expectedType = propSchema.type.lowercased()
            switch expectedType {
            case "string":
                if let str = value as? String {
                    sanitized[key] = str
                } else if let num = value as? NSNumber {
                    // Normalize numbers sent as strings
                    sanitized[key] = num.stringValue
                } else {
                    errors.append(.typeMismatch(field: key, expectedType: "string", actualType: "\(type(of: value))", tool: tool.name))
                    continue
                }

            case "integer", "int":
                if let intVal = value as? Int {
                    sanitized[key] = intVal
                } else if let num = value as? NSNumber {
                    sanitized[key] = num.intValue
                } else if let str = value as? String, let intParsed = Int(str.trimmingCharacters(in: .whitespaces)) {
                    sanitized[key] = intParsed
                } else {
                    errors.append(.typeMismatch(field: key, expectedType: "integer", actualType: "\(type(of: value))", tool: tool.name))
                    continue
                }

            case "number", "float", "double":
                if let dblVal = value as? Double {
                    sanitized[key] = dblVal
                } else if let num = value as? NSNumber {
                    sanitized[key] = num.doubleValue
                } else if let str = value as? String, let dblParsed = Double(str.trimmingCharacters(in: .whitespaces)) {
                    sanitized[key] = dblParsed
                } else {
                    errors.append(.typeMismatch(field: key, expectedType: "number", actualType: "\(type(of: value))", tool: tool.name))
                    continue
                }

            case "boolean", "bool":
                if let boolVal = value as? Bool {
                    sanitized[key] = boolVal
                } else if let str = value as? String {
                    let lower = str.lowercased().trimmingCharacters(in: .whitespaces)
                    if lower == "true" || lower == "1" || lower == "yes" {
                        sanitized[key] = true
                    } else if lower == "false" || lower == "0" || lower == "no" {
                        sanitized[key] = false
                    } else {
                        errors.append(.typeMismatch(field: key, expectedType: "boolean", actualType: "string(\(str))", tool: tool.name))
                        continue
                    }
                } else {
                    errors.append(.typeMismatch(field: key, expectedType: "boolean", actualType: "\(type(of: value))", tool: tool.name))
                    continue
                }

            case "array":
                if let arr = value as? [Any] {
                    sanitized[key] = arr
                } else {
                    errors.append(.typeMismatch(field: key, expectedType: "array", actualType: "\(type(of: value))", tool: tool.name))
                    continue
                }

            case "object":
                if let obj = value as? [String: Any] {
                    sanitized[key] = obj
                } else {
                    errors.append(.typeMismatch(field: key, expectedType: "object", actualType: "\(type(of: value))", tool: tool.name))
                    continue
                }

            default:
                sanitized[key] = value
            }

            // Enum constraint check
            if let enumValues = propSchema.enumValues, !enumValues.isEmpty {
                let stringVal = "\(sanitized[key] ?? value)".trimmingCharacters(in: .whitespaces)
                let matches = enumValues.contains { $0.caseInsensitiveCompare(stringVal) == .orderedSame }
                if !matches {
                    errors.append(.invalidEnumValue(
                        field: key,
                        value: stringVal,
                        allowed: enumValues,
                        tool: tool.name
                    ))
                }
            }
        }

        // 3. Domain-specific communication tool validation
        if tool.name == "MessagingTool" {
            if let action = arguments["action"] as? String, action == "send" || action == "draft" {
                if let recipient = arguments["recipient"] as? String, recipient.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append(.emptyValue(field: "recipient", tool: tool.name))
                }
            }
        } else if tool.name == "MailTool" {
            let action = (arguments["action"] as? String)?.lowercased() ?? ""
            if action == "compose_mail" || action == "create_draft" || action == "send_email" {
                if let recipient = arguments["recipient"] as? String {
                    if recipient.trimmingCharacters(in: .whitespaces).isEmpty {
                        errors.append(.emptyValue(field: "recipient", tool: tool.name))
                    }
                } else if schema.required.contains("recipient") {
                    errors.append(.missingRequired(field: "recipient", tool: tool.name))
                }
            }
        }

        if errors.isEmpty {
            return .valid(sanitizedArguments: sanitized)
        } else {
            return .invalid(errors: errors)
        }
    }
}

