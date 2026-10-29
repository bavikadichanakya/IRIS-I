//
//  GmailConnectorTests.swift
//  IRIS_ITests
//
//  Verifies GmailConnector state transitions, credential isolation, PKCE generation,
//  state validation, message parsing with full MIME body & timestamp, and disconnect cleanup.
//

import XCTest
@testable import IRIS_ICore

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

    override func setUp() {
        super.setUp()
        testKeychain = KeychainHelper(service: "com.iris.assistant.test.gmail.\(UUID().uuidString)")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)

        connector = GmailConnector(keychain: testKeychain, session: mockSession)
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

    func testPKCEAuthorizationURLGeneration() async {
        let authURL = await connector.startAuthorizationFlow()
        let urlString = authURL.absoluteString

        XCTAssertTrue(urlString.contains("response_type=code"))
        XCTAssertTrue(urlString.contains("code_challenge="))
        XCTAssertTrue(urlString.contains("code_challenge_method=S256"))
        XCTAssertTrue(urlString.contains("state="))
        XCTAssertTrue(urlString.contains("gmail.readonly"))
    }

    func testAuthorizationRedirectRejectsStateMismatch() async {
        _ = await connector.startAuthorizationFlow()

        let tamperedRedirect = URL(string: "com.googleusercontent.apps.test:/oauth2redirect/google?code=auth_code_123&state=tampered_state_456")!

        do {
            try await connector.handleAuthorizationRedirect(url: tamperedRedirect)
            XCTFail("State mismatch must fail authorization redirect")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("state mismatch"))
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
}
