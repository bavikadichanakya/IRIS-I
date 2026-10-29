//
//  GmailConnector.swift
//  IRIS-I
//
//  OAuth 2.0 and REST API integration for Google Gmail.
//  Implements authenticated inbox search, message retrieval, draft creation, and sending.
//  Tokens are strictly stored in Keychain and never exposed to the LLM or UI text.
//

import Foundation

public actor GmailConnector: AccountConnector, MailProviderProtocol {
    public static let shared = GmailConnector()

    public let id = "com.google.gmail"
    public let displayName = "Gmail"

    // Minimal scopes required for personal assistant capabilities
    public static let scopes = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/gmail.compose",
        "https://www.googleapis.com/auth/gmail.send"
    ]

    private let keychain: KeychainHelper
    private let session: URLSession

    private let tokenKey = "gmail_access_token"
    private let refreshTokenKey = "gmail_refresh_token"
    private let emailKey = "gmail_user_email"
    private let tokenExpiryKey = "gmail_token_expiry"

    public init(keychain: KeychainHelper = .shared, session: URLSession = .shared) {
        self.keychain = keychain
        self.session = session
    }

    // MARK: - AccountConnector State

    public var state: ConnectorState {
        guard let email = keychain.get(forKey: emailKey),
              let _ = keychain.get(forKey: tokenKey) else {
            return .disconnected
        }

        if let expiryStr = keychain.get(forKey: tokenExpiryKey),
           let expiryTime = Double(expiryStr) {
            let now = Date().timeIntervalSince1970
            if now >= expiryTime {
                // If refresh token exists, it can be renewed; otherwise expired
                if keychain.get(forKey: refreshTokenKey) != nil {
                    return .tokenExpired(accountEmail: email)
                }
                return .disconnected
            }
        }

        return .connected(accountEmail: email)
    }

    /// Stores newly acquired OAuth credentials securely in Keychain.
    public func saveCredentials(
        accessToken: String,
        refreshToken: String?,
        userEmail: String,
        expiresInSeconds: TimeInterval
    ) {
        keychain.set(accessToken, forKey: tokenKey)
        if let rt = refreshToken {
            keychain.set(rt, forKey: refreshTokenKey)
        }
        keychain.set(userEmail, forKey: emailKey)
        let expiryDate = Date().addingTimeInterval(expiresInSeconds).timeIntervalSince1970
        keychain.set(String(expiryDate), forKey: tokenExpiryKey)
    }

    public func disconnect() async throws {
        // Attempt to revoke the token if possible
        if let token = keychain.get(forKey: tokenKey),
           let revokeURL = URL(string: "https://oauth2.googleapis.com/revoke?token=\(token)") {
            var request = URLRequest(url: revokeURL)
            request.httpMethod = "POST"
            _ = try? await session.data(for: request)
        }

        // Wipe credentials from Keychain
        keychain.remove(forKey: tokenKey)
        keychain.remove(forKey: refreshTokenKey)
        keychain.remove(forKey: emailKey)
        keychain.remove(forKey: tokenExpiryKey)
    }

    // MARK: - MailProviderProtocol Implementation

    public func searchMessages(query: String, maxResults: Int = 10) async throws -> [EmailMessage] {
        let token = try await validAccessToken()

        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "GmailConnector", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to search Gmail messages (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 500))."
            ])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messagesList = json["messages"] as? [[String: Any]] else {
            return [] // No messages found matching query
        }

        var results: [EmailMessage] = []
        for item in messagesList.prefix(maxResults) {
            if let id = item["id"] as? String {
                if let msg = try? await getMessage(id: id) {
                    results.append(msg)
                }
            }
        }

        return results
    }

    public func getMessage(id: String) async throws -> EmailMessage {
        let token = try await validAccessToken()

        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=full") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "GmailConnector", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to fetch Gmail message '\(id)'."
            ])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "GmailConnector", code: -1, userInfo: [NSLocalizedDescriptionKey: "Malformed message JSON."])
        }

        let snippet = (json["snippet"] as? String) ?? ""
        var sender = "Unknown"
        var subject = "(No Subject)"
        var recipients: [String] = []

        if let payload = json["payload"] as? [String: Any],
           let headers = payload["headers"] as? [[String: String]] {
            for h in headers {
                guard let name = h["name"]?.lowercased(), let val = h["value"] else { continue }
                if name == "from" { sender = val }
                else if name == "subject" { subject = val }
                else if name == "to" { recipients = val.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            }
        }

        return EmailMessage(
            id: id,
            sender: sender,
            recipients: recipients,
            subject: subject,
            snippet: snippet,
            body: snippet,
            date: Date()
        )
    }

    public func createDraft(recipient: String, subject: String, body: String) async throws -> String {
        let token = try await validAccessToken()

        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/drafts") else {
            throw URLError(.badURL)
        }

        let rawMessage = makeRFC822Raw(recipient: recipient, subject: subject, body: body)
        let bodyPayload: [String: Any] = [
            "message": [
                "raw": rawMessage
            ]
        ]
        let postData = try JSONSerialization.data(withJSONObject: bodyPayload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = postData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "GmailConnector", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create Gmail draft."
            ])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let draftId = json["id"] as? String else {
            return "draft_created"
        }

        return draftId
    }

    public func sendEmail(recipient: String, subject: String, body: String) async throws -> String {
        let token = try await validAccessToken()

        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send") else {
            throw URLError(.badURL)
        }

        let rawMessage = makeRFC822Raw(recipient: recipient, subject: subject, body: body)
        let bodyPayload: [String: Any] = [
            "raw": rawMessage
        ]
        let postData = try JSONSerialization.data(withJSONObject: bodyPayload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = postData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "GmailConnector", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to send email via Gmail API."
            ])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageId = json["id"] as? String else {
            return "message_sent"
        }

        return messageId
    }

    // MARK: - Internal Helpers

    private func validAccessToken() async throws -> String {
        guard let token = keychain.get(forKey: tokenKey) else {
            throw NSError(domain: "GmailConnector", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "No Gmail account connected. User must sign in through IRIS-I Settings."
            ])
        }

        // Check if token is expired and needs refresh
        if let expiryStr = keychain.get(forKey: tokenExpiryKey),
           let expiry = Double(expiryStr),
           Date().timeIntervalSince1970 >= expiry {
            if let refreshToken = keychain.get(forKey: refreshTokenKey) {
                return try await refreshAccessToken(refreshToken: refreshToken)
            } else {
                throw NSError(domain: "GmailConnector", code: 401, userInfo: [
                    NSLocalizedDescriptionKey: "Gmail token expired and no refresh token available."
                ])
            }
        }

        return token
    }

    private func refreshAccessToken(refreshToken: String) async throws -> String {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Note: In production apps with Google Sign-In, token refresh is managed by GoogleSignIn SDK / ASWebAuthenticationSession
        let bodyParams = "client_id=iris-assistant&grant_type=refresh_token&refresh_token=\(refreshToken)"
        request.httpBody = bodyParams.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String else {
            throw NSError(domain: "GmailConnector", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "Failed to refresh expired Gmail access token."
            ])
        }

        let expiresIn = (json["expires_in"] as? TimeInterval) ?? 3600.0
        keychain.set(newAccessToken, forKey: tokenKey)
        let expiryDate = Date().addingTimeInterval(expiresIn).timeIntervalSince1970
        keychain.set(String(expiryDate), forKey: tokenExpiryKey)

        return newAccessToken
    }

    /// Formats an RFC 2822 email header + body and returns a URL-safe Base64 string required by Gmail API.
    private func makeRFC822Raw(recipient: String, subject: String, body: String) -> String {
        let rfcMessage = """
        To: \(recipient)
        Subject: \(subject)
        Content-Type: text/plain; charset=utf-8

        \(body)
        """

        let utf8Data = rfcMessage.data(using: .utf8) ?? Data()
        // Convert to URL-safe base64 string without padding
        return utf8Data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

