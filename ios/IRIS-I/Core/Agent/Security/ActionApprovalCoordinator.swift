//
//  ActionApprovalCoordinator.swift
//  IRIS-I
//
//  Centralized coordinator for sensitive action authorization, parameter binding,
//  countdown expiration, single-use ticket consumption, and multi-step approval workflows.
//

import Foundation
import Combine

@MainActor
public final class ActionApprovalCoordinator: ObservableObject {
    public static let shared = ActionApprovalCoordinator()

    @Published public private(set) var activeTicket: ConfirmationTicket? = nil
    @Published public private(set) var timeRemainingSeconds: Int = 0
    @Published public var isPresentingApproval: Bool = false
    @Published public private(set) var lastExecutionResponse: OrchestratorResponse? = nil
    @Published public private(set) var lastErrorMessage: String? = nil

    private var approvalQueue: [ConfirmationTicket] = []
    private var countdownTimer: AnyCancellable?
    private var approvalContinuation: CheckedContinuation<OrchestratorResponse, Error>?

    public init() {}

    /// Requests user authorization for a sensitive tool ticket.
    /// If an approval is already active, queues the new ticket for sequential review.
    public func requestApproval(ticket: ConfirmationTicket) {
        if activeTicket == nil {
            presentTicket(ticket)
        } else {
            approvalQueue.append(ticket)
        }
    }

    /// Async variation that suspends until the user approves or rejects the action.
    public func requestApprovalAsync(ticket: ConfirmationTicket) async throws -> OrchestratorResponse {
        return try await withCheckedThrowingContinuation { continuation in
            self.approvalContinuation = continuation
            self.requestApproval(ticket: ticket)
        }
    }

    private func presentTicket(_ ticket: ConfirmationTicket) {
        self.activeTicket = ticket
        self.lastErrorMessage = nil
        self.timeRemainingSeconds = max(0, Int(ticket.expiresAt.timeIntervalSinceNow))
        self.isPresentingApproval = true

        startCountdownTimer()
    }

    private func startCountdownTimer() {
        countdownTimer?.cancel()
        countdownTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                guard let ticket = self.activeTicket else {
                    self.countdownTimer?.cancel()
                    return
                }

                let remaining = Int(ticket.expiresAt.timeIntervalSinceNow)
                if remaining <= 0 {
                    self.timeRemainingSeconds = 0
                    self.handleTicketExpiration(ticket)
                } else {
                    self.timeRemainingSeconds = remaining
                }
            }
    }

    /// Approves the active ticket, optionally with verified edited parameters.
    public func approve(
        ticket: ConfirmationTicket,
        parameters: [String: Any]? = nil
    ) async -> Result<OrchestratorResponse, Error> {
        let finalParams = parameters ?? ticket.rawParameters

        do {
            let response = await ReActOrchestrator.shared.executeConfirmedAction(
                ticketId: ticket.ticketId,
                parameters: finalParams
            )
            self.lastExecutionResponse = response
            self.approvalContinuation?.resume(returning: response)
            self.approvalContinuation = nil
            dismissAndProcessNext()
            return .success(response)
        } catch {
            self.lastErrorMessage = error.localizedDescription
            self.approvalContinuation?.resume(throwing: error)
            self.approvalContinuation = nil
            dismissAndProcessNext()
            return .failure(error)
        }
    }

    /// Explicitly cancels or rejects the active authorization ticket.
    public func reject(ticket: ConfirmationTicket, reason: String = "User declined authorization.") {
        let error = NSError(domain: "IRIS.ActionApproval", code: 403, userInfo: [NSLocalizedDescriptionKey: reason])
        self.approvalContinuation?.resume(throwing: error)
        self.approvalContinuation = nil
        dismissAndProcessNext()
    }

    private func handleTicketExpiration(_ ticket: ConfirmationTicket) {
        let error = NSError(domain: "IRIS.ActionApproval", code: 408, userInfo: [NSLocalizedDescriptionKey: "Authorization request timed out and expired."])
        self.approvalContinuation?.resume(throwing: error)
        self.approvalContinuation = nil
        dismissAndProcessNext()
    }

    public func dismissAndProcessNext() {
        countdownTimer?.cancel()
        countdownTimer = nil
        self.activeTicket = nil
        self.timeRemainingSeconds = 0
        self.isPresentingApproval = false

        // Process next queued ticket if present
        if !approvalQueue.isEmpty {
            let nextTicket = approvalQueue.removeFirst()
            // Ensure next ticket is not already expired
            if !nextTicket.isExpired {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.presentTicket(nextTicket)
                }
            } else {
                dismissAndProcessNext()
            }
        }
    }
}

