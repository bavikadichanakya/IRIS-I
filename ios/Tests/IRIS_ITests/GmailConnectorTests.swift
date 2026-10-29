//
//  GmailConnectorTests.swift
//  IRIS_ITests
//
//  Verifies GmailConnector state transitions, credential isolation, PKCE generation,
//  state validation, callback scheme matching, error handling, message parsing with
//  full MIME body & timestamp, and disconnect cleanup.
//

import XCTest
#if canImport(IRIS_ICore)
@testable import IRIS_ICore
#elseif canImport(IRIS_I)
@testable import IRIS_I
#endif

// Mock URLProtocol to intercept URLSession requests during offline tests
final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class GmailConnectorTests: XCTestCase {

    var testKeychain: KeychainHelper!
    var connector: GmailConnector!
    var mockSession: URLSession!
    let mockOAuthConfig = OAuthConfiguration(
        clientId: "test-client-123.apps.googleusercontent.com",
        redirectUri: "com.googleusercontent.apps.test-client-123:/oauth2redirect"
    )

    override func setUp() {
        super.setUp()
        testKeychain = KeychainHelper(service: "com.iris.assistant.test.gmail.\(UUID().uuidString)")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)

        connector = GmailConnector(
            keychain: testKeychain,
            session: mockSession,
            oauthConfig: mockOAuthConfig
        )
    }

    override func tearDown() {
        testKeychain.clearAll()
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testInitialStateIsDisconnected() async {
        let state = await connector.state
        XCTAssertEqual(state, .disconnected)
        XCTAssertFalse(state.isConnected)
        XCTAssertNil(state.accountEmail)
    }

    func testSavedCredentialsReflectConnectedState() async {
        await connector.saveCredentials(
            accessToken: "mock_access_token_12345",
            refreshToken: "mock_refresh_token_67890",
            userEmail: "testuser@gmail.com",
            expiresInSeconds: 3600
        )

        let state = await connector.state
        if case .connected(let email) = state {
            XCTAssertEqual(email, "testuser@gmail.com")
        } else {
            XCTFail("Expected .connected state, got \(state)")
        }
        XCTAssertTrue(state.isConnected)
    }

    func testExpiredTokenReflectsTokenExpiredState() async {
        await connector.saveCredentials(
            accessToken: "mock_access_token_expired",
            refreshToken: "mock_refresh_token_valid",
            userEmail: "testuser@gmail.com",
            expiresInSeconds: -10 // Already expired in the past
        )

        let state = await connector.state
        if case .tokenExpired(let email) = state {
            XCTAssertEqual(email, "testuser@gmail.com")
        } else {
            XCTFail("Expected .tokenExpired state, got \(state)")
        }
    }

    func testDisconnectWipesCredentials() async throws {
        await connector.saveCredentials(
            accessToken: "token_to_wipe",
            refreshToken: "refresh_to_wipe",
            userEmail: "wipe@gmail.com",
            expiresInSeconds: 3600
        )

        var state = await connector.state
        XCTAssertTrue(state.isConnected)

        try await connector.disconnect()

        state = await connector.state
        XCTAssertEqual(state, .disconnected)
        XCTAssertNil(testKeychain.get(forKey: "gmail_access_token"))
        XCTAssertNil(testKeychain.get(forKey: "gmail_refresh_token"))
    }

    func testPKCEAuthorizationURLGeneration() async throws {
        let authURL = try await connector.startAuthorizationFlow()
        let urlString = authURL.absoluteString

        XCTAssertTrue(urlString.contains("response_type=code"))
        XCTAssertTrue(urlString.contains("code_challenge="))
        XCTAssertTrue(urlString.contains("code_challenge_method=S256"))
        XCTAssertTrue(urlString.contains("state="))
        XCTAssertTrue(urlString.contains("gmail.readonly"))
    }

    func testAuthorizationRedirectRejectsStateMismatch() async throws {
        _ = try await connector.startAuthorizationFlow()

        let tamperedRedirect = URL(string: "com.googleusercontent.apps.test-client-123:/oauth2redirect?code=auth_code_123&state=tampered_state_456")!

        do {
            try await connector.handleAuthorizationRedirect(url: tamperedRedirect)
            XCTFail("State mismatch must fail authorization redirect")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("state mismatch"))
        }
    }

    func testAuthorizationRedirectRejectsSchemeMismatch() async throws {
        _ = try await connector.startAuthorizationFlow()

        let invalidSchemeRedirect = URL(string: "some.other.scheme:/oauth2redirect?code=123&state=abc")!

        do {
            try await connector.handleAuthorizationRedirect(url: invalidSchemeRedirect)
            XCTFail("Scheme mismatch must fail authorization redirect")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("scheme mismatch"))
        }
    }

    func testOAuthErrorInRedirectThrows() async throws {
        _ = try await connector.startAuthorizationFlow()

        let errorRedirect = URL(string: "com.googleusercontent.apps.test-client-123:/oauth2redirect?error=access_denied&state=none")!

        do {
            try await connector.handleAuthorizationRedirect(url: errorRedirect)
            XCTFail("OAuth error in redirect must throw error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Authorization failed"))
        }
    }

    func testMissingCredentialsThrowsUnauthorized() async {
        do {
            _ = try await connector.searchMessages(query: "from:test")
            XCTFail("searchMessages without credentials must throw 401")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, 401)
        }
    }

    func testUnconfiguredClientIdThrowsOnAuthStart() async {
        let unconfiguredConnector = GmailConnector(
            keychain: testKeychain,
            session: mockSession,
            oauthConfig: OAuthConfiguration(clientId: "", redirectUri: "")
        )

        do {
            _ = try await unconfiguredConnector.startAuthorizationFlow()
            XCTFail("Unconfigured client ID must throw error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Client ID is not configured"))
        }
    }

    func testGetMessageParsesExactDateAndMIMEBody() async throws {
        await connector.saveCredentials(
            accessToken: "mock_token",
            refreshToken: nil,
            userEmail: "test@gmail.com",
            expiresInSeconds: 3600
        )

        // Mock Gmail message API response with RFC MIME plain text body and timestamp
        let sampleBodyText = "Hello from OpenAI! Your API key has been created."
        let base64Body = Data(sampleBodyText.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")

        let messageJson = """
        {
            "id": "msg_openai_123",
            "snippet": "Hello from OpenAI!...",
            "internalDate": "1730200000000",
            "payload": {
                "headers": [
                    {"name": "From", "value": "OpenAI <support@openai.com>"},
                    {"name": "Subject", "value": "Welcome to OpenAI Developer Platform"},
                    {"name": "To", "value": "developer@example.com"}
                ],
                "parts": [
                    {
                        "mimeType": "text/plain",
                        "body": {
                            "data": "\(base64Body)"
                        }
                    }
                ]
            }
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, messageJson.data(using: .utf8)!)
        }

        let message = try await connector.getMessage(id: "msg_openai_123")

        XCTAssertEqual(message.id, "msg_openai_123")
        XCTAssertEqual(message.sender, "OpenAI <support@openai.com>")
        XCTAssertEqual(message.subject, "Welcome to OpenAI Developer Platform")
        XCTAssertEqual(message.recipients, ["developer@example.com"])
        // Verify full body is parsed and not substituted by snippet
        XCTAssertEqual(message.body, sampleBodyText)
        // Verify internalDate timestamp was parsed into Date
        XCTAssertEqual(message.date.timeIntervalSince1970, 1730200000.0)
    }

    func testEmptyInboxSearchReturnsEmptyArray() async throws {
        await connector.saveCredentials(
            accessToken: "mock_token",
            refreshToken: nil,
            userEmail: "test@gmail.com",
            expiresInSeconds: 3600
        )

        let emptySearchJson = """
        {
            "resultSizeEstimate": 0
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, emptySearchJson.data(using: .utf8)!)
        }

        let messages = try await connector.searchMessages(query: "from:nonexistent@domain.com")
        XCTAssertTrue(messages.isEmpty)
    }

    func testAuthorizedGmailFlowEndToEnd() async throws {
        // 1. Connect account with valid credentials
        await connector.saveCredentials(
            accessToken: "valid_e2e_access_token",
            refreshToken: "valid_e2e_refresh_token",
            userEmail: "authorized_user@gmail.com",
            expiresInSeconds: 3600
        )
        let state = await connector.state
        XCTAssertTrue(state.isConnected)
        XCTAssertEqual(state.accountEmail, "authorized_user@gmail.com")

        // 2. Search for known test message ("from:OpenAI")
        let sampleBodyText = "OpenAI Developer Platform: New model updates available."
        let base64Body = Data(sampleBodyText.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")

        let searchResponseJson = """
        {
            "messages": [
                {"id": "msg_openai_999", "threadId": "thread_999"}
            ],
            "resultSizeEstimate": 1
        }
        """

        let getMessageResponseJson = """
        {
            "id": "msg_openai_999",
            "snippet": "OpenAI Developer Platform updates...",
            "internalDate": "1730210000000",
            "payload": {
                "headers": [
                    {"name": "From", "value": "OpenAI <support@openai.com>"},
                    {"name": "Subject", "value": "OpenAI Developer Updates"},
                    {"name": "To", "value": "authorized_user@gmail.com"}
                ],
                "parts": [
                    {
                        "mimeType": "text/plain",
                        "body": {
                            "data": "\(base64Body)"
                        }
                    }
                ]
            }
        }
        """

        let createDraftResponseJson = """
        {
            "id": "draft_openai_abc",
            "message": {
                "id": "draft_msg_123"
            }
        }
        """

        let sendResponseJson = """
        {
            "id": "sent_msg_openai_789"
        }
        """

        MockURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""
            let method = request.httpMethod ?? "GET"

            if path.contains("/messages/send") && method == "POST" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (response, sendResponseJson.data(using: .utf8)!)
            } else if path.contains("/drafts") && method == "POST" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (response, createDraftResponseJson.data(using: .utf8)!)
            } else if path.contains("/messages/msg_openai_999") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (response, getMessageResponseJson.data(using: .utf8)!)
            } else if path.contains("/messages") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (response, searchResponseJson.data(using: .utf8)!)
            }

            let notFound = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (notFound, Data())
        }

        // Search messages
        let found = try await connector.searchMessages(query: "from:OpenAI")
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.id, "msg_openai_999")

        // Read content
        let message = try await connector.getMessage(id: "msg_openai_999")
        XCTAssertEqual(message.subject, "OpenAI Developer Updates")
        XCTAssertEqual(message.sender, "OpenAI <support@openai.com>")
        XCTAssertEqual(message.body, sampleBodyText)
        XCTAssertEqual(message.date.timeIntervalSince1970, 1730210000.0)

        // Create draft
        let draftId = try await connector.createDraft(
            recipient: "support@openai.com",
            subject: "Re: OpenAI Developer Updates",
            body: "Acknowledging receipt of the update."
        )
        XCTAssertEqual(draftId, "draft_openai_abc")

        // 3. Verify that sending requires explicit confirmation ticket
        let mailTool = MailTool(provider: connector)
        XCTAssertEqual(mailTool.operationType(for: ["action": "send_email"]), .send)

        // Issue single-use confirmation ticket
        let ticketParams: [String: Any] = [
            "action": "send_email",
            "recipient": "support@openai.com",
            "subject": "Re: OpenAI Developer Updates"
        ]
        let ticket = await ConfirmationManager.shared.issueTicket(
            for: "MailTool",
            operationType: .send,
            parameters: ticketParams
        )
        XCTAssertFalse(ticket.isConsumed)

        // Validate that executing with approval succeeds and consumes ticket
        let consumed = try await ConfirmationManager.shared.validateAndConsume(
            ticketId: ticket.ticketId,
            toolName: "MailTool",
            parameters: ticketParams
        )
        XCTAssertTrue(consumed.isConsumed)

        // Execute send with authorized provider
        let sentMsgId = try await connector.sendEmail(
            recipient: "support@openai.com",
            subject: "Re: OpenAI Developer Updates",
            body: "Approved outgoing response"
        )
        XCTAssertEqual(sentMsgId, "sent_msg_openai_789")
    }
}
