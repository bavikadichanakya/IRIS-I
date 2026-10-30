//
//  VoiceResponseManager.swift
//  IRIS-I
//
//  Dedicated text-to-speech manager using AVSpeechSynthesizer.
//  Handles natural speech generation, markdown sanitization,
//  barge-in interruption, and completion delegate callbacks.
//

import Foundation
import AVFoundation

public protocol VoiceResponseManagerDelegate: AnyObject, Sendable {
    func voiceResponseManagerDidStartSpeaking(_ manager: VoiceResponseManager)
    func voiceResponseManagerDidFinishSpeaking(_ manager: VoiceResponseManager)
    func voiceResponseManagerDidCancelSpeaking(_ manager: VoiceResponseManager)
}

public final class VoiceResponseManager: NSObject, @unchecked Sendable {
    public static let shared = VoiceResponseManager()

    public weak var delegate: VoiceResponseManagerDelegate?

    private let synthesizer = AVSpeechSynthesizer()
    private var isCurrentlySpeaking: Bool = false

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    public var isSpeaking: Bool {
        isCurrentlySpeaking || synthesizer.isSpeaking
    }

    public func speak(text: String, voiceIdentifier: String? = nil) {
        stopSpeaking()

        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else {
            delegate?.voiceResponseManagerDidFinishSpeaking(self)
            return
        }

        let utterance = AVSpeechUtterance(string: cleaned)
        if let id = voiceIdentifier, let customVoice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = customVoice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isCurrentlySpeaking = true
        delegate?.voiceResponseManagerDidStartSpeaking(self)
        synthesizer.speak(utterance)
    }

    public func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isCurrentlySpeaking = false
    }

    private func cleanTextForSpeech(_ text: String) -> String {
        var clean = text
        // Remove code blocks
        clean = clean.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        // Remove inline code ticks
        clean = clean.replacingOccurrences(of: "`", with: "")
        // Remove markdown symbols
        clean = clean.replacingOccurrences(of: "#", with: "")
        clean = clean.replacingOccurrences(of: "*", with: "")
        clean = clean.replacingOccurrences(of: "_", with: "")
        // Remove tool tags
        clean = clean.replacingOccurrences(of: "<tool_call>[\\s\\S]*?</tool_call>", with: "", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceResponseManager: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isCurrentlySpeaking = false
            self.delegate?.voiceResponseManagerDidFinishSpeaking(self)
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isCurrentlySpeaking = false
            self.delegate?.voiceResponseManagerDidCancelSpeaking(self)
        }
    }
}
