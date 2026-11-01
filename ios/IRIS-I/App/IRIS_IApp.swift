//
//  IRIS_IApp.swift
//  IRIS-I
//
//  Main application entrypoint.
//

import SwiftUI
#if canImport(AppIntents)
import AppIntents
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

#if canImport(UIKit)
import UIKit

final class IRISAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        #endif
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let target = response.notification.request.content.userInfo["targetURL"] as? String,
           let url = URL(string: target) {
            Task { @MainActor in
                await UIApplication.shared.open(url, options: [:])
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
#endif

@main
struct IRIS_IApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(IRISAppDelegate.self) var appDelegate
    #endif

    init() {
        #if canImport(AppIntents)
        if #available(iOS 16.0, *) {
            IRISAppShortcutsProvider.updateAppShortcutParameters()
        }
        #endif
        Task {
            await BrainDownloadCoordinator.shared.autoProvisionOrActivateOnLaunch()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
