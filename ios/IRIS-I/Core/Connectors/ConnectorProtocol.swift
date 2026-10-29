//
//  ConnectorProtocol.swift
//  IRIS-I
//
//  Standardized protocol and connection state machine for external service integrations
//  (e.g., Gmail, Google Calendar, PC Bridge, iCloud).
//

import Foundation

public enum ConnectorState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected(accountEmail: String)
    case tokenExpired(accountEmail: String)
    case error(String)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var accountEmail: String? {
        switch self {
        case .connected(let email), .tokenExpired(let email):
            return email
        default:
            return nil
        }
    }
}

public protocol AccountConnector: Sendable {
    var id: String { get }
    var displayName: String { get }
    var state: ConnectorState { get async }
    func disconnect() async throws
}

public struct EmailMessage: Sendable, Codable {
    public let id: String
    public let sender: String
    public let recipients: [String]
    public let subject: String
    public let snippet: String
    public let body: String
    public let date: Date

    public init(
        id: String,
        sender: String,
        recipients: [String] = [],
        subject: String,
        snippet: String,
        body: String = "",
        date: Date = Date()
    ) {
        self.id = id
        self.sender = sender
        self.recipients = recipients
        self.subject = subject
        self.snippet = snippet
        self.body = body
        self.date = date
    }
}

public protocol MailProviderProtocol: Sendable {
    var state: ConnectorState { get async }
    func searchMessages(query: String, maxResults: Int) async throws -> [EmailMessage]
    func getMessage(id: String) async throws -> EmailMessage
    func createDraft(recipient: String, subject: String, body: String) async throws -> String
    func sendEmail(recipient: String, subject: String, body: String) async throws -> String
}
