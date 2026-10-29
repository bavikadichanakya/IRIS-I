//
//  SpeechManager.swift
//  IRIS-I
//
//  Complete on-device voice agent pipeline coordinating real-time Speech-To-Text (STT)
//  via SFSpeechRecognizer and natural Text-To-Speech (TTS) via AVSpeechSynthesizer.
//  Includes audio level metering for animated voice orbs and full barge-in support.
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

    private let synthesizer = AVSpeechSynthesizer()
    private var audioEngine = AVAudioEngine()
    #if canImport(Speech)
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    #endif

    private var silenceTimer: Timer?
    private let silenceThresholdSeconds: TimeInterval = 1.6

    public override init() {
        super.init()
        synthesizer.delegate = self
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
        // Barge-in: stop any active speech synthesis immediately
        if state == .speaking {
            stopSpeaking()
        }

        let hasPermission = await requestPermissions()
        guard hasPermission else { return }

        stopListeningInternal()
        self.recognizedText = ""
        self.errorMessage = nil

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

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false // Allows fastest neural on-device or hybrid recognition

        audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

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
                self?.audioLevel = normalized
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            self.state = .listening
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

                    // Reset auto-send silence timer
                    self.resetSilenceTimer()
                }

                if error != nil || result?.isFinal == true {
                    if self.state == .listening && !self.recognizedText.isEmpty {
                        self.stopListeningAndProcess()
                    } else if self.state == .listening {
                        self.stopListeningInternal()
                    }
                }
            }
        }
        #else
        self.state = .listening
        self.recognizedText = "(Simulated Speech Input)"
        #endif
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThresholdSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.state == .listening, !self.recognizedText.isEmpty else { return }
                self.stopListeningAndProcess()
            }
        }
    }

    public func stopListeningAndProcess(onCompletion: (@Sendable (String) async -> Void)? = nil) {
        silenceTimer?.invalidate()
        silenceTimer = nil

        let query = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        stopListeningInternal()

        guard !query.isEmpty else {
            self.state = .idle
            return
        }

        self.state = .processing

        Task {
            if let customHandler = onCompletion {
                await customHandler(query)
            } else {
                let orchestrator = ReActOrchestrator.shared
                let response = await orchestrator.process(userPrompt: query)
                await MainActor.run {
                    self.spokenResponse = response.textResponse
                    self.speak(text: response.textResponse)
                }
            }
        }
    }

    public func stopListeningInternal() {
        silenceTimer?.invalidate()
        silenceTimer = nil

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
    }

    // MARK: - Text To Speech (Speaking)

    public func speak(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.state = .idle
            return
        }

        // Clean any markdown formatting or tags for natural speech
        let cleaned = cleanTextForSpeech(text)

        stopSpeaking()

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // Use high-quality neural Siri / Samantha voice if available
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
            if self.state == .speaking {
                self.state = .idle
            }
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if self.state == .speaking {
                self.state = .idle
            }
        }
    }
}
