//
//  ToolRegistry.swift
//  IRIS-I
//
//  Actor managing registered allowlisted tools and generating tool schemas.
//

import Foundation

public actor ToolRegistry {
    public static let shared = ToolRegistry()

    private var registeredTools: [String: any IRISAgentTool] = [:]

    public init() {}

    public func register(tool: any IRISAgentTool) {
        registeredTools[tool.name] = tool
    }

    public func getTool(named name: String) -> (any IRISAgentTool)? {
        registeredTools[name]
    }

    public func allTools() -> [any IRISAgentTool] {
        Array(registeredTools.values)
    }

    public func toolDefinitions() -> [ToolDefinition] {
        registeredTools.values.map { $0.definition }
    }
}

