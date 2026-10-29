//
//  AppLaunchRegistry.swift
//  IRIS-I
//
//  Verified registry of documented iOS URL schemes and public app launchers.
//  Strictly rejects private schemes (such as App-Prefs:root=) and arbitrary in-app UI manipulation.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct AppLaunchDescriptor: Sendable {
    public let appName: String
    public let urlScheme: String
    public let queryScheme: String?
    public let appStoreURL: URL?
    public let description: String

    public init(
        appName: String,
        urlScheme: String,
        queryScheme: String? = nil,
        appStoreURL: URL? = nil,
        description: String
    ) {
        self.appName = appName
        self.urlScheme = urlScheme
        self.queryScheme = queryScheme
        self.appStoreURL = appStoreURL
        self.description = description
    }
}

public enum AppLaunchError: LocalizedError, Sendable {
    case unregisteredScheme(String)
    case appNotInstalled(appName: String, appStoreURL: URL?)
    case unsupportedInAppAction(String)
    case systemLaunchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unregisteredScheme(let s):
            return "The scheme '\(s)' is not registered or is prohibited on iOS."
        case .appNotInstalled(let name, _):
            return "\(name) does not appear to be installed on this device."
        case .unsupportedInAppAction(let act):
            return "Cannot perform '\(act)' inside third-party app. Stock iOS sandboxing does not support cross-app UI automation."
        case .systemLaunchFailed(let s):
            return "The system failed to dispatch URL '\(s)'."
        }
    }
}

public actor AppLaunchRegistry {
    public static let shared = AppLaunchRegistry()

    private var registry: [String: AppLaunchDescriptor] = [:]

    public init() {
        registerDefaultApps()
    }

    private func registerDefaultApps() {
        // Documented public schemes
        register(AppLaunchDescriptor(
            appName: "Maps",
            urlScheme: "maps:",
            queryScheme: "maps",
            description: "Apple Maps directions and locations"
        ))
        register(AppLaunchDescriptor(
            appName: "Messages",
            urlScheme: "sms:",
            queryScheme: "sms",
            description: "iOS Messages app composer"
        ))
        register(AppLaunchDescriptor(
            appName: "Phone",
            urlScheme: "tel:",
            queryScheme: "tel",
            description: "Phone dialer"
        ))
        register(AppLaunchDescriptor(
            appName: "Mail",
            urlScheme: "mailto:",
            queryScheme: "mailto",
            description: "Default email client composer"
        ))
        register(AppLaunchDescriptor(
            appName: "Shortcuts",
            urlScheme: "shortcuts://run-shortcut?name=",
            queryScheme: "shortcuts",
            description: "Apple Shortcuts execution"
        ))
        register(AppLaunchDescriptor(
            appName: "Spotify",
            urlScheme: "spotify:",
            queryScheme: "spotify",
            appStoreURL: URL(string: "https://apps.apple.com/app/spotify/id324684580"),
            description: "Spotify music streaming"
        ))
        register(AppLaunchDescriptor(
            appName: "YouTube",
            urlScheme: "youtube:",
            queryScheme: "youtube",
            appStoreURL: URL(string: "https://apps.apple.com/app/youtube/id544007664"),
            description: "YouTube video player"
        ))
        register(AppLaunchDescriptor(
            appName: "Music",
            urlScheme: "music:",
            queryScheme: "music",
            appStoreURL: URL(string: "https://apps.apple.com/app/apple-music/id1108187390"),
            description: "Apple Music player and streaming"
        ))
        register(AppLaunchDescriptor(
            appName: "Apple Music",
            urlScheme: "music:",
            queryScheme: "music",
            appStoreURL: URL(string: "https://apps.apple.com/app/apple-music/id1108187390"),
            description: "Apple Music player and streaming"
        ))
        register(AppLaunchDescriptor(
            appName: "Photos",
            urlScheme: "photos-redirect:",
            queryScheme: "photos-redirect",
            description: "Apple Photos library"
        ))
        register(AppLaunchDescriptor(
            appName: "Camera",
            urlScheme: "camera:",
            queryScheme: "camera",
            description: "Camera capture app"
        ))
        register(AppLaunchDescriptor(
            appName: "Notes",
            urlScheme: "mobilenotes:",
            queryScheme: "mobilenotes",
            description: "Apple Notes"
        ))
        register(AppLaunchDescriptor(
            appName: "Calendar",
            urlScheme: "calshow:",
            queryScheme: "calshow",
            description: "iOS Calendar"
        ))
        register(AppLaunchDescriptor(
            appName: "Reminders",
            urlScheme: "x-apple-reminderkit:",
            queryScheme: "x-apple-reminderkit",
            description: "Apple Reminders"
        ))
        register(AppLaunchDescriptor(
            appName: "WhatsApp",
            urlScheme: "whatsapp:",
            queryScheme: "whatsapp",
            appStoreURL: URL(string: "https://apps.apple.com/app/whatsapp-messenger/id310633997"),
            description: "WhatsApp Messenger"
        ))
        register(AppLaunchDescriptor(
            appName: "Telegram",
            urlScheme: "tg:",
            queryScheme: "tg",
            appStoreURL: URL(string: "https://apps.apple.com/app/telegram-messenger/id686449807"),
            description: "Telegram Messenger"
        ))
        register(AppLaunchDescriptor(
            appName: "FaceTime",
            urlScheme: "facetime:",
            queryScheme: "facetime",
            description: "Apple FaceTime video calls"
        ))
        register(AppLaunchDescriptor(
            appName: "Files",
            urlScheme: "shareddocuments:",
            queryScheme: "shareddocuments",
            description: "Apple Files document manager"
        ))
        register(AppLaunchDescriptor(
            appName: "ChatGPT",
            urlScheme: "chatgpt:",
            queryScheme: "chatgpt",
            appStoreURL: URL(string: "https://apps.apple.com/app/chatgpt/id6448311069"),
            description: "OpenAI ChatGPT app"
        ))
        register(AppLaunchDescriptor(
            appName: "Twitter",
            urlScheme: "twitter:",
            queryScheme: "twitter",
            description: "X / Twitter"
        ))
    }

    public func register(_ descriptor: AppLaunchDescriptor) {
        let key = descriptor.appName.lowercased()
        registry[key] = descriptor
        let noSpace = key.replacingOccurrences(of: " ", with: "")
        if noSpace != key {
            registry[noSpace] = descriptor
        }
    }

    public func descriptor(for appName: String) -> AppLaunchDescriptor? {
        let key = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = registry[key] { return d }
        let stripped = key.replacingOccurrences(of: "apple ", with: "")
        if let d = registry[stripped] { return d }
        let noSpace = key.replacingOccurrences(of: " ", with: "")
        if let d = registry[noSpace] { return d }
        if key == "x" { return registry["twitter"] }
        return nil
    }

    /// Preflights and launches an app via verified URL scheme.
    /// Runs on the MainActor for UIKit interaction.
    @MainActor
    public func launchApp(name: String, parameter: String? = nil) async throws -> URL {
        let lowName = name.lowercased().trimmingCharacters(in: .whitespaces)

        // 1. Special Case: iOS System Settings via official public API
        if lowName == "settings" || lowName == "app settings" {
            #if canImport(UIKit)
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                throw AppLaunchError.systemLaunchFailed("Invalid settings URL")
            }
            let success = await UIApplication.shared.open(settingsURL)
            if success {
                return settingsURL
            } else {
                throw AppLaunchError.systemLaunchFailed(UIApplication.openSettingsURLString)
            }
            #else
            throw AppLaunchError.systemLaunchFailed("UIKit unavailable on this platform")
            #endif
        }

        // 2. Reject private schemes like App-Prefs:
        if lowName.contains("prefs:") || parameter?.lowercased().contains("prefs:") == true {
            throw AppLaunchError.unregisteredScheme("App-Prefs is a private API and cannot be used.")
        }

        // 3. Find registered descriptor
        guard let descriptor = await descriptor(for: lowName) else {
            throw AppLaunchError.unregisteredScheme(name)
        }

        // 4. Construct URL
        var targetString = descriptor.urlScheme
        if let param = parameter, !param.isEmpty {
            if targetString.hasSuffix("=") {
                let encoded = param.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? param
                targetString += encoded
            } else if targetString.hasSuffix(":") {
                let encoded = param.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? param
                targetString += encoded
            } else {
                let encoded = param.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? param
                targetString += (targetString.contains("?") ? "&" : "?") + encoded
            }
        }

        guard let targetURL = URL(string: targetString) else {
            throw AppLaunchError.systemLaunchFailed(targetString)
        }

        // 5. Pre-flight check with canOpenURL & launch via UIApplication
        #if canImport(UIKit)
        let canOpen = UIApplication.shared.canOpenURL(targetURL)
        guard canOpen else {
            throw AppLaunchError.appNotInstalled(appName: descriptor.appName, appStoreURL: descriptor.appStoreURL)
        }

        let opened = await UIApplication.shared.open(targetURL)
        guard opened else {
            throw AppLaunchError.systemLaunchFailed(targetString)
        }
        #endif

        return targetURL
    }
}

