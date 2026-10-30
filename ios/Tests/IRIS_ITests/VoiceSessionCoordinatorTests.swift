//
//  VoiceSessionCoordinatorTests.swift
//  IRIS-ITests
//
//  Unit tests verifying VoiceSessionCoordinator lifecycle, single-session residency,
//  state transitions, cancellation, error handling, and wake-word parsing.
//

import XCTest
#if canImport(IRIS_ICore)
@testable import IRIS_ICore
#elseif canImport(IRIS_I)
@testable import IRIS_I
#endif

final class VoiceSessionCoordinatorTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        VoiceSessionCoordinator.shared.resetForTesting()
    }

    @MainActor
    override func tearDown() async throws {
        VoiceSessionCoordinator.shared.resetForTesting()
        try await super.tearDown()
    }

    @MainActor
    func testInitialStateIsIdle() {
        let coordinator = VoiceSessionCoordinator.shared
        coordinator.resetForTesting()
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertEqual(coordinator.currentAudioLevel, 0.0)
        XCTAssertTrue(coordinator.activeTranscript.isEmpty)
    }

    @MainActor
    func testCancellationTransitionsState() async throws {
        let coordinator = VoiceSessionCoordinator.shared
        coordinator.cancelVoiceSession()
        XCTAssertEqual(coordinator.state, .cancelled)
    }

    @MainActor
    func testSessionErrorTransitionsToFailed() async throws {
        let coordinator = VoiceSessionCoordinator.shared
        let errMessage = "Microphone access denied"
        coordinator.handleSessionError(errMessage)
        XCTAssertEqual(coordinator.state, .failed(reason: errMessage))
        XCTAssertEqual(coordinator.errorMessage, errMessage)
    }

    @MainActor
    func testStateHelperProperties() {
        let listeningState = VoiceSessionState.listening(transcript: "Hello IRIS", audioLevel: 0.5)
        XCTAssertTrue(listeningState.isRecording)
        XCTAssertFalse(listeningState.isResponding)
        XCTAssertEqual(listeningState.displayTitle, "Listening...")

        let respondingState = VoiceSessionState.responding(text: "I am IRIS", audioLevel: 0.7)
        XCTAssertFalse(respondingState.isRecording)
        XCTAssertTrue(respondingState.isResponding)
        XCTAssertEqual(respondingState.displayTitle, "Responding...")

        let thinkingState = VoiceSessionState.thinking(prompt: "Hello")
        XCTAssertEqual(thinkingState.displayTitle, "Thinking...")

        let idleState = VoiceSessionState.idle
        XCTAssertEqual(idleState.displayTitle, "Ready")
    }

    @MainActor
    func testAudioSessionManagerInitialState() {
        let manager = AudioSessionManager.shared
        XCTAssertEqual(manager.latestLevel, 0.0)
    }

    @MainActor
    func testWakeWordStripping() {
        XCTAssertEqual(VoiceSessionCoordinator.stripWakeWords("Hey IRIS, what time is it?"), "what time is it")
        XCTAssertEqual(VoiceSessionCoordinator.stripWakeWords("iris tell me the weather"), "tell me the weather")
        XCTAssertEqual(VoiceSessionCoordinator.stripWakeWords("Hey, IRIS! Open notes."), "open notes")
        XCTAssertEqual(VoiceSessionCoordinator.stripWakeWords("hey iris"), "")
    }
}
