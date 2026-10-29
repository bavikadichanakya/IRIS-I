//
//  GmailConnectorTests.swift
//  IRIS_ITests
//
//  Verifies GmailConnector state transitions, credential isolation, and disconnect cleanup.
//

import XCTest
@testable import IRIS_ICore

final class GmailConnectorTests: XCTestCase {

    var testKeychain: KeychainHelper!
    var connector: GmailConnector!

    override func setUp() {
        super.setUp()
        testKeychain = KeychainHelper(service: "com.iris.assistant.test.gmail.\(UUID().uuidString)")
        connector = GmailConnector(keychain: testKeychain)
    }

    override func tearDown() {
        testKeychain.clearAll()
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
}

