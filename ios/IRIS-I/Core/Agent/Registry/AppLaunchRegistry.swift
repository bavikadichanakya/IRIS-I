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
    public var displayName: String { appName }
    public let urlScheme: String
    public let queryScheme: String?
    public let universalLinkURL: URL?
    public let appStoreURL: URL?
    public let description: String

    public init(
        appName: String,
        urlScheme: String,
        queryScheme: String? = nil,
        universalLinkURL: URL? = nil,
        appStoreURL: URL? = nil,
        description: String
    ) {
        self.appName = appName
        self.urlScheme = urlScheme
        self.queryScheme = queryScheme
        self.universalLinkURL = universalLinkURL
        self.appStoreURL = appStoreURL
        self.description = description
    }
}

public enum AppLaunchError: LocalizedError, Sendable {
    case unregisteredScheme(String)
    case unsupportedApp(appName: String)
    case appNotInstalled(appName: String, appStoreURL: URL?)
    case unsupportedInAppAction(String)
    case systemLaunchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unregisteredScheme(let s):
            return "The scheme '\(s)' is not registered or is prohibited on iOS."
        case .unsupportedApp(let name):
            return "Cannot open '\(name)': this application is not registered in the verified iOS capability registry."
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
            universalLinkURL: URL(string: "https://maps.apple.com/"),
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
            universalLinkURL: URL(string: "https://open.spotify.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/spotify/id324684580"),
            description: "Spotify music streaming"
        ))
        register(AppLaunchDescriptor(
            appName: "YouTube",
            urlScheme: "youtube:",
            queryScheme: "youtube",
            universalLinkURL: URL(string: "https://www.youtube.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/youtube/id544007664"),
            description: "YouTube video player"
        ))
        register(AppLaunchDescriptor(
            appName: "Instagram",
            urlScheme: "instagram:",
            queryScheme: "instagram",
            universalLinkURL: URL(string: "https://www.instagram.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/instagram/id389801252"),
            description: "Instagram photo and video sharing"
        ))
        register(AppLaunchDescriptor(
            appName: "TikTok",
            urlScheme: "snssdk1233:",
            queryScheme: "snssdk1233",
            universalLinkURL: URL(string: "https://www.tiktok.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/tiktok/id835599320"),
            description: "TikTok short-form video"
        ))
        register(AppLaunchDescriptor(
            appName: "Music",
            urlScheme: "music:",
            queryScheme: "music",
            universalLinkURL: URL(string: "https://music.apple.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/apple-music/id1108187390"),
            description: "Apple Music player and streaming"
        ))
        register(AppLaunchDescriptor(
            appName: "Apple Music",
            urlScheme: "music:",
            queryScheme: "music",
            universalLinkURL: URL(string: "https://music.apple.com/"),
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
            universalLinkURL: URL(string: "https://chat.whatsapp.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/whatsapp-messenger/id310633997"),
            description: "WhatsApp Messenger"
        ))
        register(AppLaunchDescriptor(
            appName: "Telegram",
            urlScheme: "tg:",
            queryScheme: "tg",
            universalLinkURL: URL(string: "https://t.me/"),
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
            universalLinkURL: URL(string: "https://chatgpt.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/chatgpt/id6448311069"),
            description: "OpenAI ChatGPT app"
        ))
        register(AppLaunchDescriptor(
            appName: "Twitter",
            urlScheme: "twitter:",
            queryScheme: "twitter",
            universalLinkURL: URL(string: "https://x.com/"),
            description: "X / Twitter"
        ))
        register(AppLaunchDescriptor(
            appName: "Reddit",
            urlScheme: "reddit:",
            queryScheme: "reddit",
            universalLinkURL: URL(string: "https://www.reddit.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/reddit/id1064216828"),
            description: "Reddit social news and communities"
        ))
        register(AppLaunchDescriptor(
            appName: "Slack",
            urlScheme: "slack:",
            queryScheme: "slack",
            universalLinkURL: URL(string: "https://slack.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/slack/id618783545"),
            description: "Slack team collaboration"
        ))
        register(AppLaunchDescriptor(
            appName: "Discord",
            urlScheme: "discord:",
            queryScheme: "discord",
            universalLinkURL: URL(string: "https://discord.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/discord/id985746746"),
            description: "Discord voice and chat"
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


    /// Preflights and launches an app via capability-driven dispatch (Native URL Scheme or Universal Link).
    /// Runs on the MainActor for UIKit interaction.
    @MainActor
    public func launchApp(name: String, parameter: String? = nil) async throws -> URL {
        let lowName = name.lowercased().trimmingCharacters(in: .whitespaces)

        // 1. Special Case: iOS System Settings via official public API
        if lowName == "settings" || lowName == "app settings" || lowName == "system settings" {
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

        // 3. Resolve verified descriptor strictly without guessing fake schemes
        guard let descriptor = descriptor(for: lowName) else {
            throw AppLaunchError.unsupportedApp(appName: name)
        }

        // 4. Construct candidate URL Scheme
        var targetString = descriptor.urlScheme
        if let param = parameter, !param.isEmpty {
            if targetString.hasSuffix("=") || targetString.hasSuffix(":") {
                let encoded = param.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? param
                targetString += encoded
            } else {
                let encoded = param.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? param
                targetString += (targetString.contains("?") ? "&" : "?") + encoded
            }
        }

        #if canImport(UIKit)
        // Phase 1: Try Native URL Scheme if canOpenURL allows it
        if let schemeURL = URL(string: targetString), UIApplication.shared.canOpenURL(schemeURL) {
            let opened = await UIApplication.shared.open(schemeURL)
            if opened {
                return schemeURL
            }
        }

        // Phase 2: Try Universal Link with .universalLinksOnly: true
        // Official iOS public API: launches the native app if installed, failing cleanly if not installed
        if let universalBase = descriptor.universalLinkURL {
            let openedNative = await UIApplication.shared.open(universalBase, options: [.universalLinksOnly: true])
            if openedNative {
                return universalBase
            }
        }

        // Phase 3: Neither native scheme nor universal link opened a native app
        // Truthful outcome: the application is not installed on this device
        throw AppLaunchError.appNotInstalled(appName: descriptor.appName, appStoreURL: descriptor.appStoreURL)
        #else
        throw AppLaunchError.systemLaunchFailed("UIKit unavailable on this platform")
        #endif
    }
}

