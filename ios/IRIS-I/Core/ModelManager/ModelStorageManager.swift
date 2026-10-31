//
//  ModelStorageManager.swift
//  IRIS-I
//
//  Manages isolated disk storage for local model weights outside the app bundle.
//

import Foundation

/// Strict integrity state of a local neural model artifact.
public enum ModelIntegrityState: String, Codable, Sendable {
    case downloading
    case staged
    case validating
    case verified
    case installed
    case failed
    case quarantined
}

public final class ModelStorageManager: Sendable {
    public static let shared = ModelStorageManager()

    public let baseDirectory: URL
    public let weightsDirectory: URL
    public let downloadsDirectory: URL
    public let stagingDirectory: URL
    public let quarantineDirectory: URL

    public init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let irisDir = appSupport.appendingPathComponent("IRIS-I", isDirectory: true)
        self.baseDirectory = irisDir
        self.weightsDirectory = irisDir.appendingPathComponent("Models/weights", isDirectory: true)
        self.downloadsDirectory = irisDir.appendingPathComponent("Models/downloads", isDirectory: true)
        self.stagingDirectory = irisDir.appendingPathComponent("Models/staging", isDirectory: true)
        self.quarantineDirectory = irisDir.appendingPathComponent("Models/quarantine", isDirectory: true)

        try? fileManager.createDirectory(at: weightsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)

        // Exclude entire Models directory from iCloud backups
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableWeights = weightsDirectory
        try? mutableWeights.setResourceValues(resourceValues)
    }

    public func stagingURL(for filename: String) -> URL {
        stagingDirectory.appendingPathComponent(filename)
    }

    public func weightsURL(for filename: String) -> URL {
        weightsDirectory.appendingPathComponent(filename)
    }

    public func quarantineURL(for filename: String) -> URL {
        quarantineDirectory.appendingPathComponent(filename)
    }

    /// Safely isolates an artifact that failed integrity verification into quarantine.
    public func quarantine(stagingURL: URL, filename: String) throws -> URL {
        let fm = FileManager.default
        let destURL = quarantineURL(for: filename)

        try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }

        try fm.moveItem(at: stagingURL, to: destURL)
        return destURL
    }

    /// Lists all quarantined model files awaiting investigation.
    public func quarantinedFiles() -> [URL] {
        let fm = FileManager.default
        return (try? fm.contentsOfDirectory(at: quarantineDirectory, includingPropertiesForKeys: nil)) ?? []
    }

    /// Queries the actual available free disk space on device volume in bytes
    public func availableDiskSpaceBytes() -> Int64 {
        do {
            let values = try baseDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return capacity
            }
        } catch {}
        // Fallback to POSIX statvfs
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: baseDirectory.path),
           let freeSize = attrs[.systemFreeSize] as? Int64 {
            return freeSize
        }
        return 0
    }

    /// Verifies if the device has enough free storage with a 500 MB safety buffer
    public func hasSufficientSpace(requiredBytes: Int64) -> Bool {
        let free = availableDiskSpaceBytes()
        let safetyBuffer: Int64 = 500 * 1024 * 1024 // 500 MB safety buffer
        return free > (requiredBytes + safetyBuffer)
    }

    /// Atomically promotes a verified model from staging to permanent weights storage
    public func atomicPromote(stagingURL: URL, filename: String) throws -> URL {
        let fm = FileManager.default
        let destURL = weightsURL(for: filename)

        try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }

        try fm.moveItem(at: stagingURL, to: destURL)
        return destURL
    }

    /// Cleans up any leftover artifacts in the staging directory
    public func cleanupStaging() {
        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(at: stagingDirectory, includingPropertiesForKeys: nil) {
            for item in items {
                try? fm.removeItem(at: item)
            }
        }
    }

    public func fileURL(for filename: String) -> URL {
        let weightsPath = weightsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: weightsPath.path) {
            return weightsPath
        }

        // Check Documents root and Documents/Models
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docsDirect = docs.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: docsDirect.path) {
                return docsDirect
            }
            let docsModels = docs.appendingPathComponent("Models").appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: docsModels.path) {
                return docsModels
            }
        }

        return weightsPath
    }

    public func isModelInstalled(_ manifest: ModelManifest) -> Bool {
        let url = fileURL(for: manifest.filename)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        guard exists && !isDir.boolValue else { return false }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            return size > 1_000_000 // Must be larger than 1 MB to be a valid weight file
        }
        return false
    }

    public func fileSize(for manifest: ModelManifest) -> Int64? {
        let url = fileURL(for: manifest.filename)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return nil }
        return size
    }

    public func deleteModel(_ manifest: ModelManifest) throws {
        let url = fileURL(for: manifest.filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Safely imports a local .gguf model file selected by the user via Document Picker
    public func importLocalModel(
        from sourceURL: URL,
        manifest: ModelManifest,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        let shouldStopAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationURL = fileURL(for: manifest.filename)
        let fm = FileManager.default

        // Clean existing file if present
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }

        // Stream file copy with progress
        let sourceHandle = try FileHandle(forReadingFrom: sourceURL)
        defer { try? sourceHandle.close() }

        fm.createFile(atPath: destinationURL.path, contents: nil)
        let destHandle = try FileHandle(forWritingTo: destinationURL)
        defer { try? destHandle.close() }

        let attrs = try fm.attributesOfItem(atPath: sourceURL.path)
        let totalBytes = (attrs[.size] as? Int64) ?? 1
        var copiedBytes: Int64 = 0
        let chunkSize = 1024 * 1024 * 4 // 4 MB chunk

        while autoreleasepool(invoking: {
            let data = sourceHandle.readData(ofLength: chunkSize)
            guard !data.isEmpty else { return false }
            destHandle.write(data)
            copiedBytes += Int64(data.count)
            let progress = min(1.0, Double(copiedBytes) / Double(totalBytes))
            progressHandler?(progress)
            return true
        }) {}

        return destinationURL
    }
}
