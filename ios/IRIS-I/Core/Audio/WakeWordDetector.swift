//
//  WakeWordDetector.swift
//  IRIS-I
//
//  On-device acoustic wake-word detector processing 16kHz frames for "Hey IRIS" and "IRIS".
//  Features acoustic energy envelope analysis, sibilant zero-crossing rate detection,
//  sensitivity calibration, and strict iOS background execution diagnostics.
//

import Foundation
import Combine
import AVFoundation

public enum WakeWordPhrase: String, CaseIterable, Sendable {
    case heyIris = "Hey IRIS"
    case iris = "IRIS"
}

public enum WakeWordSensitivity: Int, CaseIterable, Sendable {
    case low = 0
    case standard = 1
    case high = 2

    public var title: String {
        switch self {
        case .low: return "Low"
        case .standard: return "Standard"
        case .high: return "High"
        }
    }

    public var detectionThreshold: Float {
        switch self {
        case .low: return 0.82
        case .standard: return 0.70
        case .high: return 0.58
        }
    }

    public var minRMSFloor: Float {
        switch self {
        case .low: return 0.04
        case .standard: return 0.025
        case .high: return 0.015
        }
    }
}

/// Authoritative diagnostic representation of iOS background wake-word execution capabilities
public enum iOSBackgroundWakeWordState: String, Sendable {
    case foregroundActive = "Active (Foreground)"
    case backgroundActiveSession = "Active (Background Audio Session)"
    case backgroundSuspended = "Suspended by iOS"
    case deviceLocked = "Restricted (Device Locked)"
    case terminated = "Inactive (App Terminated)"

    public var isCapableOfAcousticDetection: Bool {
        switch self {
        case .foregroundActive, .backgroundActiveSession:
            return true
        case .backgroundSuspended, .deviceLocked, .terminated:
            return false
        }
    }

    public var explanation: String {
        switch self {
        case .foregroundActive:
            return "Microphone is actively capturing frames; wake-word engine running continuously."
        case .backgroundActiveSession:
            return "App maintains an active AVAudioSession with background audio mode. Detection runs while audio is streaming."
        case .backgroundSuspended:
            return "iOS suspends microphone capture in the background when no active audio pipeline is streaming to preserve battery. Use Action Button or Siri for instant activation."
        case .deviceLocked:
            return "Microphone recording while locked requires active background audio session. Use Action Button or Siri Shortcut for guaranteed invocation."
        case .terminated:
            return "The app is not running. Launch via Action Button or Siri."
        }
    }
}

public protocol WakeWordDetectorDelegate: AnyObject, Sendable {
    func wakeWordDetector(_ detector: WakeWordDetector, didDetectPhrase phrase: String, confidence: Float)
}

@MainActor
public final class WakeWordDetector: ObservableObject, AudioFrameProcessorDelegate, @unchecked Sendable {
    public static let shared = WakeWordDetector()

    public weak var delegate: WakeWordDetectorDelegate?

    @Published public var isListening: Bool = false
    @Published public var selectedPhrase: WakeWordPhrase = .heyIris {
        didSet {
            UserDefaults.standard.set(selectedPhrase.rawValue, forKey: "iris_wake_phrase")
        }
    }
    @Published public var sensitivity: WakeWordSensitivity = .standard {
        didSet {
            UserDefaults.standard.set(sensitivity.rawValue, forKey: "iris_wake_sensitivity")
        }
    }
    @Published public var liveRMS: Float = 0.0
    @Published public var lastConfidenceScore: Float = 0.0
    @Published public var detectionCount: Int = 0
    @Published public var lastDetectedAt: Date? = nil
    @Published public private(set) var backgroundExecutionState: iOSBackgroundWakeWordState = .foregroundActive

    // Acoustic temporal buffer (1.2 seconds of frames = ~38 frames of 512 samples with 256 hop at 16kHz)
    private struct FrameSample {
        let rms: Float
        let zcr: Float
        let timestamp: Date
    }

    private var recentFrames: [FrameSample] = []
    private let maxHistoryFrames: Int = 40
    private var lastTriggerTime: Date = Date.distantPast
    private let refractoryPeriodSeconds: TimeInterval = 2.0 // Prevent double-triggering

    private init() {
        if let savedPhrase = UserDefaults.standard.string(forKey: "iris_wake_phrase"),
           let phrase = WakeWordPhrase(rawValue: savedPhrase) {
            self.selectedPhrase = phrase
        }
        let savedSens = UserDefaults.standard.integer(forKey: "iris_wake_sensitivity")
        if let sens = WakeWordSensitivity(rawValue: savedSens) {
            self.sensitivity = sens
        }

        AudioFrameProcessor.shared.delegate = self
        setupAppLifecycleObservers()
    }

    // MARK: - App Lifecycle & Background Monitoring

    private func setupAppLifecycleObservers() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.backgroundExecutionState = .foregroundActive
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let isBgAudioActive = AVAudioSession.sharedInstance().isOtherAudioPlaying == false
            self?.backgroundExecutionState = isBgAudioActive ? .backgroundActiveSession : .backgroundSuspended
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.backgroundExecutionState == .foregroundActive {
                self?.backgroundExecutionState = .backgroundActiveSession
            }
        }
        #endif
    }

    // MARK: - Listening Control

    public func startListening() {
        guard !isListening else { return }
        isListening = true
        recentFrames.removeAll()
        print("[WAKE_WORD] Started acoustic wake word listener (Phrase: \(selectedPhrase.rawValue), Sensitivity: \(sensitivity.title))")
    }

    public func stopListening() {
        isListening = false
        recentFrames.removeAll()
        liveRMS = 0.0
        print("[WAKE_WORD] Stopped acoustic wake word listener.")
    }

    // MARK: - AudioFrameProcessorDelegate

    public nonisolated func audioFrameProcessor(
        _ processor: AudioFrameProcessor,
        didProduceFrame frame: [Float],
        rms: Float,
        zcr: Float
    ) {
        Task { @MainActor in
            guard self.isListening else { return }

            self.liveRMS = min(1.0, rms * 10.0)

            let sample = FrameSample(rms: rms, zcr: zcr, timestamp: Date())
            self.recentFrames.append(sample)
            if self.recentFrames.count > self.maxHistoryFrames {
                self.recentFrames.removeFirst()
            }

            self.evaluateAcousticTemporalPattern()
        }
    }

    // MARK: - Acoustic Pattern Analysis

    private func evaluateAcousticTemporalPattern() {
        guard recentFrames.count >= 20 else { return }

        // Enforce refractory cooldown
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) > refractoryPeriodSeconds else { return }

        // Must meet minimum RMS floor for sensitivity
        let currentWindow = Array(recentFrames.suffix(28))
        let peakRMS = currentWindow.map(\.rms).max() ?? 0.0
        guard peakRMS >= sensitivity.minRMSFloor else { return }

        let score = calculatePatternScore(window: currentWindow, for: selectedPhrase)
        self.lastConfidenceScore = score

        if score >= sensitivity.detectionThreshold {
            print("[WAKE_WORD] Wake word detected: '\(selectedPhrase.rawValue)' (Score: \(String(format: "%.2f", score)) >= Threshold: \(sensitivity.detectionThreshold))")
            self.lastTriggerTime = now
            self.lastDetectedAt = now
            self.detectionCount += 1

            // Notify delegate and trigger voice session coordinator
            delegate?.wakeWordDetector(self, didDetectPhrase: selectedPhrase.rawValue, confidence: score)
            VoiceSessionCoordinator.shared.wakeWordDetected(phrase: selectedPhrase.rawValue)
        }
    }

    /// Evaluates phoneme acoustic profile:
    /// 1. Vowel energy onset (high RMS, low-moderate ZCR < 0.25)
    /// 2. Intermediate liquid transition /r/ (energy reduction)
    /// 3. Terminal sibilant /s/ (high ZCR > 0.38, moderate RMS)
    private func calculatePatternScore(window: [FrameSample], for phrase: WakeWordPhrase) -> Float {
        let count = window.count
        guard count >= 16 else { return 0.0 }

        // Split into onset (40%), transition (30%), and coda/sibilant (30%)
        let onsetEnd = Int(Double(count) * 0.40)
        let transEnd = Int(Double(count) * 0.70)

        let onset = Array(window[0..<onsetEnd])
        let transition = Array(window[onsetEnd..<transEnd])
        let coda = Array(window[transEnd..<count])

        let onsetMeanRMS = onset.map(\.rms).reduce(0, +) / Float(max(1, onset.count))
        let codaMeanZCR = coda.map(\.zcr).reduce(0, +) / Float(max(1, coda.count))
        let transMeanRMS = transition.map(\.rms).reduce(0, +) / Float(max(1, transition.count))

        var score: Float = 0.0

        // 1. Initial vowel burst check
        if onsetMeanRMS > sensitivity.minRMSFloor * 1.5 {
            score += 0.35
        } else if onsetMeanRMS > sensitivity.minRMSFloor {
            score += 0.20
        }

        // 2. Terminal sibilant fricative (/s/) high-frequency zero-crossing check
        if codaMeanZCR > 0.38 {
            score += 0.40
        } else if codaMeanZCR > 0.28 {
            score += 0.25
        }

        // 3. Dynamic contrast: coda should have higher ZCR than onset
        let onsetMeanZCR = onset.map(\.zcr).reduce(0, +) / Float(max(1, onset.count))
        if codaMeanZCR > onsetMeanZCR * 1.4 {
            score += 0.15
        }

        // 4. Acoustic dip during liquid /r/ transition
        if transMeanRMS <= onsetMeanRMS * 1.1 {
            score += 0.10
        }

        return min(1.0, max(0.0, score))
    }
}
