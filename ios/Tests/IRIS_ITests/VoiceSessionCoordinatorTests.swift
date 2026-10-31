//
//  VoiceSessionCoordinatorTests.swift
//  IRIS-ITests
//
//  Comprehensive unit tests verifying VoiceSessionCoordinator lifecycle, single-session residency,
//  state transitions, cancellation, error handling, wake-word parsing, and tool execution parity.
//

import XCTest
#if canImport(Speech)
import Speech
#endif
#if canImport(IRIS_ICore)
@testable import IRIS_ICore
#elseif canImport(IRIS_I)
@testable import IRIS_I
#endif

final class VoiceSessionCoordinatorTests: XCTestCase {

    @MainActor
    override func setUp() {
        super.setUp()
        VoiceSessionCoordinator.shared.resetForTesting()
    }

    @MainActor
    override func tearDown() {
        VoiceSessionCoordinator.shared.resetForTesting()
        super.tearDown()
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
    func testCancellationTransitionsState() {
        let coordinator = VoiceSessionCoordinator.shared
        coordinator.cancelVoiceSession()
        XCTAssertEqual(coordinator.state, .cancelled)
        coordinator.resetForTesting()
    }

    @MainActor
    func testSessionErrorTransitionsToFailed() {
        let coordinator = VoiceSessionCoordinator.shared
        let errMessage = "Microphone access denied"
        coordinator.handleSessionError(errMessage)
        XCTAssertEqual(coordinator.state, .failed(reason: errMessage))
        XCTAssertEqual(coordinator.errorMessage, errMessage)
        coordinator.resetForTesting()
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
        XCTAssertEqual(VoiceSessionCoordinator.stripWakeWords("Hey IRIS open YouTube"), "open youtube")
        XCTAssertEqual(VoiceSessionCoordinator.stripWakeWords("IRIS open YouTube"), "open youtube")
        XCTAssertEqual(VoiceSessionCoordinator.stripWakeWords("open YouTube"), "open youtube")
        XCTAssertEqual(VoiceSessionCoordinator.stripWakeWords("hey iris"), "")
        XCTAssertEqual(VoiceSessionCoordinator.stripWakeWords(""), "")
    }

    @MainActor
    func testStopVoiceSessionWithExplicitTranscript() {
        let coordinator = VoiceSessionCoordinator.shared
        coordinator.stopVoiceSession(finalTranscript: "open YouTube")
        // Should transition to thinking state with stripped query
        XCTAssertEqual(coordinator.state, .thinking(prompt: "open youtube"))
        coordinator.resetForTesting()
    }

    @MainActor
    func testStopVoiceSessionWithEmptyTranscriptResetsToIdle() {
        let coordinator = VoiceSessionCoordinator.shared
        coordinator.stopVoiceSession(finalTranscript: "   ")
        XCTAssertEqual(coordinator.state, .idle)
    }

    @MainActor
    func testSubmitRecognizedCommandWakeWordOnlyTriggersGreeting() {
        let coordinator = VoiceSessionCoordinator.shared
        coordinator.submitRecognizedCommand("Hey IRIS")
        // Wake-word only should transition to responding with ready prompt
        XCTAssertEqual(coordinator.state, .responding(text: "What can I do for you?", audioLevel: 0.5))
        coordinator.resetForTesting()
    }

    @MainActor
    func testSpeechManagerSyncWithCoordinator() {
        let speech = SpeechManager.shared
        speech.syncWithCoordinator(state: .listening, audioLevel: 0.42, transcript: "testing")
        XCTAssertEqual(speech.state, .listening)
        XCTAssertEqual(speech.audioLevel, 0.42)
        XCTAssertEqual(speech.recognizedText, "testing")

        speech.syncWithCoordinator(state: .idle, audioLevel: 0.0)
        XCTAssertEqual(speech.state, .idle)
    }

    func testFastIntentRoutingOpenYouTubeParity() {
        let router = FastIntentRouter()
        let result = router.route(query: "open YouTube")
        switch result {
        case .matched(let toolName, let arguments, let duration):
            XCTAssertEqual(toolName, "AppOpenerTool")
            XCTAssertEqual(arguments["app_name"] as? String, "youtube")
            XCTAssertLessThan(duration, 10.0)
        case .unmatched:
            XCTFail("Expected 'open YouTube' to match AppOpenerTool")
        }
    }

    func testFastIntentRoutingTimeParity() {
        let router = FastIntentRouter()
        let result = router.route(query: "what is the time")
        switch result {
        case .matched(let toolName, let arguments, let duration):
            XCTAssertEqual(toolName, "SystemInfoTool")
            XCTAssertEqual(arguments["action"] as? String, "time")
            XCTAssertLessThan(duration, 10.0)
        case .unmatched:
            XCTFail("Expected 'what is the time' to match SystemInfoTool")
        }
    }

    func testSpeechRecognitionOfflineRequirements() {
        let manager = SpeechRecognitionManager.shared
        XCTAssertTrue(manager.isStrictOnDeviceRequired, "Strict on-device speech recognition must be enforced")

        #if canImport(Speech)
        // Test unsupported recognizer throws explicit offline error
        let unsupportedRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "und"))
        if let unsupp = unsupportedRecognizer {
            if !unsupp.supportsOnDeviceRecognition {
                XCTAssertThrowsError(try manager.validateOfflineCapability(for: unsupp)) { error in
                    let nsError = error as NSError
                    XCTAssertEqual(nsError.domain, "IRIS.Speech")
                }
            }
        }

        // Test nil recognizer throws unavailable error
        XCTAssertThrowsError(try manager.validateOfflineCapability(for: nil)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "IRIS.Speech")
            XCTAssertEqual(nsError.code, -1)
        }
        #endif
    }
}
