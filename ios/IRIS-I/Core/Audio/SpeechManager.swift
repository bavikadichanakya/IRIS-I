//
//  SpeechManager.swift
//  IRIS-I
//
//  Lightweight SwiftUI observable adapter coordinating between in-app views
//  and the central authoritative VoiceSessionCoordinator pipeline.
//

import Foundation
import AVFoundation
#if canImport(Speech)
import Speech
#endif

public enum VoiceState: String, Sendable {
    case idle
    case listening
    case processing
    case speaking
}

@MainActor
public final class SpeechManager: NSObject, ObservableObject, @unchecked Sendable {
    public static let shared = SpeechManager()

    @Published public var state: VoiceState = .idle
    @Published public var recognizedText: String = ""
    @Published public var spokenResponse: String = ""
    @Published public var audioLevel: Float = 0.0
    @Published public var errorMessage: String? = nil
    @Published public var wakeWordDetected: Bool = false
    @Published public var isBackgroundWakeWordEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBackgroundWakeWordEnabled, forKey: "iris_background_wake_word_enabled")
        }
    }
    @Published public var isAwaitingFollowUp: Bool = false

    private override init() {
        self.isBackgroundWakeWordEnabled = UserDefaults.standard.bool(forKey: "iris_background_wake_word_enabled")
        super.init()
    }

    // MARK: - State Synchronization from VoiceSessionCoordinator

    public func syncWithCoordinator(
        state: VoiceState,
        audioLevel: Float = 0.0,
        transcript: String? = nil,
        response: String? = nil
    ) {
        self.state = state
        self.audioLevel = audioLevel
        if let t = transcript {
            self.recognizedText = t
        }
        if let r = response {
            self.spokenResponse = r
        }
    }

    // MARK: - Permissions

    public func requestPermissions() async -> Bool {
        let mic = await AudioSessionManager.shared.requestMicrophonePermission()
        let speech = await SpeechRecognitionManager.shared.requestSpeechAuthorization()
        return mic && speech
    }

    // MARK: - Speech To Text (Delegated to VoiceSessionCoordinator)

    public func startListening() async {
        if state == .speaking {
            stopSpeaking()
        }
        await VoiceSessionCoordinator.shared.startVoiceSession()
    }

    public func stopListeningInternal() {
        VoiceSessionCoordinator.shared.stopVoiceSession()
    }

    @discardableResult
    public func stopListening() -> String {
        let text = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        VoiceSessionCoordinator.shared.stopVoiceSession(finalTranscript: text)
        return text
    }

    public func stopListeningAndProcess(customHandler: ((String) async -> Void)? = nil) {
        let text = stopListening()
        guard !text.isEmpty else {
            self.state = .idle
            return
        }

        if let handler = customHandler {
            self.state = .processing
            Task {
                await handler(text)
            }
        } else {
            processVoiceQuery(rawText: text)
        }
    }

    public func processVoiceQuery(rawText: String? = nil) {
        let input = (rawText ?? self.recognizedText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            self.state = .idle
            return
        }
        VoiceSessionCoordinator.shared.submitRecognizedCommand(input)
    }

    // MARK: - Text To Speech (Delegated to VoiceResponseManager)

    public func speak(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.state = .idle
            return
        }
        self.spokenResponse = text
        self.state = .speaking
        VoiceResponseManager.shared.speak(text: text)
    }

    public func stopSpeaking() {
        VoiceResponseManager.shared.stopSpeaking()
        if state == .speaking {
            self.state = .idle
        }
    }
}
