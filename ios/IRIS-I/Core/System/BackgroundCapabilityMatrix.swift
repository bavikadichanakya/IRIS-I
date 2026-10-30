//
//  BackgroundCapabilityMatrix.swift
//  IRIS-I
//
//  Authoritative capability matrix governing iOS system execution states and sandboxing reality.
//  Separates foreground execution, active background audio, background suspension, lock screen, and terminated states.
//

import Foundation

public enum IOSExecutionState: String, CaseIterable, Sendable {
    case foregroundActive = "Foreground (Active)"
    case foregroundInactive = "Foreground (Inactive / Transitioning)"
    case backgroundActiveAudio = "Background (Active Audio Session)"
    case backgroundSuspended = "Background (Suspended)"
    case lockScreen = "Lock Screen"
    case terminated = "Terminated"
}

public enum CapabilitySupportLevel: String, Sendable {
    case fullySupported = "Supported (Unrestricted)"
    case supportedWithRestrictions = "Supported (Restricted / Time-Bounded)"
    case requiresForegroundHandoff = "Requires Foreground Handoff"
    case unsupported = "Unsupported by iOS Sandbox"
}

public struct StateCapabilityProfile: Sendable {
    public let state: IOSExecutionState
    public let liveActivityUpdates: CapabilitySupportLevel
    public let appIntentExecution: CapabilitySupportLevel
    public let backgroundAudioPlayback: CapabilitySupportLevel
    public let microphoneCapture: CapabilitySupportLevel
    public let localModelInference: CapabilitySupportLevel
    public let wakeWordDetection: CapabilitySupportLevel
    public let shortcutsExecution: CapabilitySupportLevel
    public let documentation: String

    public init(
        state: IOSExecutionState,
        liveActivityUpdates: CapabilitySupportLevel,
        appIntentExecution: CapabilitySupportLevel,
        backgroundAudioPlayback: CapabilitySupportLevel,
        microphoneCapture: CapabilitySupportLevel,
        localModelInference: CapabilitySupportLevel,
        wakeWordDetection: CapabilitySupportLevel,
        shortcutsExecution: CapabilitySupportLevel,
        documentation: String
    ) {
        self.state = state
        self.liveActivityUpdates = liveActivityUpdates
        self.appIntentExecution = appIntentExecution
        self.backgroundAudioPlayback = backgroundAudioPlayback
        self.microphoneCapture = microphoneCapture
        self.localModelInference = localModelInference
        self.wakeWordDetection = wakeWordDetection
        self.shortcutsExecution = shortcutsExecution
        self.documentation = documentation
    }
}

public struct BackgroundCapabilityMatrix: Sendable {
    public static let shared = BackgroundCapabilityMatrix()

    public let profiles: [IOSExecutionState: StateCapabilityProfile]

    public init() {
        var map: [IOSExecutionState: StateCapabilityProfile] = [:]

        // 1. Foreground Active
        map[.foregroundActive] = StateCapabilityProfile(
            state: .foregroundActive,
            liveActivityUpdates: .fullySupported,
            appIntentExecution: .fullySupported,
            backgroundAudioPlayback: .fullySupported,
            microphoneCapture: .fullySupported,
            localModelInference: .fullySupported,
            wakeWordDetection: .fullySupported,
            shortcutsExecution: .fullySupported,
            documentation: "Full access to A19 Metal GPU, neural engine, audio session input/output, and unrestricted system APIs."
        )

        // 2. Foreground Inactive
        map[.foregroundInactive] = StateCapabilityProfile(
            state: .foregroundInactive,
            liveActivityUpdates: .fullySupported,
            appIntentExecution: .fullySupported,
            backgroundAudioPlayback: .fullySupported,
            microphoneCapture: .supportedWithRestrictions,
            localModelInference: .supportedWithRestrictions,
            wakeWordDetection: .supportedWithRestrictions,
            shortcutsExecution: .fullySupported,
            documentation: "App is transitioning (e.g. Control Center down, Siri active). Audio session remains attached but input may pause."
        )

        // 3. Background Active Audio
        map[.backgroundActiveAudio] = StateCapabilityProfile(
            state: .backgroundActiveAudio,
            liveActivityUpdates: .fullySupported,
            appIntentExecution: .supportedWithRestrictions,
            backgroundAudioPlayback: .fullySupported,
            microphoneCapture: .supportedWithRestrictions,
            localModelInference: .supportedWithRestrictions,
            wakeWordDetection: .supportedWithRestrictions,
            shortcutsExecution: .fullySupported,
            documentation: "Audio session initiated in foreground with UIBackgroundModes 'audio'. Background recording continues while actively capturing. Metal compute throttled by thermal budget."
        )

        // 4. Background Suspended
        map[.backgroundSuspended] = StateCapabilityProfile(
            state: .backgroundSuspended,
            liveActivityUpdates: .supportedWithRestrictions,
            appIntentExecution: .supportedWithRestrictions,
            backgroundAudioPlayback: .unsupported,
            microphoneCapture: .requiresForegroundHandoff,
            localModelInference: .unsupported,
            wakeWordDetection: .requiresForegroundHandoff,
            shortcutsExecution: .supportedWithRestrictions,
            documentation: "Process suspended in RAM. iOS denies starting new AVAudioEngine recording taps from suspended background. App Intents run out-of-process or wake briefly."
        )

        // 5. Lock Screen
        map[.lockScreen] = StateCapabilityProfile(
            state: .lockScreen,
            liveActivityUpdates: .fullySupported,
            appIntentExecution: .supportedWithRestrictions,
            backgroundAudioPlayback: .fullySupported,
            microphoneCapture: .requiresForegroundHandoff,
            localModelInference: .supportedWithRestrictions,
            wakeWordDetection: .supportedWithRestrictions,
            shortcutsExecution: .supportedWithRestrictions,
            documentation: "Dynamic Island and Lock Screen Live Activities display real-time updates. Action Button wakes AppIntent; mic capture starts upon unlock or foreground activation."
        )

        // 6. Terminated
        map[.terminated] = StateCapabilityProfile(
            state: .terminated,
            liveActivityUpdates: .unsupported,
            appIntentExecution: .supportedWithRestrictions,
            backgroundAudioPlayback: .unsupported,
            microphoneCapture: .requiresForegroundHandoff,
            localModelInference: .unsupported,
            wakeWordDetection: .requiresForegroundHandoff,
            shortcutsExecution: .supportedWithRestrictions,
            documentation: "Process is not running. App Intents and Action Button relaunch app or launch extension without in-memory state."
        )

        self.profiles = map
    }

    public func profile(for state: IOSExecutionState) -> StateCapabilityProfile {
        return profiles[state] ?? profiles[.terminated]!
    }

    /// Verifies whether microphone capture can legitimately begin in the given state
    public func canInitiateMicrophone(in state: IOSExecutionState) -> Bool {
        switch state {
        case .foregroundActive:
            return true
        case .foregroundInactive, .backgroundActiveAudio:
            return true
        case .backgroundSuspended, .lockScreen, .terminated:
            return false
        }
    }
}

