//
//  ModelStorageManager.swift
//  IRIS-I
//
//  Manages isolated disk storage for local model weights outside the app bundle.
//

import Foundation

public final class ModelStorageManager: Sendable {
    public static let shared = ModelStorageManager()

    public let baseDirectory: URL
    public let weightsDirectory: URL
    public let downloadsDirectory: URL

    public init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let irisDir = appSupport.appendingPathComponent("IRIS-I", isDirectory: true)
        self.baseDirectory = irisDir
        self.weightsDirectory = irisDir.appendingPathComponent("Models/weights", isDirectory: true)
        self.downloadsDirectory = irisDir.appendingPathComponent("Models/downloads", isDirectory: true)

        try? fileManager.createDirectory(at: weightsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)

        // Exclude entire Models directory from iCloud backups
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableWeights = weightsDirectory
        try? mutableWeights.setResourceValues(resourceValues)
    }

    public func fileURL(for filename: String) -> URL {
        let weightsPath = weightsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: weightsPath.path) {
            return weightsPath
        }
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docsPath = docs.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: docsPath.path) {
                return docsPath
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
