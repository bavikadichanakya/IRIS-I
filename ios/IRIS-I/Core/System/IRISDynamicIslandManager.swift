//
//  IRISDynamicIslandManager.swift
//  IRIS-I
//
//  Dynamic Island & Live Activity coordination for background listening and Lock Screen indicators.
//

import Foundation
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

public enum IRISSessionState: String, Codable, Sendable {
    case idle = "Ready"
    case listening = "Listening..."
    case thinking = "Thinking..."
    case executing = "Executing..."
    case responding = "Responding..."
    case completedVerified = "Completed"
    case completedUnverified = "Completed (Unverified)"
    case failed = "Could not complete"
    case cancelled = "Cancelled"
}

@MainActor
public final class IRISDynamicIslandManager: ObservableObject {
    public static let shared = IRISDynamicIslandManager()

    @Published public var isLiveActivityActive: Bool = false
    private var currentActivity: Activity<IRISLiveActivityAttributes>?
    private var lastUpdateTime: Date = .distantPast
    private var lastStatusText: String = ""

    private init() {
        #if canImport(ActivityKit)
        // Clean up any orphaned/abandoned activities from previous sessions
        Task {
            for activity in Activity<IRISLiveActivityAttributes>.activities {
                print("[ACTIVITY_KIT] Terminating stale Live Activity: \(activity.id)")
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }

    public func startLiveActivity() {
        #if canImport(ActivityKit)
        let auth = ActivityAuthorizationInfo()
        guard auth.areActivitiesEnabled else {
            print("[ACTIVITY_KIT] areActivitiesEnabled is false! Live Activities disabled by user in iOS Settings.")
            return
        }

        // Reuse existing active activity if one is already present
        if let existing = currentActivity ?? Activity<IRISLiveActivityAttributes>.activities.first {
            self.currentActivity = existing
            self.isLiveActivityActive = true
            print("[ACTIVITY_KIT] Reusing existing Live Activity with ID: \(existing.id)")
            updateLiveActivity(statusText: "Listening...", isListening: true, audioLevel: 0.2)
            return
        }

        let attributes = IRISLiveActivityAttributes(title: "Hey IRIS")
        let initialState = IRISLiveActivityAttributes.ContentState(
            statusText: "Listening...",
            isListening: true,
            audioLevel: 0.2
        )

        do {
            print("[ACTIVITY_KIT] Requesting new Activity<IRISLiveActivityAttributes>...")
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            self.currentActivity = activity
            self.isLiveActivityActive = true
            self.lastStatusText = "Listening..."
            self.lastUpdateTime = Date()
            print("[ACTIVITY_KIT] Successfully started Live Activity! Activity ID: \(activity.id)")

            // Send AlertConfiguration for prominent Dynamic Island presence
            Task {
                let alertConfig = AlertConfiguration(
                    title: "Hey IRIS",
                    body: "Listening...",
                    sound: .default
                )
                await activity.update(
                    ActivityContent(state: initialState, staleDate: nil),
                    alertConfiguration: alertConfig
                )
                print("[ACTIVITY_KIT] Sent AlertConfiguration for activity ID: \(activity.id)")
            }
        } catch {
            print("[ACTIVITY_KIT] Failed to start Live Activity: \(error.localizedDescription)")
        }
        #endif
    }

    public func updateLiveActivity(statusText: String, isListening: Bool, audioLevel: Float, transcript: String? = nil) {
        #if canImport(ActivityKit)
        guard let activity = currentActivity else { return }
        let now = Date()
        let isStatusChanged = (statusText != lastStatusText)
        let isIntervalElapsed = now.timeIntervalSince(lastUpdateTime) >= 0.25

        // Throttle audio waveform updates to prevent widgetd IPC rate-limiting kills
        guard isStatusChanged || isIntervalElapsed else { return }

        lastUpdateTime = now
        lastStatusText = statusText

        let updatedState = IRISLiveActivityAttributes.ContentState(
            statusText: statusText,
            isListening: isListening,
            audioLevel: audioLevel,
            transcript: transcript
        )
        Task {
            print("[ACTIVITY_KIT] Updating activity ID: \(activity.id) - status: '\(statusText)', audioLevel: \(audioLevel)")
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
        #endif
    }

    public func updateSessionState(_ state: IRISSessionState, audioLevel: Float = 0.0, details: String? = nil) {
        let text: String
        let isListening: Bool
        switch state {
        case .idle:
            text = "Ready..."
            isListening = false
        case .listening:
            text = "Listening..."
            isListening = true
        case .thinking:
            text = "Thinking..."
            isListening = false
        case .executing:
            text = details.map { "Opening \($0)..." } ?? "Processing..."
            isListening = false
        case .responding:
            text = "Responding..."
            isListening = false
        case .completedVerified:
            text = details ?? "Completed"
            isListening = false
        case .completedUnverified:
            text = details ?? "Completed"
            isListening = false
        case .failed:
            text = details ?? "Action failed"
            isListening = false
        case .cancelled:
            text = "Cancelled"
            isListening = false
        }

        updateLiveActivity(statusText: text, isListening: isListening, audioLevel: audioLevel)

        // Automatically end terminal activities after brief visual feedback
        if state == .completedVerified || state == .completedUnverified || state == .failed || state == .cancelled {
            Task {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                if self.currentActivity != nil && !isListening {
                    self.endLiveActivity()
                }
            }
        }
    }

    public func endLiveActivity() {
        #if canImport(ActivityKit)
        guard let activity = currentActivity else { return }
        print("[ACTIVITY_KIT] Ending Live Activity ID: \(activity.id)")
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
            self.isLiveActivityActive = false
        }
        #endif
    }
}
