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
    @Published public var isContinuousListeningEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isContinuousListeningEnabled, forKey: "iris_continuous_listening")
        }
    }

    private let audioManager = AudioSessionManager.shared
    private let speechManager = SpeechRecognitionManager.shared
    private let responseManager = VoiceResponseManager.shared
    private let dynamicIsland = IRISDynamicIslandManager.shared
    private let orchestrator = ReActOrchestrator.shared

    private var activeSessionId: UUID?
    private var isStartingSession: Bool = false
    private var isSubmittingCommand: Bool = false

    private init() {
        if UserDefaults.standard.object(forKey: "iris_continuous_listening") != nil {
            self.isContinuousListeningEnabled = UserDefaults.standard.bool(forKey: "iris_continuous_listening")
        }
        audioManager.delegate = self
        speechManager.delegate = self
        responseManager.delegate = self
    }

    // MARK: - Public Voice Session Lifecycle

    /// Starts a new voice session from Action Button, Siri, or In-App Tap.
    /// Strictly enforces:
    /// intent_received -> session_created -> activity_requested -> activity_started -> audio_started -> listening_state_published
    public func startVoiceSession() async {
        guard !isStartingSession else {
            print("[VOICE_SESSION] startVoiceSession ignored: session start already in progress")
            return
        }

        // If currently speaking, barge-in by stopping speech
        if responseManager.isSpeaking {
            responseManager.stopSpeaking()
        }

        // If already listening, focus current session rather than re-creating
        if case .listening = state {
            print("[VOICE_SESSION] already listening, keeping active session")
            return
        }

        isStartingSession = true
        defer { isStartingSession = false }

        let newSessionId = UUID()
        self.activeSessionId = newSessionId
        print("[VOICE_SESSION] session_created: \(newSessionId.uuidString)")

        self.state = .preparing
        self.activeTranscript = ""
        self.latestResponse = ""
        self.errorMessage = nil
        self.isSubmittingCommand = false

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

        // Step 2: Request ActivityKit Live Activity
        print("[VOICE_SESSION] activity_requested for session: \(newSessionId.uuidString)")
        self.dynamicIsland.startLiveActivity()
        print("[VOICE_SESSION] activity_started for session: \(newSessionId.uuidString)")

        // Step 3: Prepare Audio Capture & Speech Recognition
        self.state = .startingAudio
        print("[VOICE_SESSION] audio_started for session: \(newSessionId.uuidString)")

        do {
            try speechManager.startRecognition()
            let speechRef = self.speechManager
            try audioManager.startCapture { buffer in
                speechRef.appendAudioBuffer(buffer)
                AudioFrameProcessor.shared.processBuffer(buffer)
            }

            // Step 4: Publish authoritative listening state
            self.state = .listening(transcript: "", audioLevel: 0.1)
            print("[VOICE_SESSION] listening_state_published for session: \(newSessionId.uuidString)")
            self.dynamicIsland.updateSessionState(.listening, audioLevel: 0.1)
            SpeechManager.shared.syncWithCoordinator(state: .listening, audioLevel: 0.1)
        } catch {
            print("[VOICE_SESSION] Failed to start audio engine: \(error.localizedDescription)")
            handleSessionError("Failed to start audio engine: \(error.localizedDescription)")
            cleanupAudioPipeline()
        }
    }

    /// Called by the acoustic WakeWordDetector when the wake phrase is recognized
    public func wakeWordDetected(phrase: String) {
        print("[VOICE_SESSION] Acoustic wake phrase confirmed: '\(phrase)'")
        Task { @MainActor in
            if case .idle = self.state {
                await self.startVoiceSession()
            }
        }
    }

    /// Stops listening and transitions to processing.
    /// Uses explicit finalTranscript if provided, otherwise falls back to activeTranscript.
    public func stopVoiceSession(finalTranscript: String? = nil) {
        guard !isSubmittingCommand else { return }

        let candidate: String
        if let explicit = finalTranscript, !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidate = explicit
        } else if !activeTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidate = activeTranscript
        } else if case .listening(let t, _) = state, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidate = t
        } else {
            candidate = ""
        }

        cleanupAudioPipeline()

        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[VOICE_SESSION] stopVoiceSession resolved transcript: '\(trimmed)'")

        if trimmed.isEmpty {
            print("[VOICE_SESSION] Empty transcript resolved, resetting to idle")
            self.state = .idle
            self.dynamicIsland.endLiveActivity()
            SpeechManager.shared.syncWithCoordinator(state: .idle, audioLevel: 0.0)
        } else {
            submitRecognizedCommand(trimmed)
        }
    }

    /// Cancels any active session immediately
    public func cancelVoiceSession() {
        cleanupAudioPipeline()
        responseManager.stopSpeaking()
        self.isSubmittingCommand = false
        self.state = .cancelled
        self.dynamicIsland.updateSessionState(.cancelled)
        SpeechManager.shared.syncWithCoordinator(state: .idle)
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            if self.state == .cancelled {
                self.state = .idle
                self.dynamicIsland.endLiveActivity()
            }
        }
    }

    /// Submits a transcribed voice command through the local AI and agent pipeline.
    /// Strictly guarantees exactly-once execution and deterministic wake word stripping.
    public func submitRecognizedCommand(_ command: String) {
        guard !isSubmittingCommand else {
            print("[VOICE_SESSION] Duplicate command submission ignored: '\(command)'")
            return
        }
        isSubmittingCommand = true

        cleanupAudioPipeline()
        self.activeTranscript = command

        let cleanQuery = VoiceSessionCoordinator.stripWakeWords(command)
        print("[VOICE_SESSION] wake_words_stripped from '\(command)' -> '\(cleanQuery)'")

        let lower = cleanQuery.lowercased()
        if lower == "stop" || lower == "cancel" || lower == "exit" || lower == "goodbye" || lower == "dismiss" || lower == "bye" || lower == "stop listening" {
            print("[VOICE_SESSION] User explicitly ended continuous voice session: '\(cleanQuery)'")
            self.isSubmittingCommand = false
            self.cancelVoiceSession()
            return
        }

        guard !cleanQuery.isEmpty else {
            // User uttered wake word only ("Hey IRIS") -> respond with ready prompt and keep listening
            print("[VOICE_SESSION] User uttered wake word only, speaking greeting prompt")
            self.isSubmittingCommand = false
            speakResponse("What can I do for you?", isGreeting: true)
            return
        }

        self.state = .thinking(prompt: cleanQuery)
        self.dynamicIsland.updateSessionState(.thinking, audioLevel: 0.2)
        SpeechManager.shared.syncWithCoordinator(state: .processing, transcript: cleanQuery)

        print("[VOICE_SESSION] orchestrator_dispatched query: '\(cleanQuery)'")
        Task {
            let result = await orchestrator.process(userPrompt: cleanQuery)
            print("[VOICE_SESSION] orchestrator_completed with executedTools: \(result.executedTools), text: '\(result.textResponse)'")

            await MainActor.run {
                self.isSubmittingCommand = false
                self.latestResponse = result.textResponse
                SpeechManager.shared.syncWithCoordinator(state: .speaking, response: result.textResponse)
                self.speakResponse(result.textResponse, isGreeting: false)
            }
        }
    }

    public func handleSessionError(_ message: String) {
        cleanupAudioPipeline()
        responseManager.stopSpeaking()
        self.isSubmittingCommand = false
        self.errorMessage = message
        self.state = .failed(reason: message)
        self.dynamicIsland.updateSessionState(.failed, details: message)
        SpeechManager.shared.syncWithCoordinator(state: .idle)

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
        self.isSubmittingCommand = false
    }

    private func speakResponse(_ text: String, isGreeting: Bool) {
        self.state = .responding(text: text, audioLevel: 0.5)
        self.dynamicIsland.updateSessionState(.responding, audioLevel: 0.5)
        print("[VOICE_SESSION] voice_response_started: '\(text)'")
        responseManager.speak(text: text)
    }

    private func cleanupAudioPipeline() {
        audioManager.stopCapture()
        speechManager.stopRecognition()
    }

    nonisolated public static func stripWakeWords(_ text: String) -> String {
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
    nonisolated public func audioSessionManager(_ manager: AudioSessionManager, didUpdateAudioLevel level: Float) {
        Task { @MainActor in
            self.currentAudioLevel = level
            if case .listening(let transcript, _) = self.state {
                self.state = .listening(transcript: transcript, audioLevel: level)
                self.dynamicIsland.updateLiveActivity(statusText: "Listening...", isListening: true, audioLevel: level, transcript: transcript)
                SpeechManager.shared.syncWithCoordinator(state: .listening, audioLevel: level, transcript: transcript)
            }
        }
    }

    nonisolated public func audioSessionManagerDidReceiveInterruption(_ manager: AudioSessionManager) {
        Task { @MainActor in
            print("[VOICE_SESSION] Audio session received hardware interruption")
            self.cancelVoiceSession()
        }
    }

    nonisolated public func audioSessionManagerDidChangeRoute(_ manager: AudioSessionManager, toBluetooth: Bool) {
        print("[VOICE_SESSION] Audio route changed. toBluetooth: \(toBluetooth)")
    }
}

// MARK: - SpeechRecognitionManagerDelegate

extension VoiceSessionCoordinator: SpeechRecognitionManagerDelegate {
    nonisolated public func speechRecognitionManager(_ manager: SpeechRecognitionManager, didUpdatePartialTranscript transcript: String) {
        Task { @MainActor in
            self.activeTranscript = transcript
            if case .listening(_, let level) = self.state {
                self.state = .listening(transcript: transcript, audioLevel: level)
                self.dynamicIsland.updateLiveActivity(statusText: "Listening...", isListening: true, audioLevel: level, transcript: transcript)
                SpeechManager.shared.syncWithCoordinator(state: .listening, audioLevel: level, transcript: transcript)
            }
        }
    }

    nonisolated public func speechRecognitionManager(_ manager: SpeechRecognitionManager, didFinishWithFinalTranscript transcript: String) {
        Task { @MainActor in
            print("[VOICE_SESSION] Final transcript callback received: '\(transcript)'")
            self.activeTranscript = transcript
            self.stopVoiceSession(finalTranscript: transcript)
        }
    }

    nonisolated public func speechRecognitionManager(_ manager: SpeechRecognitionManager, didFailWithError error: Error) {
        let nsError = error as NSError
        if nsError.code == 203 || nsError.domain == "kAFAssistantErrorDomain" || nsError.domain == "kLSRErrorDomain" {
            // Ignore benign cancellation errors
            return
        }
        print("[VOICE_SESSION] Speech recognition error: \(error.localizedDescription)")
        Task { @MainActor in
            self.handleSessionError(error.localizedDescription)
        }
    }
}

// MARK: - VoiceResponseManagerDelegate

extension VoiceSessionCoordinator: VoiceResponseManagerDelegate {
    nonisolated public func voiceResponseManagerDidStartSpeaking(_ manager: VoiceResponseManager) {
        Task { @MainActor in
            self.dynamicIsland.updateSessionState(.responding, audioLevel: 0.6)
        }
    }

    nonisolated public func voiceResponseManagerDidFinishSpeaking(_ manager: VoiceResponseManager) {
        Task { @MainActor in
            print("[VOICE_SESSION] voice_response_finished. Summary: '\(self.latestResponse)'")
            self.state = .completed(summary: self.latestResponse)
            self.dynamicIsland.updateSessionState(.completedVerified, details: self.latestResponse)
            SpeechManager.shared.syncWithCoordinator(state: .idle)

            if self.isContinuousListeningEnabled {
                // Multi-turn continuous voice in Dynamic Island:
                // Allow audio hardware and echo cancellation to stabilize before re-opening mic
                try? await Task.sleep(nanoseconds: 500_000_000)
                if case .completed = self.state {
                    print("[VOICE_SESSION] Continuous listening enabled: resuming voice capture in Dynamic Island.")
                    self.activeTranscript = ""
                    self.isSubmittingCommand = false
                    await self.startVoiceSession()
                }
            } else {
                Task {
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    if case .completed = self.state {
                        print("[VOICE_SESSION] session_completed. Resetting to idle.")
                        self.state = .idle
                        self.dynamicIsland.endLiveActivity()
                    }
                }
            }
        }
    }

    nonisolated public func voiceResponseManagerDidCancelSpeaking(_ manager: VoiceResponseManager) {
        Task { @MainActor in
            print("[VOICE_SESSION] voice_response_cancelled")
            self.state = .idle
            self.dynamicIsland.endLiveActivity()
            SpeechManager.shared.syncWithCoordinator(state: .idle)
        }
    }
}
