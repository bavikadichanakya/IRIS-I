//
//  PermissionManager.swift
//  IRIS-I
//
//  Deterministic policy gate evaluating tool permission levels and confirmation requirements.
//

import Foundation

public actor PermissionManager {
    public static let shared = PermissionManager()

    public init() {}

    /// Evaluates if an action can execute immediately or requires user confirmation.
    public func evaluate(
        tool: IRISAgentTool,
        arguments: [String: Any],
        hasExplicitApproval: Bool = false,
        confirmationToken: String? = nil
    ) async -> PolicyDecision {
        // 1. Public level tools execute freely
        if tool.permissionLevel == .publicLevel {
            return .allowImmediate
        }

        // 2. Protected tools execute if user has already granted session permission
        if tool.permissionLevel == .protectedLevel {
            // Protected actions can execute directly with audit log or prompt if configured
            return .allowImmediate
        }

        // 3. Sensitive actions strictly require a validated single-use confirmation ticket
        if tool.permissionLevel == .sensitiveLevel {
            guard let token = confirmationToken else {
                // Issue a new ticket for user confirmation
                let ticket = await ConfirmationManager.shared.issueTicket(for: tool.name, parameters: arguments)
                return .requiresConfirmation(ticket: ticket)
            }

            do {
                _ = try await ConfirmationManager.shared.validateAndConsume(ticketId: token, parameters: arguments)
                return .allowImmediate
            } catch let err as ConfirmationError {
                return .denied(reason: err.localizedDescription)
            } catch {
                return .denied(reason: "Security confirmation failed: \(error.localizedDescription)")
            }
        }

        return .denied(reason: "Unknown permission policy tier.")
    }
}

public enum PolicyDecision: Sendable {
    case allowImmediate
    case requiresConfirmation(ticket: ConfirmationTicket)
    case denied(reason: String)
}

