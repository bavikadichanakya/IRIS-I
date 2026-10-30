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
    public static var description = IntentDescription("Executes natural-language voice commands via Dynamic Island Live Activity.")

    /// Runs directly in the Dynamic Island without opening the full app window
    public static var openAppWhenRun: Bool = false
    public static var isDiscoverable: Bool = true

    @Parameter(title: "Command", default: nil)
    public var command: String?

    public init() {}

    public init(command: String?) {
        self.command = command
    }

    public func perform() async throws -> some IntentResult {
        if let query = command?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            let orchestrator = ReActOrchestrator.shared
            let response = await orchestrator.process(userPrompt: query)
            await MainActor.run {
                #if canImport(ActivityKit)
                IRISDynamicIslandManager.shared.updateLiveActivity(statusText: "Responding...", isListening: false, audioLevel: 0.6)
                #endif
                SpeechManager.shared.speak(text: response.textResponse)
            }
            return .result()
        } else {
            // Instant 1-press trigger from Action Button: start real Dynamic Island Live Activity
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
    public static var description = IntentDescription("Wakes IRIS and immediately begins listening for voice commands in the Dynamic Island.")

    public static var isDiscoverable: Bool = true
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        // 1. Trigger the Live Activity in Dynamic Island
        #if canImport(ActivityKit)
        IRISDynamicIslandManager.shared.startLiveActivity()
        #endif

        // 2. Start speech recognizer / AVAudioEngine listening sequence
        Task {
            await SpeechManager.shared.startListening()
        }

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
                "Start \(.applicationName)"
            ],
            shortTitle: "Ask IRIS",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: AskIRISIntent(),
            phrases: [
                "Tell \(.applicationName) to \(\.$command)",
                "\(.applicationName) \(\.$command)",
                "Ask \(.applicationName) to \(\.$command)"
            ],
            shortTitle: "Ask IRIS Command",
            systemImageName: "sparkles"
        )
    }
}

#endif

