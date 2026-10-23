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
    case validating
    case installed(fileURL: URL, fileSize: Int64)
    case loading(progress: Double)
    case ready(contextSize: Int)
    case inferring(promptSnippet: String)
    case unloading
    case failed(error: String)

    public var isLoaded: Bool {
        switch self {
        case .ready, .inferring:
            return true
        default:
            return false
        }
    }

    public var isInstalled: Bool {
        switch self {
        case .installed, .loading, .ready, .inferring, .unloading:
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
        case .validating:
            return "Verifying Integrity (SHA-256)..."
        case .installed:
            return "Installed"
        case .loading(let p):
            return String(format: "Loading Metal Engine (%.0f%%)...", p * 100)
        case .ready(let ctx):
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
