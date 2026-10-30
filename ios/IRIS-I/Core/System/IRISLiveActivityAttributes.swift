//
//  IRISLiveActivityAttributes.swift
//  IRIS-I
//
//  Shared ActivityAttributes for Live Activity and Dynamic Island coordination.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit

public struct IRISLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var statusText: String
        public var isListening: Bool
        public var audioLevel: Float

        public var status: String {
            get { statusText }
            set { statusText = newValue }
        }

        public init(statusText: String = "Listening...", isListening: Bool = true, audioLevel: Float = 0.0) {
            self.statusText = statusText
            self.isListening = isListening
            self.audioLevel = audioLevel
        }

        public init(status: String) {
            self.statusText = status
            self.isListening = true
            self.audioLevel = 0.2
        }
    }

    public var title: String

    public init(title: String = "Hey IRIS") {
        self.title = title
    }
}

public typealias IrisWidgetAttributes = IRISLiveActivityAttributes
#endif

