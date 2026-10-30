//
//  SpeechManager.swift
//  IRIS-I
//
//  Complete on-device voice agent pipeline coordinating real-time Speech-To-Text (STT)
//  via SFSpeechRecognizer and natural Text-To-Speech (TTS) via AVSpeechSynthesizer.
//  Includes wake-word handling ("Hey IRIS"), audio level metering for animated voice orbs,
//  and full barge-in interruption support.
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

    private let synthesizer = AVSpeechSynthesizer()
    private var audioEngine = AVAudioEngine()
    #if canImport(Speech)
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    #endif

    private var silenceTask: Task<Void, Never>?
    private let silenceThresholdNanoseconds: UInt64 = 1_600_000_000 // 1.6 seconds of silence auto-submits

    public override init() {
        self.isBackgroundWakeWordEnabled = UserDefaults.standard.bool(forKey: "iris_background_wake_word_enabled")
        super.init()
        synthesizer.delegate = self
        setupLifecycleObservers()
    }

    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            if type == .began {
                self.stopListeningInternal()
                self.stopSpeaking()
            }
        }
    }

    // MARK: - Permissions

    public func requestPermissions() async -> Bool {
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micGranted else {
            self.errorMessage = "Microphone access is required for voice interaction."
            return false
        }

        #if canImport(Speech)
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else {
            self.errorMessage = "Speech Recognition authorization is required for voice commands."
            return false
        }
        #endif

        return true
    }

    // MARK: - Speech To Text (Listening)

    public func startListening() async {
        // Barge-in: immediately cut off any active speech synthesis
        if state == .speaking {
            stopSpeaking()
        }

        let hasPermission = await requestPermissions()
        guard hasPermission else { return }

        stopListeningInternal()
        self.recognizedText = ""
        self.errorMessage = nil
        self.wakeWordDetected = false

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.errorMessage = "Failed to configure audio session: \(error.localizedDescription)"
            return
        }

        #if canImport(Speech)
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            self.errorMessage = "Speech recognizer is not currently available."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false // Fast neural hybrid or on-device
        self.recognitionRequest = request

        audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Capture local reference to avoid actor isolation crossings inside the audio thread tap
        let activeRequest = request

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            activeRequest.append(buffer)

            // Calculate RMS audio level for waveform visualization (0.0 to 1.0)
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = UInt(buffer.frameLength)
            var sum: Float = 0.0
            for i in 0..<Int(frameLength) {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / max(1.0, Float(frameLength)))
            let normalized = min(1.0, max(0.0, rms * 10.0))

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.audioLevel = normalized
                IRISDynamicIslandManager.shared.updateLiveActivity(statusText: "Listening...", isListening: true, audioLevel: normalized)
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            self.state = .listening
            IRISDynamicIslandManager.shared.startLiveActivity()
        } catch {
            self.errorMessage = "Audio engine could not start: \(error.localizedDescription)"
            stopListeningInternal()
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let result = result {
                    let transcribed = result.bestTranscription.formattedString
                    self.recognizedText = transcribed

                    let cleanLower = transcribed.lowercased()
                        .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))

                    if cleanLower.contains("hey iris") || cleanLower.contains("iris") {
                        self.wakeWordDetected = true
                        // If user specifically said "Hey IRIS" (or "IRIS") alone, trigger greeting immediately without waiting
                        if cleanLower == "hey iris" || cleanLower == "iris" {
                            self.silenceTask?.cancel()
                            self.silenceTask = nil
                            self.processVoiceQuery()
                            return
                        }
                    }

                    // Reset auto-send silence timer for voice commands
                    self.resetSilenceTimer()
                }

                if error != nil || result?.isFinal == true {
                    if self.state == .listening && !self.recognizedText.isEmpty {
                        self.processVoiceQuery()
                    } else if self.state == .listening {
                        self.stopListeningInternal()
                        // Automatically restart listener so wake word is continuously ready
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            if self.state == .idle {
                                await self.startListening()
                            }
                        }
                    }
                }
            }
        }
        #else
        self.state = .listening
        self.recognizedText = "Hey IRIS, what time is it?"
        self.wakeWordDetected = true
        #endif
    }

    private func resetSilenceTimer() {
        silenceTask?.cancel()
        silenceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: self.silenceThresholdNanoseconds)
            guard !Task.isCancelled, self.state == .listening, !self.recognizedText.isEmpty else { return }
            self.processVoiceQuery()
        }
    }

    /// Stops listening and immediately returns the current transcribed text.
    @discardableResult
    public func stopListening() -> String {
        silenceTask?.cancel()
        silenceTask = nil
        let text = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        stopListeningInternal()
        return text
    }

    /// Stops listening and triggers end-to-end voice query processing and vocalization.
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

    /// Processes recognized text with wake-word detection, stripping prefixes, and vocalizing responses.
    public func processVoiceQuery(rawText: String? = nil) {
        let input = (rawText ?? self.recognizedText).trimmingCharacters(in: .whitespacesAndNewlines)
        stopListeningInternal()

        guard !input.isEmpty else {
            self.state = .idle
            return
        }

        // Detect and strip wake-word prefixes cleanly, accounting for speech recognition punctuation
        let lower = input.lowercased()
        var clean = lower.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        for wakeVariant in ["hey iris", "hey, iris", "iris"] {
            if clean.hasPrefix(wakeVariant) {
                var remaining = clean.dropFirst(wakeVariant.count)
                while let first = remaining.first, first == "," || first == "." || first == " " || first == ":" || first == "!" || first == "?" {
                    remaining = remaining.dropFirst()
                }
                clean = String(remaining)
                break
            }
        }
        let query = clean.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))

        // If user only uttered the wake word, respond with greeting and immediately listen for follow-up command
        if query.isEmpty {
            self.state = .speaking
            self.spokenResponse = "What can I do for you?"
            self.isAwaitingFollowUp = true
            IRISDynamicIslandManager.shared.updateLiveActivity(statusText: "What can I do for you?", isListening: false, audioLevel: 0.5)
            speak(text: self.spokenResponse)
            return
        }

        self.state = .processing
        IRISDynamicIslandManager.shared.updateLiveActivity(statusText: "Thinking...", isListening: false, audioLevel: 0.3)
        Task {
            let orchestrator = ReActOrchestrator.shared
            let response = await orchestrator.process(userPrompt: query)
            await MainActor.run {
                self.spokenResponse = response.textResponse
                IRISDynamicIslandManager.shared.updateLiveActivity(statusText: "Responding...", isListening: false, audioLevel: 0.6)
                self.speak(text: response.textResponse)
            }
        }
    }

    public func stopListeningInternal() {
        silenceTask?.cancel()
        silenceTask = nil

        #if canImport(Speech)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        #endif

        self.audioLevel = 0.0
        if state == .listening {
            self.state = .idle
        }
        if !isAwaitingFollowUp && state != .speaking && state != .processing {
            IRISDynamicIslandManager.shared.endLiveActivity()
        }
    }

    // MARK: - Text To Speech (Speaking)

    public func speak(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.state = .idle
            return
        }

        // Clean markdown, tags, and formatting for natural spoken cadence
        let cleaned = cleanTextForSpeech(text)

        stopSpeaking()

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.04
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        if let preferredVoice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = preferredVoice
        }

        self.spokenResponse = cleaned
        self.state = .speaking
        synthesizer.speak(utterance)
    }

    public func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if state == .speaking {
            self.state = .idle
        }
    }

    private func cleanTextForSpeech(_ text: String) -> String {
        var clean = text
        // Strip code blocks
        clean = clean.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        // Strip inline backticks
        clean = clean.replacingOccurrences(of: "`", with: "")
        // Strip markdown headers and bold/italic asterisks
        clean = clean.replacingOccurrences(of: "#", with: "")
        clean = clean.replacingOccurrences(of: "*", with: "")
        // Strip tool call tags
        clean = clean.replacingOccurrences(of: "<tool_call>[\\s\\S]*?</tool_call>", with: "", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if self.isAwaitingFollowUp {
                self.isAwaitingFollowUp = false
                self.state = .idle
                await self.startListening()
            } else if self.state == .speaking {
                self.state = .idle
                IRISDynamicIslandManager.shared.endLiveActivity()
            }
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if self.state == .speaking {
                self.state = .idle
                IRISDynamicIslandManager.shared.endLiveActivity()
            }
        }
    }
}
