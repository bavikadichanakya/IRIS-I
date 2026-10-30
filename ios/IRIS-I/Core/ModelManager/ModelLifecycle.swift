//
//  ModelLifecycle.swift
//  IRIS-I
//
//  State machine governing individual model and engine lifecycles.
//

import Foundation

public enum ModelLifecycleState: Equatable, Sendable {
    case uninstalled
    case downloading(progress: Double, bytesWritten: Int64, totalBytes: Int64, speedMBs: Double)
    case importing(progress: Double)
    case staged(fileURL: URL, fileSize: Int64)
    case validating(step: String)
    case installed(fileURL: URL, fileSize: Int64)
    case loading(progress: Double)
    case loaded(contextSize: Int)
    case operational(contextSize: Int)
    case ready(contextSize: Int)
    case inferring(promptSnippet: String)
    case unloading
    case failed(error: String)

    public var isOperational: Bool {
        switch self {
        case .operational, .ready, .inferring:
            return true
        default:
            return false
        }
    }

    public var isLoaded: Bool {
        switch self {
        case .loaded, .operational, .ready, .inferring:
            return true
        default:
            return false
        }
    }

    public var isInstalled: Bool {
        switch self {
        case .installed, .loading, .loaded, .operational, .ready, .inferring, .unloading:
            return true
        default:
            return false
        }
    }

    public var displayTitle: String {
        switch self {
        case .uninstalled:
            return "Not Installed"
        case .downloading(let p, _, _, let spd):
            return String(format: "Downloading (%.1f%%, %.1f MB/s)", p * 100, spd)
        case .importing(let p):
            return String(format: "Importing (%.1f%%)", p * 100)
        case .staged:
            return "Downloaded (Staged, Pending Verification)"
        case .validating(let step):
            return "Verifying: \(step)"
        case .installed:
            return "Installed (Inactive)"
        case .loading(let p):
            return String(format: "Loading Metal Engine (%.0f%%)...", p * 100)
        case .loaded(let ctx):
            return "Loaded (Warming Up, Context: \(ctx))..."
        case .operational(let ctx), .ready(let ctx):
            return "Active (Context: \(ctx))"
        case .inferring:
            return "Generating..."
        case .unloading:
            return "Unloading Engine..."
        case .failed(let err):
            return "Failed: \(err)"
        }
    }
}
