//
//  PermissionManager.swift
//  IRIS-I
//
//  Deterministic policy gate evaluating action operation types (read, draft, send, destructive, remoteCommand).
//

import Foundation

public actor PermissionManager {
    public static let shared = PermissionManager()

    /// Configuration for whether external send operations require confirmation.
    public var requireConfirmationForSend: Bool = true

    public init(requireConfirmationForSend: Bool = true) {
        self.requireConfirmationForSend = requireConfirmationForSend
    }

    /// Evaluates if an action can execute immediately or requires user confirmation based on operation type.
    public func evaluate(
        tool: any IRISAgentTool,
        arguments: [String: Any],
        hasExplicitApproval: Bool = false,
        confirmationToken: String? = nil
    ) async -> PolicyDecision {
        let opType = tool.operationType(for: arguments)

        switch opType {
        case .read:
            // Read-only actions (time, status, read emails, query calendar) execute immediately
            return .allowImmediate

        case .draft:
            // Local drafting actions (open composer, save local draft) execute immediately
            return .allowImmediate

        case .send:
            // External transmission (actually sending email or message over the wire)
            if !requireConfirmationForSend || hasExplicitApproval {
                return .allowImmediate
            }
            if let token = confirmationToken {
                do {
                    _ = try await ConfirmationManager.shared.validateAndConsume(
                        ticketId: token,
                        toolName: tool.name,
                        parameters: arguments
                    )
                    return .allowImmediate
                } catch let err as ConfirmationError {
                    return .denied(reason: err.localizedDescription)
                } catch {
                    return .denied(reason: "Send confirmation failed: \(error.localizedDescription)")
                }
            }
            let ticket = await ConfirmationManager.shared.issueTicket(
                for: tool.name,
                operationType: .send,
                parameters: arguments
            )
            return .requiresConfirmation(ticket: ticket)

        case .destructive:
            // Destructive operations (deleting emails, clearing events, wiping memory) strictly require a confirmation ticket
            if let token = confirmationToken {
                do {
                    _ = try await ConfirmationManager.shared.validateAndConsume(
                        ticketId: token,
                        toolName: tool.name,
                        parameters: arguments
                    )
                    return .allowImmediate
                } catch let err as ConfirmationError {
                    return .denied(reason: err.localizedDescription)
                } catch {
                    return .denied(reason: "Destructive action confirmation failed: \(error.localizedDescription)")
                }
            }
            let ticket = await ConfirmationManager.shared.issueTicket(
                for: tool.name,
                operationType: .destructive,
                parameters: arguments
            )
            return .requiresConfirmation(ticket: ticket)

        case .remoteCommand:
            // Remote execution or shell operations strictly require confirmation
            if let token = confirmationToken {
                do {
                    _ = try await ConfirmationManager.shared.validateAndConsume(
                        ticketId: token,
                        toolName: tool.name,
                        parameters: arguments
                    )
                    return .allowImmediate
                } catch let err as ConfirmationError {
                    return .denied(reason: err.localizedDescription)
                } catch {
                    return .denied(reason: "Remote command confirmation failed: \(error.localizedDescription)")
                }
            }
            let ticket = await ConfirmationManager.shared.issueTicket(
                for: tool.name,
                operationType: .remoteCommand,
                parameters: arguments
            )
            return .requiresConfirmation(ticket: ticket)
        }
    }
}

public enum PolicyDecision: Sendable {
    case allowImmediate
    case requiresConfirmation(ticket: ConfirmationTicket)
    case denied(reason: String)
}
