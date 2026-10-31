//
//  SpeechRecognitionManager.swift
//  IRIS-I
//
//  Dedicated SFSpeechRecognizer manager streaming audio buffers from
//  AudioSessionManager and emitting partial and final speech transcripts.
//

import Foundation
#if canImport(Speech)
import Speech
#endif
import AVFoundation

public protocol SpeechRecognitionManagerDelegate: AnyObject, Sendable {
    func speechRecognitionManager(_ manager: SpeechRecognitionManager, didUpdatePartialTranscript transcript: String)
    func speechRecognitionManager(_ manager: SpeechRecognitionManager, didFinishWithFinalTranscript transcript: String)
    func speechRecognitionManager(_ manager: SpeechRecognitionManager, didFailWithError error: Error)
}

public final class SpeechRecognitionManager: NSObject, @unchecked Sendable {
    public static let shared = SpeechRecognitionManager()

    public weak var delegate: SpeechRecognitionManagerDelegate?

    #if canImport(Speech)
    private var recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    #endif

    private var silenceTask: Task<Void, Never>?
    private let silenceDurationNanoseconds: UInt64 = 1_500_000_000 // 1.5s silence triggers auto-submission

    private override init() {
        super.init()
    }

    public func requestSpeechAuthorization() async -> Bool {
        #if canImport(Speech)
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        #else
        return true
        #endif
    }

    public var isSpeechAuthorized: Bool {
        #if canImport(Speech)
        SFSpeechRecognizer.authorizationStatus() == .authorized
        #else
        return true
        #endif
    }

    public var isAvailable: Bool {
        #if canImport(Speech)
        recognizer?.isAvailable ?? false
        #else
        return false
        #endif
    }

    /// Whether the current device and locale support strictly local on-device speech transcription.
    public var supportsOnDeviceRecognition: Bool {
        #if canImport(Speech)
        return recognizer?.supportsOnDeviceRecognition ?? false
        #else
        return false
        #endif
    }

    /// Enforces strictly local recognition without sending voice data to remote servers.
    public var isStrictOnDeviceRequired: Bool = true

    /// Validates that offline on-device speech recognition is available and supported.
    /// Throws an explicit error if unsupported or unavailable; never falls back to cloud.
    #if canImport(Speech)
    public func validateOfflineCapability(for recognizer: SFSpeechRecognizer? = nil, allowDefaultFallback: Bool = true) throws {
        let rec = allowDefaultFallback ? (recognizer ?? self.recognizer) : recognizer
        guard let rec = rec, rec.isAvailable else {
            throw NSError(
                domain: "IRIS.Speech",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is unavailable on this device."]
            )
        }

        guard rec.supportsOnDeviceRecognition else {
            throw NSError(
                domain: "IRIS.Speech",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "On-device speech recognition is not supported for locale '\(rec.locale.identifier)'. Cloud fallback is strictly prohibited to guarantee total on-device privacy."]
            )
        }
    }
    #else
    public func validateOfflineCapability(for recognizer: Any? = nil, allowDefaultFallback: Bool = true) throws {}
    #endif

    public func startRecognition() throws {
        #if canImport(Speech)
        stopRecognition()

        try validateOfflineCapability(for: self.recognizer)

        guard let recognizer = self.recognizer else {
            throw NSError(domain: "IRIS.Speech", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is unavailable."])
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        print("[SPEECH_REC] Strict on-device recognition enforced (100% offline).")
        self.recognitionRequest = request

        self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let error = error {
                    let nsError = error as NSError
                    if nsError.code != 203 && nsError.domain != "kAFAssistantErrorDomain" {
                        print("[SPEECH_REC] Recognition error: \(error.localizedDescription)")
                        self.delegate?.speechRecognitionManager(self, didFailWithError: error)
                    }
                    self.stopRecognition()
                    return
                }

                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    self.delegate?.speechRecognitionManager(self, didUpdatePartialTranscript: transcript)

                    if result.isFinal {
                        print("[SPEECH_REC] Final speech result received: '\(transcript)'")
                        self.delegate?.speechRecognitionManager(self, didFinishWithFinalTranscript: transcript)
                        self.stopRecognition()
                    } else {
                        // Reset silence timer on partial results
                        self.resetSilenceTimer(currentTranscript: transcript)
                    }
                }
            }
        }
        #endif
    }

    public func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        #if canImport(Speech)
        recognitionRequest?.append(buffer)
        #endif
    }

    private func resetSilenceTimer(currentTranscript: String) {
        silenceTask?.cancel()
        silenceTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: self.silenceDurationNanoseconds)
                guard !Task.isCancelled else { return }
                let trimmed = currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    print("[SPEECH_REC] Silence auto-endpoint reached (1.5s). Final transcript: '\(trimmed)'")
                    self.delegate?.speechRecognitionManager(self, didFinishWithFinalTranscript: trimmed)
                    self.stopRecognition()
                }
            } catch {}
        }
    }

    public func stopRecognition() {
        silenceTask?.cancel()
        silenceTask = nil

        #if canImport(Speech)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        #endif
    }
}
