//
//  ReActOrchestrator.swift
//  IRIS-I
//
//  Multi-step ReAct (Reason + Act) execution orchestrator running on iOS.
//  Coordinates FastIntentRouter (<10ms), LocalModelRunner streaming inference,
//  ToolRegistry dispatch, PermissionManager security gates, and tool feedback loops.
//

import Foundation

public struct OrchestratorResponse: Sendable {
    public let textResponse: String
    public let executedTools: [String]
    public let requiresConfirmation: Bool
    public let pendingConfirmationTicket: ConfirmationTicket?
    public let routingDurationMs: Double
    public let totalDurationMs: Double
    public let stepCount: Int
}

public actor ReActOrchestrator {
    public static let shared = ReActOrchestrator()

    private let runner = LocalModelRunner.shared
    private let toolRegistry = ToolRegistry.shared
    private let permissionManager = PermissionManager.shared
    private let fastRouter = FastIntentRouter()

    private var maxIterations: Int = 5
    private var isCancelled: Bool = false

    public init() {
        registerBuiltInTools()
    }

    private func registerBuiltInTools() {
        Task {
            await toolRegistry.register(tool: SystemInfoTool())
            await toolRegistry.register(tool: WebSearchTool())
            await toolRegistry.register(tool: MailTool())
            await toolRegistry.register(tool: MessagingTool())
            await toolRegistry.register(tool: EventKitTool())
            await toolRegistry.register(tool: AppOpenerTool())
            await toolRegistry.register(tool: ShortcutsTool())
        }
    }

    public func cancel() {
        self.isCancelled = true
        Task {
            await runner.cancelGeneration()
        }
    }

    /// Primary entry point: Processes a user request through FastIntentRouter or the multi-step ReAct loop.
    public func process(
        userPrompt: String,
        sessionHistory: [ChatMessage] = [],
        confirmationToken: String? = nil,
        progressStream: (@Sendable (String) -> Void)? = nil
    ) async -> OrchestratorResponse {
        self.isCancelled = false
        let totalStartTime = CFAbsoluteTimeGetCurrent()

        // 1. Tier 1: Fast Intent Router (<10ms direct dispatch without LLM inference)
        let routeResult = fastRouter.route(query: userPrompt)
        switch routeResult {
        case .matched(let toolName, let args, let routingMs):
            if let tool = await toolRegistry.getTool(named: toolName) {
                progressStream?("Instant action: running \(toolName)...")
                let toolResult = await tool.execute(arguments: args)
                let totalDuration = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000.0

                let responseText: String
                if let msg = toolResult.outputPayload["message"] as? String {
                    responseText = msg
                } else if let summary = toolResult.outputPayload["summary"] as? String {
                    responseText = summary
                } else if let err = toolResult.error {
                    responseText = "Error executing \(toolName): \(err)"
                } else {
                    responseText = "Executed \(toolName) successfully."
                }

                progressStream?(responseText)

                return OrchestratorResponse(
                    textResponse: responseText,
                    executedTools: [toolName],
                    requiresConfirmation: false,
                    pendingConfirmationTicket: nil,
                    routingDurationMs: routingMs,
                    totalDurationMs: totalDuration,
                    stepCount: 1
                )
            }

        case .unmatched(let routingMs):
            break
        }

        let routingDuration = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000.0

        // 2. Tier 2: Local Model ReAct Loop
        var conversationMessages: [ChatMessage] = sessionHistory
        conversationMessages.append(ChatMessage(role: "user", content: userPrompt))

        let availableTools = await toolRegistry.toolDefinitions()
        let activeManifest = await runner.currentManifest ?? ModelCatalog.shared.baseline3B
        let formatter = PromptTemplateFormatterFactory.formatter(for: activeManifest)

        var executedToolNames: [String] = []
        var iteration = 0
        var finalAssistantText = ""

        while iteration < maxIterations {
            if self.isCancelled {
                return OrchestratorResponse(
                    textResponse: "Operation was cancelled.",
                    executedTools: executedToolNames,
                    requiresConfirmation: false,
                    pendingConfirmationTicket: nil,
                    routingDurationMs: routingDuration,
                    totalDurationMs: (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000.0,
                    stepCount: iteration
                )
            }

            iteration += 1

            // Format prompt with available tools and message history
            let formattedPrompt = formatter.formatChat(
                messages: conversationMessages,
                availableTools: availableTools
            )

            // Stream response from local model runner
            var accumulatedText = ""
            do {
                let stream = await runner.generateStream(prompt: formattedPrompt, maxTokens: 512, temperature: 0.3)
                for try await token in stream {
                    if self.isCancelled { break }
                    accumulatedText += token
                    progressStream?(token)
                }
            } catch {
                finalAssistantText = "Inference error: \(error.localizedDescription)"
                break
            }

            // Parse output for tool calls
            if let parsedTool = ToolCallParser.parse(content: accumulatedText) {
                guard let tool = await toolRegistry.getTool(named: parsedTool.toolName) else {
                    // Unknown tool called by model; inject error feedback
                    let feedback = formatter.formatToolFeedback(
                        toolName: parsedTool.toolName,
                        resultJson: "{\"error\": \"Tool '\(parsedTool.toolName)' is not available on this device.\"}"
                    )
                    conversationMessages.append(ChatMessage(role: "assistant", content: accumulatedText))
                    conversationMessages.append(feedback)
                    continue
                }

                // Check security policy gate
                let policyDecision = await permissionManager.evaluate(
                    tool: tool,
                    arguments: parsedTool.arguments,
                    confirmationToken: confirmationToken
                )

                switch policyDecision {
                case .allowImmediate:
                    executedToolNames.append(tool.name)
                    progressStream?("\n[Executing \(tool.name)...]\n")

                    let result = await tool.execute(arguments: parsedTool.arguments)

                    // Convert payload to JSON string
                    let jsonStr: String
                    if let data = try? JSONSerialization.data(withJSONObject: result.outputPayload),
                       let str = String(data: data, encoding: .utf8) {
                        jsonStr = str
                    } else {
                        jsonStr = "{\"status\": \"\(result.outcome.rawValue)\"}"
                    }

                    let feedback = formatter.formatToolFeedback(toolName: tool.name, resultJson: jsonStr)
                    conversationMessages.append(ChatMessage(role: "assistant", content: accumulatedText))
                    conversationMessages.append(feedback)
                    // Continue ReAct loop to let model synthesize final user answer

                case .requiresConfirmation(let ticket):
                    let totalDuration = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000.0
                    return OrchestratorResponse(
                        textResponse: "Action requires confirmation: \(tool.name)",
                        executedTools: executedToolNames,
                        requiresConfirmation: true,
                        pendingConfirmationTicket: ticket,
                        routingDurationMs: routingDuration,
                        totalDurationMs: totalDuration,
                        stepCount: iteration
                    )

                case .denied(let reason):
                    let feedback = formatter.formatToolFeedback(
                        toolName: tool.name,
                        resultJson: "{\"error\": \"Security denied: \(reason)\"}"
                    )
                    conversationMessages.append(ChatMessage(role: "assistant", content: accumulatedText))
                    conversationMessages.append(feedback)
                }

            } else {
                // Pure conversational response, loop completed
                finalAssistantText = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        if finalAssistantText.isEmpty {
            finalAssistantText = "Task processing completed."
        }

        let totalDuration = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000.0
        return OrchestratorResponse(
            textResponse: finalAssistantText,
            executedTools: executedToolNames,
            requiresConfirmation: false,
            pendingConfirmationTicket: nil,
            routingDurationMs: routingDuration,
            totalDurationMs: totalDuration,
            stepCount: iteration
        )
    }
}
