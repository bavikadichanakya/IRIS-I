//
//  NotificationManager.swift
//  IRIS-I
//
//  Manages local notification authorization and scheduling for proactive assistant alerts,
//  daily briefings, and reminder notifications via UserNotifications framework.
//

import Foundation
import UserNotifications

public final class NotificationManager: @unchecked Sendable {
    public static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    public func requestNotificationPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[NOTIFICATIONS] Authorization error: \(error.localizedDescription)")
            return false
        }
    }

    public func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    /// Schedules an immediate or delayed local assistant notification
    public func scheduleNotification(
        identifier: String = UUID().uuidString,
        title: String,
        body: String,
        timeInterval: TimeInterval = 1.0,
        userInfo: [String: Sendable] = [:]
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var strDict: [String: Any] = [:]
        for (k, v) in userInfo { strDict[k] = v }
        content.userInfo = strDict

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1.0, timeInterval),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
        print("[NOTIFICATIONS] Scheduled notification '\(identifier)': \(title)")
    }

    /// Schedules a recurring daily briefing notification at a specified hour and minute
    public func scheduleDailyBriefing(at hour: Int = 8, minute: Int = 30) async throws {
        let identifier = "iris.daily.briefing"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Good Morning from IRIS"
        content.body = "Your daily agenda and schedule are ready. Tap to view your morning briefing."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await center.add(request)
        print("[NOTIFICATIONS] Configured daily briefing recurring notification for \(hour):\(String(format: "%02d", minute))")
    }

    public func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
