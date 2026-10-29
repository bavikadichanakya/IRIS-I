//
//  GmailConnector.swift
//  IRIS-I
//
//  OAuth 2.0 with PKCE and REST API integration for Google Gmail.
//  Implements authenticated inbox search, full RFC MIME body parsing, exact timestamp
//  extraction, draft creation, and sending.
//  Tokens are strictly stored in Keychain and never exposed to the LLM or UI text.
//

import Foundation
import CryptoKit

public struct OAuthConfiguration: Sendable {
    public let clientId: String
    public let redirectUri: String
    public let authorizationEndpoint: URL
    public let tokenEndpoint: URL
    public let revocationEndpoint: URL

    public var isConfigured: Bool {
        !clientId.isEmpty &&
        !clientId.contains("placeholder") &&
        !clientId.contains("1082345678901") &&
        !clientId.contains("$(")
    }

    /// Derives the custom URL callback scheme from redirect URI (or reversed client ID)
    public var callbackScheme: String {
        if let url = URL(string: redirectUri), let scheme = url.scheme, !scheme.isEmpty {
            return scheme
        }
        let cleaned = clientId.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        if cleaned.hasPrefix("com.googleusercontent.apps.") {
            return cleaned
        }
        return "com.googleusercontent.apps.\(cleaned)"
    }

    public static func load(keychain: KeychainHelper = .shared) -> OAuthConfiguration {
        // 1. User keychain override (configured in-app via Settings screen)
        if let customClientId = keychain.get(forKey: "custom_gmail_client_id"), !customClientId.isEmpty {
            let customRedirect = keychain.get(forKey: "custom_gmail_redirect_uri")
            let redirect = (customRedirect != nil && !customRedirect!.isEmpty)
                ? customRedirect!
                : {
                    let cleaned = customClientId.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
                    let reversed = cleaned.hasPrefix("com.googleusercontent.apps.") ? cleaned : "com.googleusercontent.apps.\(cleaned)"
                    return "\(reversed):/oauth2redirect/google"
                }()
            return OAuthConfiguration(clientId: customClientId, redirectUri: redirect)
        }

        // 2. Process environment (e.g. CI runner or launch arguments)
        if let envClientId = ProcessInfo.processInfo.environment["GMAIL_CLIENT_ID"], !envClientId.isEmpty {
            let envRedirect = ProcessInfo.processInfo.environment["GMAIL_REDIRECT_URI"] ?? {
                let cleaned = envClientId.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
                let reversed = cleaned.hasPrefix("com.googleusercontent.apps.") ? cleaned : "com.googleusercontent.apps.\(cleaned)"
                return "\(reversed):/oauth2redirect/google"
            }()
            return OAuthConfiguration(clientId: envClientId, redirectUri: envRedirect)
        }

        // 3. Info.plist (Xcode build setting)
        if let plistClientId = Bundle.main.object(forInfoDictionaryKey: "GmailClientID") as? String,
           !plistClientId.isEmpty, !plistClientId.contains("$(") {
            let plistRedirect = (Bundle.main.object(forInfoDictionaryKey: "GmailRedirectURI") as? String) ?? {
                let cleaned = plistClientId.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
                let reversed = cleaned.hasPrefix("com.googleusercontent.apps.") ? cleaned : "com.googleusercontent.apps.\(cleaned)"
                return "\(reversed):/oauth2redirect/google"
            }()
            return OAuthConfiguration(clientId: plistClientId, redirectUri: plistRedirect)
        }

        // Unconfigured state: requires user or environment configuration
        return OAuthConfiguration(
            clientId: "",
            redirectUri: "com.googleusercontent.apps.unconfigured:/oauth2redirect/google"
        )
    }

    public init(
        clientId: String,
        redirectUri: String,
        authorizationEndpoint: URL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
        tokenEndpoint: URL = URL(string: "https://oauth2.googleapis.com/token")!,
        revocationEndpoint: URL = URL(string: "https://oauth2.googleapis.com/revoke")!
    ) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.revocationEndpoint = revocationEndpoint
    }
}

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
    private let customOAuthConfig: OAuthConfiguration?

    public var oauthConfig: OAuthConfiguration {
        customOAuthConfig ?? OAuthConfiguration.load(keychain: keychain)
    }

    private let tokenKey = "gmail_access_token"
    private let refreshTokenKey = "gmail_refresh_token"
    private let emailKey = "gmail_user_email"
    private let tokenExpiryKey = "gmail_token_expiry"

    // In-flight PKCE authorization state
    private var pendingCodeVerifier: String?
    private var pendingAuthState: String?

    public init(
        keychain: KeychainHelper = .shared,
        session: URLSession = .shared,
        oauthConfig: OAuthConfiguration? = nil
    ) {
        self.keychain = keychain
        self.session = session
        self.customOAuthConfig = oauthConfig
    }

    /// Allows user or test to provide client ID and custom redirect URI dynamically.
    public func saveClientConfiguration(clientId: String, redirectUri: String? = nil) {
        keychain.set(clientId, forKey: "custom_gmail_client_id")
        if let redirect = redirectUri, !redirect.isEmpty {
            keychain.set(redirect, forKey: "custom_gmail_redirect_uri")
        } else {
            let reversed = clientId.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
            keychain.set("com.googleusercontent.apps.\(reversed):/oauth2redirect/google", forKey: "custom_gmail_redirect_uri")
        }
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
        // Attempt to revoke the token if present
        if let token = keychain.get(forKey: tokenKey) {
            var request = URLRequest(url: oauthConfig.revocationEndpoint)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "token=\(token)".data(using: .utf8)
            _ = try? await session.data(for: request)
        }

        // Wipe all credentials from Keychain
        keychain.remove(forKey: tokenKey)
        keychain.remove(forKey: refreshTokenKey)
        keychain.remove(forKey: emailKey)
        keychain.remove(forKey: tokenExpiryKey)
        pendingCodeVerifier = nil
        pendingAuthState = nil
    }

    // MARK: - Mobile OAuth 2.0 PKCE Flow

    /// Generates the authorization URL with PKCE parameters and records the expected state.
    public func startAuthorizationFlow() throws -> URL {
        let config = self.oauthConfig
        guard config.isConfigured else {
            throw NSError(domain: "GmailConnector", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Google OAuth Client ID is not configured. Please enter your Google Cloud iOS Client ID in Settings or provide GMAIL_CLIENT_ID in your build configuration."
            ])
        }

        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)
        let state = generateRandomString(length: 24)

        self.pendingCodeVerifier = verifier
        self.pendingAuthState = state

        var components = URLComponents(url: config.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    /// Exchanges an authorization code for OAuth tokens after verifying state and PKCE verifier.
    public func handleAuthorizationRedirect(url: URL) async throws {
        let config = self.oauthConfig

        // 1. Validate callback scheme matches configured redirect URI
        if let scheme = url.scheme, scheme != config.callbackScheme {
            throw NSError(domain: "GmailConnector", code: -6, userInfo: [
                NSLocalizedDescriptionKey: "Redirect callback scheme mismatch: expected '\(config.callbackScheme)', received '\(scheme)'."
            ])
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw NSError(domain: "GmailConnector", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid redirect URL."])
        }

        // 2. Check for OAuth error from provider
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            throw NSError(domain: "GmailConnector", code: -2, userInfo: [NSLocalizedDescriptionKey: "Authorization failed: \(error)"])
        }

        // 3. Validate state parameter to protect against CSRF attacks
        guard let returnedState = queryItems.first(where: { $0.name == "state" })?.value,
              let expectedState = self.pendingAuthState,
              returnedState == expectedState else {
            throw NSError(domain: "GmailConnector", code: -3, userInfo: [NSLocalizedDescriptionKey: "OAuth state mismatch: potential CSRF detected."])
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw NSError(domain: "GmailConnector", code: -4, userInfo: [NSLocalizedDescriptionKey: "Missing authorization code in redirect."])
        }

        guard let verifier = self.pendingCodeVerifier else {
            throw NSError(domain: "GmailConnector", code: -5, userInfo: [NSLocalizedDescriptionKey: "Missing PKCE code verifier."])
        }

        // 4. Exchange authorization code for tokens
        try await exchangeCodeForTokens(code: code, verifier: verifier)
    }

    private func exchangeCodeForTokens(code: String, verifier: String) async throws {
        var request = URLRequest(url: oauthConfig.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: oauthConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: oauthConfig.redirectUri),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code_verifier", value: verifier)
        ]
        request.httpBody = bodyComponents.query?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw NSError(domain: "GmailConnector", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [
                NSLocalizedDescriptionKey: "Token exchange failed."
            ])
        }

        let refreshToken = json["refresh_token"] as? String
        let expiresIn = (json["expires_in"] as? TimeInterval) ?? 3600.0

        // Fetch user profile to identify account email
        let userEmail = (try? await fetchUserProfileEmail(accessToken: accessToken)) ?? "authorized.user@gmail.com"

        saveCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userEmail: userEmail,
            expiresInSeconds: expiresIn
        )

        self.pendingCodeVerifier = nil
        self.pendingAuthState = nil
    }

    private func fetchUserProfileEmail(accessToken: String) async throws -> String {
        guard let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo") else {
            return "user@gmail.com"
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let email = json["email"] as? String {
            return email
        }
        return "user@gmail.com"
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
        var dateHeaderString: String?

        // 1. Extract Headers
        if let payload = json["payload"] as? [String: Any],
           let headers = payload["headers"] as? [[String: String]] {
            for h in headers {
                guard let name = h["name"]?.lowercased(), let val = h["value"] else { continue }
                if name == "from" { sender = val }
                else if name == "subject" { subject = val }
                else if name == "to" { recipients = val.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                else if name == "date" { dateHeaderString = val }
            }
        }

        // 2. Parse Actual Received Date (Epoch ms timestamp from internalDate)
        var messageDate = Date()
        if let internalDateStr = json["internalDate"] as? String,
           let ms = Double(internalDateStr) {
            messageDate = Date(timeIntervalSince1970: ms / 1000.0)
        } else if let dateHeader = dateHeaderString {
            let rfc2822Formatter = DateFormatter()
            rfc2822Formatter.locale = Locale(identifier: "en_US_POSIX")
            rfc2822Formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
            if let parsed = rfc2822Formatter.date(from: dateHeader) {
                messageDate = parsed
            }
        }

        // 3. Parse Full RFC Message Body from MIME Structure (Do not substitute snippet for body)
        var fullBodyText = ""
        if let payload = json["payload"] as? [String: Any] {
            fullBodyText = extractMessageBody(from: payload)
        }

        // If body parsing yields nothing (e.g. blank email), fallback to snippet
        if fullBodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fullBodyText = snippet
        }

        return EmailMessage(
            id: id,
            sender: sender,
            recipients: recipients,
            subject: subject,
            snippet: snippet,
            body: fullBodyText,
            date: messageDate
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
                NSLocalizedDescriptionKey: "No Gmail account connected. User must link their account in Settings."
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
        var request = URLRequest(url: oauthConfig.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: oauthConfig.clientId),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]
        request.httpBody = components.query?.data(using: .utf8)

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

    /// Recursively extracts plain text or HTML body from a Gmail MIME payload.
    private func extractMessageBody(from payload: [String: Any]) -> String {
        // Direct body data
        if let bodyDict = payload["body"] as? [String: Any],
           let dataStr = bodyDict["data"] as? String,
           let decoded = decodeBase64URL(dataStr), !decoded.isEmpty {
            return decoded
        }

        // Inspect multipart subparts
        if let parts = payload["parts"] as? [[String: Any]] {
            // Prioritize text/plain parts
            for part in parts {
                if (part["mimeType"] as? String) == "text/plain",
                   let bodyDict = part["body"] as? [String: Any],
                   let dataStr = bodyDict["data"] as? String,
                   let decoded = decodeBase64URL(dataStr), !decoded.isEmpty {
                    return decoded
                }
            }

            // Fallback to text/html parts
            for part in parts {
                if (part["mimeType"] as? String) == "text/html",
                   let bodyDict = part["body"] as? [String: Any],
                   let dataStr = bodyDict["data"] as? String,
                   let decoded = decodeBase64URL(dataStr), !decoded.isEmpty {
                    return decoded
                }
            }

            // Recurse into nested multipart containers
            for part in parts {
                let nested = extractMessageBody(from: part)
                if !nested.isEmpty {
                    return nested
                }
            }
        }

        return ""
    }

    /// Decodes URL-safe Base64 string into UTF-8 text with proper padding restoration.
    private func decodeBase64URL(_ base64URL: String) -> String? {
        var base64 = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func makeRFC822Raw(recipient: String, subject: String, body: String) -> String {
        let rfcMessage = """
        To: \(recipient)
        Subject: \(subject)
        Content-Type: text/plain; charset=utf-8

        \(body)
        """

        let utf8Data = rfcMessage.data(using: .utf8) ?? Data()
        return utf8Data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - PKCE Utilities

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = verifier.data(using: .ascii) ?? Data()
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateRandomString(length: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
