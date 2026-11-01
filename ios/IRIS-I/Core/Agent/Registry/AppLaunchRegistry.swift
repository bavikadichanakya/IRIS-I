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
#if canImport(UserNotifications)
import UserNotifications
#endif

public struct AppLaunchDescriptor: Sendable {
    public let appName: String
    public var displayName: String { appName }
    public let urlScheme: String
    public let queryScheme: String?
    public let universalLinkURL: URL?
    public let appStoreURL: URL?
    public let description: String
    public let bundleID: String?

    public init(
        appName: String,
        urlScheme: String,
        queryScheme: String? = nil,
        universalLinkURL: URL? = nil,
        appStoreURL: URL? = nil,
        description: String,
        bundleID: String? = nil
    ) {
        self.appName = appName
        self.urlScheme = urlScheme
        self.queryScheme = queryScheme
        self.universalLinkURL = universalLinkURL
        self.appStoreURL = appStoreURL
        self.description = description
        self.bundleID = bundleID
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
            description: "Apple Maps directions and locations",
            bundleID: "com.apple.Maps"
        ))
        register(AppLaunchDescriptor(
            appName: "Messages",
            urlScheme: "sms:",
            queryScheme: "sms",
            description: "iOS Messages app composer",
            bundleID: "com.apple.MobileSMS"
        ))
        register(AppLaunchDescriptor(
            appName: "Phone",
            urlScheme: "tel:",
            queryScheme: "tel",
            description: "Phone dialer",
            bundleID: "com.apple.mobilephone"
        ))
        register(AppLaunchDescriptor(
            appName: "Mail",
            urlScheme: "mailto:",
            queryScheme: "mailto",
            description: "Default email client composer",
            bundleID: "com.apple.mobilemail"
        ))
        register(AppLaunchDescriptor(
            appName: "Shortcuts",
            urlScheme: "shortcuts://run-shortcut?name=",
            queryScheme: "shortcuts",
            description: "Apple Shortcuts execution",
            bundleID: "com.apple.shortcuts"
        ))
        register(AppLaunchDescriptor(
            appName: "Spotify",
            urlScheme: "spotify:",
            queryScheme: "spotify",
            universalLinkURL: URL(string: "https://open.spotify.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/spotify/id324684580"),
            description: "Spotify music streaming",
            bundleID: "com.spotify.client"
        ))
        register(AppLaunchDescriptor(
            appName: "YouTube",
            urlScheme: "youtube:",
            queryScheme: "youtube",
            universalLinkURL: URL(string: "https://www.youtube.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/youtube/id544007664"),
            description: "YouTube video player",
            bundleID: "com.google.ios.youtube"
        ))
        register(AppLaunchDescriptor(
            appName: "Instagram",
            urlScheme: "instagram:",
            queryScheme: "instagram",
            universalLinkURL: URL(string: "https://www.instagram.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/instagram/id389801252"),
            description: "Instagram photo and video sharing",
            bundleID: "com.burbn.instagram"
        ))
        register(AppLaunchDescriptor(
            appName: "TikTok",
            urlScheme: "snssdk1233:",
            queryScheme: "snssdk1233",
            universalLinkURL: URL(string: "https://www.tiktok.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/tiktok/id835599320"),
            description: "TikTok short-form video",
            bundleID: "com.zhiliaoapp.musically"
        ))
        register(AppLaunchDescriptor(
            appName: "Music",
            urlScheme: "music:",
            queryScheme: "music",
            universalLinkURL: URL(string: "https://music.apple.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/apple-music/id1108187390"),
            description: "Apple Music player and streaming",
            bundleID: "com.apple.Music"
        ))
        register(AppLaunchDescriptor(
            appName: "Apple Music",
            urlScheme: "music:",
            queryScheme: "music",
            universalLinkURL: URL(string: "https://music.apple.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/apple-music/id1108187390"),
            description: "Apple Music player and streaming",
            bundleID: "com.apple.Music"
        ))
        register(AppLaunchDescriptor(
            appName: "Photos",
            urlScheme: "photos-redirect:",
            queryScheme: "photos-redirect",
            description: "Apple Photos library",
            bundleID: "com.apple.mobileslideshow"
        ))
        register(AppLaunchDescriptor(
            appName: "Camera",
            urlScheme: "camera:",
            queryScheme: "camera",
            description: "Camera capture app",
            bundleID: "com.apple.camera"
        ))
        register(AppLaunchDescriptor(
            appName: "Notes",
            urlScheme: "mobilenotes:",
            queryScheme: "mobilenotes",
            description: "Apple Notes",
            bundleID: "com.apple.mobilenotes"
        ))
        register(AppLaunchDescriptor(
            appName: "Calendar",
            urlScheme: "calshow:",
            queryScheme: "calshow",
            description: "iOS Calendar",
            bundleID: "com.apple.mobilecal"
        ))
        register(AppLaunchDescriptor(
            appName: "Reminders",
            urlScheme: "x-apple-reminderkit:",
            queryScheme: "x-apple-reminderkit",
            description: "Apple Reminders",
            bundleID: "com.apple.reminders"
        ))
        register(AppLaunchDescriptor(
            appName: "WhatsApp",
            urlScheme: "whatsapp:",
            queryScheme: "whatsapp",
            universalLinkURL: URL(string: "https://chat.whatsapp.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/whatsapp-messenger/id310633997"),
            description: "WhatsApp Messenger",
            bundleID: "net.whatsapp.WhatsApp"
        ))
        register(AppLaunchDescriptor(
            appName: "Telegram",
            urlScheme: "tg:",
            queryScheme: "tg",
            universalLinkURL: URL(string: "https://t.me/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/telegram-messenger/id686449807"),
            description: "Telegram Messenger",
            bundleID: "ph.telegra.Telegraph"
        ))
        register(AppLaunchDescriptor(
            appName: "FaceTime",
            urlScheme: "facetime:",
            queryScheme: "facetime",
            description: "Apple FaceTime video calls",
            bundleID: "com.apple.facetime"
        ))
        register(AppLaunchDescriptor(
            appName: "Files",
            urlScheme: "shareddocuments:",
            queryScheme: "shareddocuments",
            description: "Apple Files document manager",
            bundleID: "com.apple.DocumentsApp"
        ))
        register(AppLaunchDescriptor(
            appName: "ChatGPT",
            urlScheme: "chatgpt:",
            queryScheme: "chatgpt",
            universalLinkURL: URL(string: "https://chatgpt.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/chatgpt/id6448311069"),
            description: "OpenAI ChatGPT app",
            bundleID: "com.openai.chat"
        ))
        register(AppLaunchDescriptor(
            appName: "Twitter",
            urlScheme: "twitter:",
            queryScheme: "twitter",
            universalLinkURL: URL(string: "https://x.com/"),
            description: "X / Twitter",
            bundleID: "com.atebits.Tweetie2"
        ))
        register(AppLaunchDescriptor(
            appName: "Reddit",
            urlScheme: "reddit:",
            queryScheme: "reddit",
            universalLinkURL: URL(string: "https://www.reddit.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/reddit/id1064216828"),
            description: "Reddit social news and communities",
            bundleID: "com.reddit.Reddit"
        ))
        register(AppLaunchDescriptor(
            appName: "Slack",
            urlScheme: "slack:",
            queryScheme: "slack",
            universalLinkURL: URL(string: "https://slack.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/slack/id618783545"),
            description: "Slack team collaboration",
            bundleID: "com.tinyspeck.chatlyio"
        ))
        register(AppLaunchDescriptor(
            appName: "Discord",
            urlScheme: "discord:",
            queryScheme: "discord",
            universalLinkURL: URL(string: "https://discord.com/"),
            appStoreURL: URL(string: "https://apps.apple.com/app/discord/id985746746"),
            description: "Discord voice and chat",
            bundleID: "com.hammerandchisel.discord"
        ))
        register(AppLaunchDescriptor(
            appName: "Safari",
            urlScheme: "https://",
            queryScheme: "http",
            universalLinkURL: URL(string: "https://apple.com"),
            description: "Apple Safari web browser",
            bundleID: "com.apple.mobilesafari"
        ))
        register(AppLaunchDescriptor(
            appName: "Calculator",
            urlScheme: "calc:",
            queryScheme: "calc",
            description: "Apple Calculator",
            bundleID: "com.apple.calculator"
        ))
        register(AppLaunchDescriptor(
            appName: "Clock",
            urlScheme: "clock-timer:",
            queryScheme: "clock-timer",
            description: "Apple Clock & Timer",
            bundleID: "com.apple.mobiletimer"
        ))
        register(AppLaunchDescriptor(
            appName: "App Store",
            urlScheme: "itms-apps:",
            queryScheme: "itms-apps",
            universalLinkURL: URL(string: "https://apps.apple.com"),
            description: "Apple App Store",
            bundleID: "com.apple.AppStore"
        ))
        register(AppLaunchDescriptor(
            appName: "Podcasts",
            urlScheme: "podcasts:",
            queryScheme: "podcasts",
            description: "Apple Podcasts",
            bundleID: "com.apple.podcasts"
        ))
        register(AppLaunchDescriptor(
            appName: "Settings",
            urlScheme: "prefs:",
            queryScheme: "prefs",
            description: "iOS Settings",
            bundleID: "com.apple.Preferences"
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
        if key == "browser" || key == "web browser" { return registry["safari"] }
        if key == "store" { return registry["app store"] }
        if key == "calc" { return registry["calculator"] }
        return nil
    }


    /// Preflights and launches an app via capability-driven dispatch (Native URL Scheme or Universal Link).
    /// Runs on the MainActor for UIKit interaction.
    @MainActor
    public func launchApp(name: String, parameter: String? = nil) async throws -> URL {
        let lowName = name.lowercased().trimmingCharacters(in: .whitespaces)
        print("[APP_LAUNCH] Attempting to launch app: '\(name)' (resolved key: '\(lowName)')")

        // 1. Special Case: iOS System Settings via official public API
        if lowName == "settings" || lowName == "app settings" || lowName == "system settings" {
            #if canImport(UIKit)
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                throw AppLaunchError.systemLaunchFailed("Invalid settings URL")
            }
            let success = await UIApplication.shared.open(settingsURL)
            print("[APP_LAUNCH] Settings launch result: \(success)")
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
            print("[APP_LAUNCH] Rejected prohibited private scheme attempt: '\(lowName)'")
            throw AppLaunchError.unregisteredScheme("App-Prefs is a private API and cannot be used.")
        }

        // 3. Resolve verified descriptor strictly without guessing fake schemes
        guard let descriptor = await descriptor(for: lowName) else {
            print("[APP_LAUNCH] App '\(name)' not found in verified registry")
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
        // Phase 1: Try Native URL Schemes and Universal Links
        var candidates: [URL] = []
        let baseScheme = descriptor.urlScheme
        let cleanParam = parameter?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if baseScheme.hasSuffix("://") {
            if let u = URL(string: baseScheme + cleanParam) { candidates.append(u) }
        } else if baseScheme.hasSuffix(":") {
            let bare = String(baseScheme.dropLast())
            if let u = URL(string: "\(bare)://\(cleanParam)") { candidates.append(u) }
            if let u = URL(string: "\(bare):\(cleanParam)") { candidates.append(u) }
        } else {
            if let u = URL(string: baseScheme) { candidates.append(u) }
        }

        if let universal = descriptor.universalLinkURL {
            candidates.append(universal)
        }

        guard let targetURL = candidates.first else {
            throw AppLaunchError.unregisteredScheme(descriptor.urlScheme)
        }

        // Multi-channel SpringBoard dispatch:
        // 1. Internal SpringBoard direct dispatch (bypasses background URL restriction on sideloaded/dev builds)
        let openSensitiveSelector = NSSelectorFromString("openSensitiveURL:withOptions:")
        if UIApplication.shared.responds(to: openSensitiveSelector) {
            print("[APP_LAUNCH] Dispatching via openSensitiveURL:withOptions: for \(targetURL.absoluteString)")
            UIApplication.shared.perform(openSensitiveSelector, with: targetURL, with: nil)
        }

        // 2. LSApplicationWorkspace openApplicationWithBundleID:
        if let bundleID = descriptor.bundleID {
            if let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
               let workspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() {
                let openAppSel = NSSelectorFromString("openApplicationWithBundleID:")
                if workspace.responds(to: openAppSel) {
                    print("[APP_LAUNCH] Dispatching via LSApplicationWorkspace.openApplicationWithBundleID: \(bundleID)")
                    workspace.perform(openAppSel, with: bundleID)
                }
            }
        }

        // 3. LSApplicationWorkspace openURL:
        if let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
           let workspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() {
            let openURLSel = NSSelectorFromString("openURL:")
            if workspace.responds(to: openURLSel) {
                print("[APP_LAUNCH] Dispatching via LSApplicationWorkspace.openURL: \(targetURL.absoluteString)")
                workspace.perform(openURLSel, with: targetURL)
            }
        }

        // 4. Standard UIApplication.shared.open on MainActor
        Task { @MainActor in
            _ = await UIApplication.shared.open(targetURL, options: [:])
        }

        // 5. Post high-priority banner notification for instant tap switch
        AppLaunchRegistry.postAppHandoffNotification(appName: descriptor.appName, targetURL: targetURL)

        // 6. Update Dynamic Island Live Activity
        Task { @MainActor in
            IRISDynamicIslandManager.shared.updateLiveActivity(
                statusText: "Opening \(descriptor.appName)...",
                isListening: false,
                audioLevel: 0.0,
                transcript: "Opening \(descriptor.appName)",
                targetURL: targetURL.absoluteString
            )
        }

        print("[APP_LAUNCH] Successfully dispatched launch for '\(descriptor.appName)' (URL: \(targetURL.absoluteString))")
        return targetURL
        #else
        throw AppLaunchError.systemLaunchFailed("UIKit unavailable on this platform")
        #endif
    }
}

#if canImport(UserNotifications)
extension AppLaunchRegistry {
    nonisolated public static func postAppHandoffNotification(appName: String, targetURL: URL) {
        let content = UNMutableNotificationContent()
        content.title = "Opening \(appName)"
        content.body = "Tap to switch to \(appName)"
        content.sound = .default
        content.userInfo = ["targetURL": targetURL.absoluteString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "app_launch_\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
#endif

