//
//  VoiceSessionCoordinator.swift
//  IRIS-I
//
//  Central Voice Session Coordinator owning the complete voice-session lifecycle.
//  Coordinates AudioSessionManager, SpeechRecognitionManager, LocalModelRunner,
//  VoiceResponseManager, and ActivityKit Live Activities with a single authoritative state.
//

import Foundation
import SwiftUI
import AVFoundation

public enum VoiceSessionState: Equatable, Sendable {
    case idle
    case preparing
    case requestingPermissions
    case startingAudio
    case listening(transcript: String, audioLevel: Float)
    case processing(transcript: String)
    case thinking(prompt: String)
    case executing(action: String)
    case responding(text: String, audioLevel: Float)
    case completed(summary: String)
    case failed(reason: String)
    case cancelled

    public var isRecording: Bool {
        switch self {
        case .listening:
            return true
        default:
            return false
        }
    }

    public var isResponding: Bool {
        switch self {
        case .responding:
            return true
        default:
            return false
        }
    }

    public var displayTitle: String {
        switch self {
        case .idle:
            return "Ready"
        case .preparing:
            return "Preparing..."
        case .requestingPermissions:
            return "Requesting Permissions..."
        case .startingAudio:
            return "Starting Audio..."
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .thinking:
            return "Thinking..."
        case .executing(let action):
            return "Executing: \(action)"
        case .responding:
            return "Responding..."
        case .completed:
            return "Completed"
        case .failed(let err):
            return "Error: \(err)"
        case .cancelled:
            return "Cancelled"
        }
    }
}

@MainActor
public final class VoiceSessionCoordinator: ObservableObject {
    public static let shared = VoiceSessionCoordinator()

    @Published public private(set) var state: VoiceSessionState = .idle
    @Published public private(set) var activeTranscript: String = ""
    @Published public private(set) var latestResponse: String = ""
    @Published public private(set) var currentAudioLevel: Float = 0.0
    @Published public private(set) var errorMessage: String? = nil

    private let audioManager = AudioSessionManager.shared
    private let speechManager = SpeechRecognitionManager.shared
    private let responseManager = VoiceResponseManager.shared
    private let dynamicIsland = IRISDynamicIslandManager.shared
    private let orchestrator = ReActOrchestrator.shared

    private var activeSessionId: UUID?
    private var isStartingSession: Bool = false

    private init() {
        audioManager.delegate = self
        speechManager.delegate = self
        responseManager.delegate = self
    }

    // MARK: - Public Voice Session Lifecycle

    /// Starts a new voice session from Action Button, Siri, or In-App Tap.
    /// Strictly prevents multiple simultaneous sessions or duplicate audio taps.
    public func startVoiceSession() async {
        guard !isStartingSession else { return }

        // If currently speaking, barge-in by stopping speech
        if responseManager.isSpeaking {
            responseManager.stopSpeaking()
        }

        // If already listening, focus current session rather than re-creating
        if case .listening = state {
            return
        }

        isStartingSession = true
        defer { isStartingSession = false }

        self.state = .preparing
        self.activeTranscript = ""
        self.errorMessage = nil
        let newSessionId = UUID()
        self.activeSessionId = newSessionId

        // Step 1: Ensure Permissions
        self.state = .requestingPermissions
        let micAllowed = await audioManager.requestMicrophonePermission()
        guard micAllowed else {
            handleSessionError("Microphone access is required for IRIS voice assistant.")
            return
        }

        let speechAllowed = await speechManager.requestSpeechAuthorization()
        guard speechAllowed else {
            handleSessionError("Speech Recognition authorization is required for voice commands.")
            return
        }

        // Step 2: Prepare Audio Capture & Speech Recognition
        self.state = .startingAudio

        do {
            try speechManager.startRecognition()
            let speechRef = self.speechManager
            try audioManager.startCapture { buffer in
                speechRef.appendAudioBuffer(buffer)
            }

            // Only transition to .listening AFTER audio engine and recognizer have engaged
            self.state = .listening(transcript: "", audioLevel: 0.0)
            self.dynamicIsland.startLiveActivity()
            self.dynamicIsland.updateSessionState(.listening, audioLevel: 0.1)
        } catch {
            handleSessionError("Failed to start audio engine: \(error.localizedDescription)")
            cleanupAudioPipeline()
        }
    }

    /// Stops listening and transitions to processing
    public func stopVoiceSession() {
        guard case .listening(let transcript, _) = state else { return }
        audioManager.stopCapture()
        speechManager.stopRecognition()

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self.state = .idle
            self.dynamicIsland.endLiveActivity()
        } else {
            submitRecognizedCommand(trimmed)
        }
    }

    /// Cancels any active session immediately
    public func cancelVoiceSession() {
        cleanupAudioPipeline()
        responseManager.stopSpeaking()
        self.state = .cancelled
        self.dynamicIsland.updateSessionState(.cancelled)
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            if self.state == .cancelled {
                self.state = .idle
                self.dynamicIsland.endLiveActivity()
            }
        }
    }

    /// Submits a transcribed voice command through the local AI and agent pipeline
    public func submitRecognizedCommand(_ command: String) {
        cleanupAudioPipeline()

        let cleanQuery = VoiceSessionCoordinator.stripWakeWords(command)
        guard !cleanQuery.isEmpty else {
            // User said only "Hey IRIS" -> respond with ready prompt
            speakResponse("What can I do for you?", isGreeting: true)
            return
        }

        self.state = .thinking(prompt: cleanQuery)
        self.dynamicIsland.updateSessionState(.thinking, audioLevel: 0.2)

        Task {
            let result = await orchestrator.process(userPrompt: cleanQuery)
            await MainActor.run {
                self.latestResponse = result.textResponse
                self.speakResponse(result.textResponse, isGreeting: false)
            }
        }
    }

    public func handleSessionError(_ message: String) {
        cleanupAudioPipeline()
        responseManager.stopSpeaking()
        self.errorMessage = message
        self.state = .failed(reason: message)
        self.dynamicIsland.updateSessionState(.failed, details: message)

        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if case .failed = self.state {
                self.state = .idle
                self.dynamicIsland.endLiveActivity()
            }
        }
    }

    // MARK: - Internal Helpers

    public func resetForTesting() {
        cleanupAudioPipeline()
        responseManager.stopSpeaking()
        self.state = .idle
        self.activeTranscript = ""
        self.latestResponse = ""
        self.currentAudioLevel = 0.0
        self.errorMessage = nil
        self.activeSessionId = nil
        self.isStartingSession = false
    }

    private func speakResponse(_ text: String, isGreeting: Bool) {
        self.state = .responding(text: text, audioLevel: 0.5)
        self.dynamicIsland.updateSessionState(.responding, audioLevel: 0.5)
        responseManager.speak(text: text)
    }

    private func cleanupAudioPipeline() {
        audioManager.stopCapture()
        speechManager.stopRecognition()
    }

    public static func stripWakeWords(_ text: String) -> String {
        let lower = text.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        var clean = lower
        for variant in ["hey iris", "hey, iris", "iris"] {
            if clean.hasPrefix(variant) {
                var remainder = clean.dropFirst(variant.count)
                while let first = remainder.first, first == "," || first == "." || first == " " || first == ":" || first == "!" || first == "?" {
                    remainder = remainder.dropFirst()
                }
                clean = String(remainder)
                break
            }
        }
        return clean.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }
}

// MARK: - AudioSessionManagerDelegate

extension VoiceSessionCoordinator: AudioSessionManagerDelegate {
    public func audioSessionManager(_ manager: AudioSessionManager, didUpdateAudioLevel level: Float) {
        self.currentAudioLevel = level
        if case .listening(let transcript, _) = state {
            self.state = .listening(transcript: transcript, audioLevel: level)
            self.dynamicIsland.updateLiveActivity(statusText: "Listening...", isListening: true, audioLevel: level)
        }
    }

    public func audioSessionManagerDidReceiveInterruption(_ manager: AudioSessionManager) {
        cancelVoiceSession()
    }

    public func audioSessionManagerDidChangeRoute(_ manager: AudioSessionManager, toBluetooth: Bool) {
        // Route changed (e.g. AirPods connected/disconnected)
    }
}

// MARK: - SpeechRecognitionManagerDelegate

extension VoiceSessionCoordinator: SpeechRecognitionManagerDelegate {
    public func speechRecognitionManager(_ manager: SpeechRecognitionManager, didUpdatePartialTranscript transcript: String) {
        self.activeTranscript = transcript
        if case .listening(_, let level) = state {
            self.state = .listening(transcript: transcript, audioLevel: level)
        }
    }

    public func speechRecognitionManager(_ manager: SpeechRecognitionManager, didFinishWithFinalTranscript transcript: String) {
        self.activeTranscript = transcript
        stopVoiceSession()
    }

    public func speechRecognitionManager(_ manager: SpeechRecognitionManager, didFailWithError error: Error) {
        // Ignore cancelled errors
        if (error as NSError).code == 203 || (error as NSError).domain == "kAFAssistantErrorDomain" {
            return
        }
        handleSessionError(error.localizedDescription)
    }
}

// MARK: - VoiceResponseManagerDelegate

extension VoiceSessionCoordinator: VoiceResponseManagerDelegate {
    public func voiceResponseManagerDidStartSpeaking(_ manager: VoiceResponseManager) {
        self.dynamicIsland.updateSessionState(.responding, audioLevel: 0.6)
    }

    public func voiceResponseManagerDidFinishSpeaking(_ manager: VoiceResponseManager) {
        self.state = .completed(summary: latestResponse)
        self.dynamicIsland.updateSessionState(.completedVerified)
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if case .completed = self.state {
                self.state = .idle
                self.dynamicIsland.endLiveActivity()
            }
        }
    }

    public func voiceResponseManagerDidCancelSpeaking(_ manager: VoiceResponseManager) {
        self.state = .idle
        self.dynamicIsland.endLiveActivity()
    }
}
