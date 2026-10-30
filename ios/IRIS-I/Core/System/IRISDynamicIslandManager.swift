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
        // Part 3.8: Clean up any orphaned/abandoned activities from previous sessions
        Task {
            for activity in Activity<IRISLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    public func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Reuse existing active activity if one is already present
        if let existing = currentActivity ?? Activity<IRISLiveActivityAttributes>.activities.first {
            self.currentActivity = existing
            self.isLiveActivityActive = true
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
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            self.currentActivity = activity
            self.isLiveActivityActive = true
            self.lastStatusText = "Listening..."
            self.lastUpdateTime = Date()

            // Trigger alert expansion to display the full Hey IRIS island capsule immediately
            Task {
                let alertConfig = AlertConfiguration(
                    title: "Hey IRIS",
                    body: "Listening...",
                    sound: nil
                )
                await activity.update(
                    ActivityContent(state: initialState, staleDate: nil),
                    alertConfiguration: alertConfig
                )
            }
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    public func updateLiveActivity(statusText: String, isListening: Bool, audioLevel: Float) {
        guard let activity = currentActivity else { return }
        let now = Date()
        let isStatusChanged = (statusText != lastStatusText)
        let isIntervalElapsed = now.timeIntervalSince(lastUpdateTime) >= 0.35

        // Throttle audio waveform updates to prevent widgetd IPC rate-limiting kills
        guard isStatusChanged || isIntervalElapsed else { return }

        lastUpdateTime = now
        lastStatusText = statusText

        let updatedState = IRISLiveActivityAttributes.ContentState(
            statusText: statusText,
            isListening: isListening,
            audioLevel: audioLevel
        )
        Task {
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
    }

    public func updateSessionState(_ state: IRISSessionState, audioLevel: Float = 0.0, details: String? = nil) {
        let text: String
        let isListening: Bool
        switch state {
        case .idle:
            text = "Ready"
            isListening = false
        case .listening:
            text = "Listening..."
            isListening = true
        case .thinking:
            text = "Thinking..."
            isListening = false
        case .executing:
            text = details.map { "Executing \($0)..." } ?? "Executing..."
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
            text = details ?? "Could not complete"
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
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
            self.isLiveActivityActive = false
        }
    }
}

