//
//  ConfirmationTicket.swift
//  IRIS-I
//
//  Cryptographic single-use confirmation tickets bound to action parameter digests.
//

import Foundation
import CryptoKit

public struct ConfirmationTicket: Sendable {
    public let ticketId: String
    public let toolName: String
    public let operationType: ActionOperationType
    public let paramsHash: String
    public let rawParameters: [String: Any]
    public let createdAt: Date
    public let expiresAt: Date
    public let isConsumed: Bool

    public var isExpired: Bool {
        Date() > expiresAt
    }

    public init(
        toolName: String,
        operationType: ActionOperationType = .destructive,
        parameters: [String: Any],
        ttlSeconds: TimeInterval = 300.0
    ) {
        self.ticketId = "cfm_\(UUID().uuidString.prefix(16))"
        self.toolName = toolName
        self.operationType = operationType
        self.rawParameters = parameters
        self.paramsHash = Self.computeDigest(parameters)
        let now = Date()
        self.createdAt = now
        self.expiresAt = now.addingTimeInterval(ttlSeconds)
        self.isConsumed = false
    }

    private init(
        ticketId: String,
        toolName: String,
        operationType: ActionOperationType,
        paramsHash: String,
        rawParameters: [String: Any],
        createdAt: Date,
        expiresAt: Date,
        isConsumed: Bool
    ) {
        self.ticketId = ticketId
        self.toolName = toolName
        self.operationType = operationType
        self.paramsHash = paramsHash
        self.rawParameters = rawParameters
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isConsumed = isConsumed
    }

    public func markingConsumed() -> ConfirmationTicket {
        ConfirmationTicket(
            ticketId: self.ticketId,
            toolName: self.toolName,
            operationType: self.operationType,
            paramsHash: self.paramsHash,
            rawParameters: self.rawParameters,
            createdAt: self.createdAt,
            expiresAt: self.expiresAt,
            isConsumed: true
        )
    }

    /// Computes canonical SHA-256 digest of parameter dictionary
    public static func computeDigest(_ params: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: params, options: [.sortedKeys]) else {
            return "00000000"
        }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// Actor managing pending and consumed confirmation tickets
public actor ConfirmationManager {
    public static let shared = ConfirmationManager()

    private var activeTickets: [String: ConfirmationTicket] = [:]

    public init() {}

    public func issueTicket(
        for tool: String,
        operationType: ActionOperationType = .destructive,
        parameters: [String: Any],
        ttl: TimeInterval = 300.0
    ) -> ConfirmationTicket {
        let ticket = ConfirmationTicket(
            toolName: tool,
            operationType: operationType,
            parameters: parameters,
            ttlSeconds: ttl
        )
        activeTickets[ticket.ticketId] = ticket
        return ticket
    }

    public func getPendingTicket(ticketId: String) -> ConfirmationTicket? {
        guard let ticket = activeTickets[ticketId], !ticket.isConsumed, !ticket.isExpired else {
            return nil
        }
        return ticket
    }

    public func validateAndConsume(
        ticketId: String,
        toolName: String? = nil,
        parameters: [String: Any]
    ) throws -> ConfirmationTicket {
        guard let ticket = activeTickets[ticketId] else {
            throw ConfirmationError.invalidTicket
        }

        if ticket.isConsumed {
            throw ConfirmationError.alreadyConsumed
        }

        if ticket.isExpired {
            activeTickets.removeValue(forKey: ticketId)
            throw ConfirmationError.expiredTicket
        }

        if let expectedTool = toolName, ticket.toolName != expectedTool {
            throw ConfirmationError.toolMismatch(expected: ticket.toolName, actual: expectedTool)
        }

        let incomingHash = ConfirmationTicket.computeDigest(parameters)
        if incomingHash != ticket.paramsHash {
            throw ConfirmationError.parameterMismatch
        }

        let consumedTicket = ticket.markingConsumed()
        activeTickets[ticketId] = consumedTicket
        return consumedTicket
    }

    public func purgeExpired() {
        let now = Date()
        activeTickets = activeTickets.filter { _, ticket in
            !ticket.isConsumed && ticket.expiresAt > now
        }
    }
}

public typealias ConfirmationTicketRegistry = ConfirmationManager

public enum ConfirmationError: LocalizedError, Sendable, Equatable {
    case invalidTicket
    case alreadyConsumed
    case expiredTicket
    case parameterMismatch
    case toolMismatch(expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case .invalidTicket:
            return "Confirmation ticket is invalid or does not exist."
        case .alreadyConsumed:
            return "Confirmation ticket has already been consumed (replay prevention)."
        case .expiredTicket:
            return "Confirmation ticket has expired. Please re-authorize the action."
        case .parameterMismatch:
            return "Action parameters were altered after confirmation was issued."
        case .toolMismatch(let expected, let actual):
            return "Action tool mismatch: expected '\(expected)', received '\(actual)'."
        }
    }
}
