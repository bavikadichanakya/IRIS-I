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
    }

    public func register(_ descriptor: AppLaunchDescriptor) {
        registry[descriptor.appName.lowercased()] = descriptor
    }

    public func descriptor(for appName: String) -> AppLaunchDescriptor? {
        registry[appName.lowercased()]
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
        guard let descriptor = descriptor(for: lowName) else {
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

