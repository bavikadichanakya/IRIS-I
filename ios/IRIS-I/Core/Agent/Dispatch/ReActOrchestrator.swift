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
    public let executionRecord: ExecutionRecord?

    public init(
        textResponse: String,
        executedTools: [String] = [],
        requiresConfirmation: Bool = false,
        pendingConfirmationTicket: ConfirmationTicket? = nil,
        routingDurationMs: Double = 0.0,
        totalDurationMs: Double = 0.0,
        stepCount: Int = 1,
        executionRecord: ExecutionRecord? = nil
    ) {
        self.textResponse = textResponse
        self.executedTools = executedTools
        self.requiresConfirmation = requiresConfirmation
        self.pendingConfirmationTicket = pendingConfirmationTicket
        self.routingDurationMs = routingDurationMs
        self.totalDurationMs = totalDurationMs
        self.stepCount = stepCount
        self.executionRecord = executionRecord
    }
}

public actor ReActOrchestrator {
    public static let shared = ReActOrchestrator()

    private let runner = LocalModelRunner.shared
    private let toolRegistry = ToolRegistry.shared
    private let permissionManager = PermissionManager.shared
    private let fastRouter = FastIntentRouter()

    private var maxIterations: Int = 5
    private var isCancelled: Bool = false
    private var isInitialized: Bool = false

    public init() {}

    /// Deterministically registers all built-in tools before any operations are executed.
    public func ensureInitialized() async {
        guard !isInitialized else { return }
        await toolRegistry.register(tool: SystemInfoTool())
        await toolRegistry.register(tool: WebSearchTool())
        await toolRegistry.register(tool: MailTool())
        await toolRegistry.register(tool: MessagingTool())
        await toolRegistry.register(tool: EventKitTool())
        await toolRegistry.register(tool: AppOpenerTool())
        await toolRegistry.register(tool: ShortcutsTool())
        isInitialized = true
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
        await ensureInitialized()
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
                switch toolResult.outcome {
                case .completedVerified:
                    if let msg = toolResult.outputPayload["message"] as? String {
                        responseText = msg
                    } else if let summary = toolResult.outputPayload["summary"] as? String {
                        responseText = summary
                    } else {
                        responseText = "Executed \(toolName) successfully."
                    }
                case .completedUnverified:
                    if let msg = toolResult.outputPayload["message"] as? String {
                        responseText = msg
                    } else {
                        responseText = "Action dispatched to external system."
                    }
                case .failed:
                    responseText = toolResult.error ?? "Action failed."
                case .deniedPolicy:
                    responseText = toolResult.error ?? "Action denied by security policy."
                case .cancelled:
                    responseText = "Action was cancelled."
                case .timedOut:
                    responseText = "Action timed out."
                case .unsupported:
                    responseText = toolResult.error ?? "Action is not supported on this platform."
                case .accepted, .inProgress, .confirmationRequired:
                    responseText = (toolResult.outputPayload["message"] as? String) ?? "Action status: \(toolResult.outcome.rawValue)"
                }

                let execState: StructuredExecutionState
                switch toolResult.outcome {
                case .completedVerified: execState = .completedVerified
                case .completedUnverified: execState = .completedUnverified
                case .failed: execState = .failed
                case .deniedPolicy: execState = .failed
                case .unsupported: execState = .unsupported
                case .cancelled: execState = .cancelled
                case .timedOut: execState = .timedOut
                case .confirmationRequired: execState = .permissionRequired
                case .inProgress, .accepted: execState = .inProgress
                }

                var strArgs: [String: String] = [:]
                for (k, v) in args { strArgs[k] = "\(v)" }

                var strPayload: [String: String] = [:]
                for (k, v) in toolResult.outputPayload { strPayload[k] = "\(v)" }

                let record = ExecutionRecord(
                    userRequest: userPrompt,
                    interpretedIntent: "Direct invocation of \(toolName)",
                    selectedTool: toolName,
                    validatedArguments: strArgs,
                    permissionResult: "authorized",
                    executionState: execState,
                    toolOutcome: toolResult.outcome,
                    resultPayload: strPayload,
                    errorDetails: toolResult.error,
                    isVerified: toolResult.verified,
                    durationMs: totalDuration,
                    requiredUserAction: nil,
                    timestamp: Date()
                )

                await MainActor.run {
                    #if canImport(ActivityKit)
                    switch execState {
                    case .completedVerified:
                        IRISDynamicIslandManager.shared.updateSessionState(.completedVerified, details: responseText)
                    case .completedUnverified:
                        IRISDynamicIslandManager.shared.updateSessionState(.completedUnverified, details: responseText)
                    case .failed, .unsupported:
                        IRISDynamicIslandManager.shared.updateSessionState(.failed, details: responseText)
                    case .cancelled:
                        IRISDynamicIslandManager.shared.updateSessionState(.cancelled)
                    default:
                        break
                    }
                    #endif
                }

                progressStream?(responseText)

                return OrchestratorResponse(
                    textResponse: responseText,
                    executedTools: [toolName],
                    requiresConfirmation: false,
                    pendingConfirmationTicket: nil,
                    routingDurationMs: routingMs,
                    totalDurationMs: totalDuration,
                    stepCount: 1,
                    executionRecord: record
                )
            }

        case .unmatched(let routingMs):
            break
        }

        let routingDuration = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000.0

        // 2. Tier 2: Local Model ReAct Loop Preflight
        let isModelLoaded = await runner.isModelLoaded
        if !isModelLoaded {
            let baseline = ModelCatalog.shared.baseline3B
            let isInstalled = ModelStorageManager.shared.isModelInstalled(baseline)
            if isInstalled {
                progressStream?("Initializing neural brain context...")
                do {
                    try await runner.loadModel(manifest: baseline, contextSize: 2048, forceMockEngine: false)
                } catch {
                    let msg = "Could not activate local neural model: \(error.localizedDescription)"
                    return OrchestratorResponse(
                        textResponse: msg,
                        executedTools: [],
                        requiresConfirmation: false,
                        pendingConfirmationTicket: nil,
                        routingDurationMs: routingDuration,
                        totalDurationMs: (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000.0,
                        stepCount: 1,
                        executionRecord: nil
                    )
                }
            } else {
                let msg = "The on-device neural brain (Qwen 2.5 3B) is not installed yet. You can download and activate it in Settings, or ask me to open apps like YouTube, Music, or Camera."
                return OrchestratorResponse(
                    textResponse: msg,
                    executedTools: [],
                    requiresConfirmation: false,
                    pendingConfirmationTicket: nil,
                    routingDurationMs: routingDuration,
                    totalDurationMs: (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000.0,
                    stepCount: 1,
                    executionRecord: nil
                )
            }
        }

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

                    // Convert payload to JSON string with outcome metadata
                    var payload = result.outputPayload
                    payload["_outcome"] = result.outcome.rawValue
                    if let err = result.error {
                        payload["error"] = err
                    }

                    let jsonStr: String
                    if let data = try? JSONSerialization.data(withJSONObject: payload),
                       let str = String(data: data, encoding: .utf8) {
                        jsonStr = str
                    } else {
                        jsonStr = "{\"outcome\": \"\(result.outcome.rawValue)\"}"
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

    /// Directly executes an authorized pending action ticket without re-querying or hallucinating via the LLM.
    public func executeConfirmedAction(
        ticketId: String,
        parameters: [String: Any]
    ) async -> OrchestratorResponse {
        await ensureInitialized()
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let ticket = await ConfirmationManager.shared.getPendingTicket(ticketId: ticketId) else {
            return OrchestratorResponse(
                textResponse: "Authorization error: Confirmation ticket expired, was already consumed, or was not found.",
                executedTools: [],
                requiresConfirmation: false,
                pendingConfirmationTicket: nil,
                routingDurationMs: 0,
                totalDurationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0,
                stepCount: 1
            )
        }

        guard let tool = await toolRegistry.getTool(named: ticket.toolName) else {
            return OrchestratorResponse(
                textResponse: "Authorization error: Tool '\(ticket.toolName)' is no longer available.",
                executedTools: [],
                requiresConfirmation: false,
                pendingConfirmationTicket: nil,
                routingDurationMs: 0,
                totalDurationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0,
                stepCount: 1
            )
        }

        // Validate and consume the single-use ticket with canonical parameter hashing
        do {
            _ = try await ConfirmationManager.shared.validateAndConsume(
                ticketId: ticketId,
                toolName: ticket.toolName,
                parameters: parameters
            )
        } catch {
            return OrchestratorResponse(
                textResponse: "Security violation: \(error.localizedDescription)",
                executedTools: [],
                requiresConfirmation: false,
                pendingConfirmationTicket: nil,
                routingDurationMs: 0,
                totalDurationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0,
                stepCount: 1
            )
        }

        // Execute the tool with original approved parameters
        let result = await tool.execute(arguments: parameters)
        let totalDuration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        let responseText: String
        switch result.outcome {
        case .completedVerified:
            if let msg = result.outputPayload["message"] as? String {
                responseText = msg
            } else if let summary = result.outputPayload["summary"] as? String {
                responseText = summary
            } else {
                responseText = "Authorized action executed successfully: \(tool.name)."
            }
        case .completedUnverified:
            let msg = (result.outputPayload["message"] as? String) ?? "Action handed off to external system (unverified outcome)."
            responseText = "Handed off: \(msg)"
        case .failed:
            let err = result.error ?? (result.outputPayload["error"] as? String) ?? "Unknown failure."
            responseText = "Action failed: \(err)"
        case .unsupported:
            let err = result.error ?? (result.outputPayload["error"] as? String) ?? "Action or application is unsupported on this device."
            responseText = "Unsupported: \(err)"
        case .accepted:
            responseText = (result.outputPayload["message"] as? String) ?? "Action accepted for processing."
        case .inProgress:
            responseText = (result.outputPayload["message"] as? String) ?? "Action is in progress."
        case .confirmationRequired:
            responseText = "Action requires further confirmation."
        case .deniedPolicy:
            let err = result.error ?? "Action denied by security policy."
            responseText = "Action denied: \(err)"
        case .cancelled:
            responseText = "Action was cancelled."
        case .timedOut:
            responseText = "Action execution timed out."
        }

        return OrchestratorResponse(
            textResponse: responseText,
            executedTools: [tool.name],
            requiresConfirmation: false,
            pendingConfirmationTicket: nil,
            routingDurationMs: 0,
            totalDurationMs: totalDuration,
            stepCount: 1
        )
    }
}
