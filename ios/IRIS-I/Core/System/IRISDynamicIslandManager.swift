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

#if canImport(ActivityKit)
public struct IRISLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var statusText: String
        public var isListening: Bool
        public var audioLevel: Float

        public init(statusText: String = "Listening...", isListening: Bool = true, audioLevel: Float = 0.0) {
            self.statusText = statusText
            self.isListening = isListening
            self.audioLevel = audioLevel
        }
    }

    public var title: String

    public init(title: String = "Hey IRIS") {
        self.title = title
    }
}

@MainActor
public final class IRISDynamicIslandManager: ObservableObject {
    public static let shared = IRISDynamicIslandManager()

    @Published public var isLiveActivityActive: Bool = false
    private var currentActivity: Activity<IRISLiveActivityAttributes>?

    private init() {}

    public func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard currentActivity == nil else { return }

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
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    public func updateLiveActivity(statusText: String, isListening: Bool, audioLevel: Float) {
        guard let activity = currentActivity else { return }
        let updatedState = IRISLiveActivityAttributes.ContentState(
            statusText: statusText,
            isListening: isListening,
            audioLevel: audioLevel
        )
        Task {
            await activity.update(.init(state: updatedState, staleDate: nil))
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
#endif

