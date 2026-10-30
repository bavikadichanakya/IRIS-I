//
//  IRISAppIntents.swift
//  IRIS-I
//
//  System-level AppIntents and AppShortcuts integration enabling hands-free voice execution
//  from Siri, Action Button, Lock Screen widgets, and Control Center without needing
//  the main IRIS interface to be open.
//

import Foundation
import AppIntents

#if canImport(AppIntents)

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct AskIRISIntent: AppIntent {
    public static var title: LocalizedStringResource = "Ask IRIS"
    public static var description = IntentDescription("Executes natural-language voice or text commands with the on-device IRIS assistant engine.")

    /// Headless background execution: does not require bringing IRIS UI to the foreground for general queries
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Command", requestValueDialog: "What can IRIS do for you?")
    public var command: String

    public init() {}

    public init(command: String) {
        self.command = command
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "I didn't catch that. What would you like me to do?")
        }

        let orchestrator = ReActOrchestrator.shared
        let response = await orchestrator.process(userPrompt: trimmed)

        return .result(dialog: IntentDialog(stringLiteral: response.textResponse))
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
    public static var description = IntentDescription("Wakes IRIS and immediately begins listening for voice commands with the Pearl Orb interface.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            Task {
                await SpeechManager.shared.startListening()
            }
        }
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct IRISAppShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskIRISIntent(),
            phrases: [
                "\(.applicationName)",
                "Ask \(.applicationName)",
                "Tell \(.applicationName) to \(\.$command)",
                "\(.applicationName) \(\.$command)",
                "Ask \(.applicationName) to \(\.$command)"
            ],
            shortTitle: "Ask IRIS",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: StartIRISVoiceIntent(),
            phrases: [
                "Wake \(.applicationName)",
                "Open \(.applicationName) Voice"
            ],
            shortTitle: "Wake IRIS Voice",
            systemImageName: "mic.fill"
        )
    }
}

#endif

