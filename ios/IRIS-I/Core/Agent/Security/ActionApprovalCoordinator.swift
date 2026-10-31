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
    private var continuations: [UUID: CheckedContinuation<OrchestratorResponse, Error>] = [:]
    private var consumedTicketIds: Set<UUID> = []

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
    /// Safely associates each request with its own dedicated continuation by ticketId.
    public func requestApprovalAsync(ticket: ConfirmationTicket) async throws -> OrchestratorResponse {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuations[ticket.ticketId] = continuation
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
    /// Enforces: active ticket match, single-use ticket consumption, and replay prevention.
    public func approve(
        ticket: ConfirmationTicket,
        parameters: [String: Any]? = nil
    ) async -> Result<OrchestratorResponse, Error> {
        // 1. Verify active ticket
        guard let current = self.activeTicket, current.ticketId == ticket.ticketId else {
            let error = NSError(
                domain: "IRIS.ActionApproval",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Ticket is not currently active or was already dismissed."]
            )
            return .failure(error)
        }

        // 2. Prevent replay
        guard !consumedTicketIds.contains(ticket.ticketId) else {
            let error = NSError(
                domain: "IRIS.ActionApproval",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Ticket \(ticket.ticketId) has already been consumed and cannot be replayed."]
            )
            return .failure(error)
        }

        consumedTicketIds.insert(ticket.ticketId)

        let finalParams = parameters ?? ticket.rawParameters

        do {
            let response = await ReActOrchestrator.shared.executeConfirmedAction(
                ticketId: ticket.ticketId,
                parameters: finalParams
            )
            self.lastExecutionResponse = response
            if let continuation = self.continuations.removeValue(forKey: ticket.ticketId) {
                continuation.resume(returning: response)
            }
            dismissAndProcessNext()
            return .success(response)
        } catch {
            self.lastErrorMessage = error.localizedDescription
            if let continuation = self.continuations.removeValue(forKey: ticket.ticketId) {
                continuation.resume(throwing: error)
            }
            dismissAndProcessNext()
            return .failure(error)
        }
    }

    /// Explicitly cancels or rejects the active authorization ticket.
    public func reject(ticket: ConfirmationTicket, reason: String = "User declined authorization.") {
        guard let current = self.activeTicket, current.ticketId == ticket.ticketId else { return }
        consumedTicketIds.insert(ticket.ticketId)

        let error = NSError(domain: "IRIS.ActionApproval", code: 403, userInfo: [NSLocalizedDescriptionKey: reason])
        if let continuation = self.continuations.removeValue(forKey: ticket.ticketId) {
            continuation.resume(throwing: error)
        }
        dismissAndProcessNext()
    }

    private func handleTicketExpiration(_ ticket: ConfirmationTicket) {
        guard self.activeTicket?.ticketId == ticket.ticketId else { return }
        consumedTicketIds.insert(ticket.ticketId)

        let error = NSError(
            domain: "IRIS.ActionApproval",
            code: 408,
            userInfo: [NSLocalizedDescriptionKey: "Authorization request timed out and expired."]
        )
        if let continuation = self.continuations.removeValue(forKey: ticket.ticketId) {
            continuation.resume(throwing: error)
        }
        dismissAndProcessNext()
    }

    /// Cancels all currently queued approval requests, ensuring no continuation remains suspended.
    public func cancelAllQueued(reason: String = "Approval queue was cancelled.") {
        let cancelError = NSError(domain: "IRIS.ActionApproval", code: 499, userInfo: [NSLocalizedDescriptionKey: reason])
        if let active = self.activeTicket {
            consumedTicketIds.insert(active.ticketId)
            if let cont = self.continuations.removeValue(forKey: active.ticketId) {
                cont.resume(throwing: cancelError)
            }
        }
        for ticket in approvalQueue {
            consumedTicketIds.insert(ticket.ticketId)
            if let cont = self.continuations.removeValue(forKey: ticket.ticketId) {
                cont.resume(throwing: cancelError)
            }
        }
        approvalQueue.removeAll()
        dismissAndProcessNext()
    }

    public func dismissAndProcessNext() {
        countdownTimer?.cancel()
        countdownTimer = nil
        self.activeTicket = nil
        self.timeRemainingSeconds = 0
        self.isPresentingApproval = false

        // Process next queued ticket if present
        while !approvalQueue.isEmpty {
            let nextTicket = approvalQueue.removeFirst()
            if !nextTicket.isExpired {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.presentTicket(nextTicket)
                }
                return
            } else {
                consumedTicketIds.insert(nextTicket.ticketId)
                if let cont = self.continuations.removeValue(forKey: nextTicket.ticketId) {
                    cont.resume(throwing: NSError(domain: "IRIS.ActionApproval", code: 408, userInfo: [NSLocalizedDescriptionKey: "Queued ticket expired before presentation."]))
                }
            }
        }
    }

    public func resetForTesting() {
        cancelAllQueued(reason: "Reset for testing")
        consumedTicketIds.removeAll()
        continuations.removeAll()
        activeTicket = nil
        approvalQueue.removeAll()
        isPresentingApproval = false
        timeRemainingSeconds = 0
        lastExecutionResponse = nil
        lastErrorMessage = nil
    }
}
