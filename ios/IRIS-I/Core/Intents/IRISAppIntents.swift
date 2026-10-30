//
//  IRISAppIntents.swift
//  IRIS-I
//
//  System-level AppIntents and AppShortcuts integration enabling hands-free voice execution
//  from Siri, Action Button, Lock Screen widgets, and Control Center without needing
//  the main IRIS interface to be open.
//

import Foundation
import SwiftUI
import AppIntents

#if canImport(AppIntents)

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct AskIRISIntent: AppIntent {
    public static var title: LocalizedStringResource = "Ask IRIS"
    public static var description = IntentDescription("Wakes IRIS and begins listening for voice commands.")

    /// Brings app to foreground so iOS legitimately allows microphone audio capture
    public static var openAppWhenRun: Bool = true
    public static var isDiscoverable: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        #if canImport(ActivityKit)
        IRISDynamicIslandManager.shared.startLiveActivity()
        #endif
        await SpeechManager.shared.startListening()
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct AskIRISWithTextIntent: AppIntent {
    public static var title: LocalizedStringResource = "Ask IRIS with Text"
    public static var description = IntentDescription("Sends a typed text instruction to IRIS, or begins voice listening if empty.")

    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = true

    /// Default to empty string so iOS NEVER prompts with a modal 'Command' keyboard sheet
    @Parameter(title: "Command", default: "")
    public var command: String

    public init() {}

    public init(command: String) {
        self.command = command
    }

    public func perform() async throws -> some IntentResult {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            // Seamless zero-prompt fallback: start voice listening
            await MainActor.run {
                #if canImport(ActivityKit)
                IRISDynamicIslandManager.shared.startLiveActivity()
                #endif
            }
            await SpeechManager.shared.startListening()
            return .result()
        }

        let orchestrator = ReActOrchestrator.shared
        let response = await orchestrator.process(userPrompt: trimmed)
        await MainActor.run {
            #if canImport(ActivityKit)
            IRISDynamicIslandManager.shared.updateLiveActivity(statusText: "Responding...", isListening: false, audioLevel: 0.6)
            #endif
            SpeechManager.shared.speak(text: response.textResponse)
        }
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct OpenAppWithIRISIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open App with IRIS"
    public static var description = IntentDescription("Opens any verified application or settings screen using IRIS capability resolver.")

    /// Must open app when switching to another application
    public static var openAppWhenRun: Bool = true

    @Parameter(title: "App Name", description: "Name of the app to launch (e.g. Instagram, Spotify, YouTube)")
    public var appName: String

    public init() {}

    public init(appName: String) {
        self.appName = appName
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            _ = try await AppLaunchRegistry.shared.launchApp(name: appName)
            return .result(dialog: "Opening \(appName)...")
        } catch let err as AppLaunchError {
            return .result(dialog: IntentDialog(stringLiteral: err.localizedDescription))
        } catch {
            return .result(dialog: IntentDialog(stringLiteral: "Failed to open \(appName): \(error.localizedDescription)"))
        }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct StartIRISVoiceIntent: AppIntent {
    public static var title: LocalizedStringResource = "Wake IRIS Voice"
    public static var description = IntentDescription("Wakes IRIS and immediately begins listening for voice commands in the Dynamic Island.")
    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            #if canImport(ActivityKit)
            IRISDynamicIslandManager.shared.startLiveActivity()
            #endif
            Task {
                await SpeechManager.shared.startListening()
            }
        }
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct StartListeningIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Iris Voice Agent"
    public static var description = IntentDescription("Wakes IRIS and begins listening for voice commands.")

    public static var isDiscoverable: Bool = true
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        // 1. Trigger the Live Activity in Dynamic Island
        #if canImport(ActivityKit)
        IRISDynamicIslandManager.shared.startLiveActivity()
        #endif

        // 2. Start speech recognizer / AVAudioEngine listening sequence
        await SpeechManager.shared.startListening()

        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct IRISAppShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartListeningIntent(),
            phrases: [
                "Start \(.applicationName) Voice Agent",
                "Ask \(.applicationName)",
                "Hey \(.applicationName)",
                "Start \(.applicationName)",
                "\(.applicationName)"
            ],
            shortTitle: "Ask IRIS",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: AskIRISIntent(),
            phrases: [
                "Talk to \(.applicationName)",
                "Wake \(.applicationName)"
            ],
            shortTitle: "Wake IRIS",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: AskIRISWithTextIntent(),
            phrases: [
                "Tell \(.applicationName) to \(\.$command)",
                "Ask \(.applicationName) to \(\.$command)"
            ],
            shortTitle: "Ask IRIS Command",
            systemImageName: "sparkles"
        )
    }
}

#endif

