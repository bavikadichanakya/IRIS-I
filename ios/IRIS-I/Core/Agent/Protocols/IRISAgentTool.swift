//
//  IRISAgentTool.swift
//  IRIS-I
//
//  Defines the core protocol, schema, and execution outcome lifecycle for on-device tools.
//

import Foundation

/// Defines the outcome state of a tool execution.
public enum ToolExecutionOutcome: String, Codable, Sendable {
    /// Action has been validated against schema and accepted for processing.
    case accepted
    /// Action is currently executing.
    case inProgress
    /// Completed and outcome verified (e.g., event ID returned from EventKit, system clock queried).
    case completedVerified
    /// Handoff to external OS/app succeeded, but internal target-app state is unverifiable (e.g. URL scheme launch).
    case completedUnverified
    /// Action is sensitive and requires explicit user confirmation.
    case confirmationRequired
    /// Action denied by security policy, missing permission, or unsupported OS boundary.
    case deniedPolicy
    /// Action was cancelled by the user or task supervisor.
    case cancelled
    /// Execution exceeded its deadline.
    case timedOut
    /// Execution encountered an explicit failure.
    case failed
}

/// Action-specific operation classifications separating read, draft, send, destructive, and remote commands.
public enum ActionOperationType: String, Codable, Sendable {
    case read
    case draft
    case send
    case destructive
    case remoteCommand
}

/// Structured parameter schema definition compatible with standard JSON Schema.
public struct ToolParameterSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: ToolPropertySchema]
    public let required: [String]

    public init(
        type: String = "object",
        properties: [String: ToolPropertySchema] = [:],
        required: [String] = []
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

public struct ToolPropertySchema: Codable, Sendable {
    public let type: String
    public let description: String
    public let enumValues: [String]?

    public init(
        type: String,
        description: String,
        enumValues: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
    }
}

/// Definition of an agent tool for schema publishing to the model.
public struct ToolDefinition: Codable, Sendable {
    public let name: String
    public let description: String
    public let parameters: ToolParameterSchema
    public let category: String

    public init(
        name: String,
        description: String,
        parameters: ToolParameterSchema,
        category: String = "general"
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.category = category
    }
}

/// Rich execution result returned by all tools.
public struct AgentExecutionResult: Sendable {
    public let success: Bool
    public let toolName: String
    public let outcome: ToolExecutionOutcome
    public let outputPayload: [String: Sendable]
    public let error: String?
    public let confirmationToken: String?
    public let executionDurationMs: Double

    public init(
        success: Bool,
        toolName: String,
        outcome: ToolExecutionOutcome,
        outputPayload: [String: Sendable] = [:],
        error: String? = nil,
        confirmationToken: String? = nil,
        executionDurationMs: Double = 0.0
    ) {
        self.success = success
        self.toolName = toolName
        self.outcome = outcome
        self.outputPayload = outputPayload
        self.error = error
        self.confirmationToken = confirmationToken
        self.executionDurationMs = executionDurationMs
    }

    /// Convenience initializer supporting flexible parameter naming
    public init(
        success: Bool? = nil,
        tool: String,
        outcome: ToolExecutionOutcome,
        outputPayload: [String: Sendable] = [:],
        error: String? = nil,
        confirmationToken: String? = nil,
        durationMs: Double = 0.0
    ) {
        let isSuccess = success ?? (outcome == .completedVerified || outcome == .completedUnverified || outcome == .accepted)
        self.init(
            success: isSuccess,
            toolName: tool,
            outcome: outcome,
            outputPayload: outputPayload,
            error: error,
            confirmationToken: confirmationToken,
            executionDurationMs: durationMs
        )
    }

    public static func success(
        tool: String,
        verified: Bool = true,
        payload: [String: Sendable] = [:],
        durationMs: Double = 0.0
    ) -> AgentExecutionResult {
        AgentExecutionResult(
            success: true,
            toolName: tool,
            outcome: verified ? .completedVerified : .completedUnverified,
            outputPayload: payload,
            executionDurationMs: durationMs
        )
    }

    public static func failure(
        tool: String,
        error: String,
        outcome: ToolExecutionOutcome = .failed,
        durationMs: Double = 0.0
    ) -> AgentExecutionResult {
        AgentExecutionResult(
            success: false,
            toolName: tool,
            outcome: outcome,
            error: error,
            executionDurationMs: durationMs
        )
    }
}

/// The contract that all on-device tools must implement.
public protocol IRISAgentTool: Sendable {
    var name: String { get }
    var description: String { get }
    var parametersSchema: ToolParameterSchema { get }
    var permissionLevel: PermissionLevel { get }
    var category: String { get }

    /// Returns the exact operation type for a given argument set.
    func operationType(for arguments: [String: Any]) -> ActionOperationType

    /// Executes the tool action with parsed argument dictionary.
    func execute(arguments: [String: Any]) async -> AgentExecutionResult
}

extension IRISAgentTool {
    public var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: description,
            parameters: parametersSchema,
            category: category
        )
    }

    public func operationType(for arguments: [String: Any]) -> ActionOperationType {
        switch permissionLevel {
        case .publicLevel:
            return .read
        case .protectedLevel:
            return .draft
        case .sensitiveLevel:
            return .destructive
        }
    }
}
