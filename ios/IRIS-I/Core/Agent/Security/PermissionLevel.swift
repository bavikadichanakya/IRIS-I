//
//  PermissionLevel.swift
//  IRIS-I
//
//  Security policy tiers separating read-only queries from sensitive actions.
//

import Foundation

public enum PermissionLevel: String, Codable, Sendable, Comparable {
    /// Read-only queries, time, telemetry, and web searches (executes immediately).
    case publicLevel = "PUBLIC"
    /// Actions with external side-effects (opening apps, composing drafts, smart home toggles).
    case protectedLevel = "PROTECTED"
    /// Destructive, irreversible, or privileged actions (deleting calendar items, sending emails directly).
    case sensitiveLevel = "SENSITIVE"

    private var priority: Int {
        switch self {
        case .publicLevel: return 0
        case .protectedLevel: return 1
        case .sensitiveLevel: return 2
        }
    }

    public static func < (lhs: PermissionLevel, rhs: PermissionLevel) -> Bool {
        lhs.priority < rhs.priority
    }
}

