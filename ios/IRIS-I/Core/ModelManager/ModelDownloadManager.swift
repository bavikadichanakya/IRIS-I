//
//  ModelDownloadManager.swift
//  IRIS-I
//
//  Manages downloading, progress observation, pausing, and cancellation of model weights.
//

import Foundation

public struct DownloadSnapshot: Sendable {
    public let modelId: String
    public let progress: Double
    public let bytesWritten: Int64
    public let totalBytes: Int64
    public let speedMBs: Double
}

public actor ModelDownloadManager: NSObject, URLSessionDownloadDelegate {
    public static let shared = ModelDownloadManager()

    private var activeTask: URLSessionDownloadTask?
    private var resumeData: Data?
    private var activeManifest: ModelManifest?
    private var startTime: Date?
    private var lastBytesWritten: Int64 = 0
    private var lastSpeedCheckTime: Date?
    private var currentSpeedMBs: Double = 0.0

    private var progressContinuation: AsyncStream<DownloadSnapshot>.Continuation?
    nonisolated(unsafe) private var targetFilename: String?
    nonisolated(unsafe) private var targetManifest: ModelManifest?

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60 * 60 * 2 // 2 hours max
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    public func startDownload(
        manifest: ModelManifest,
        from url: URL
    ) -> AsyncStream<DownloadSnapshot> {
        cancelDownload()

        // Storage pre-flight check: ensure sufficient disk space is available
        guard ModelStorageManager.shared.hasSufficientSpace(requiredBytes: manifest.requiredDiskBytes) else {
            let (stream, continuation) = AsyncStream<DownloadSnapshot>.makeStream()
            continuation.finish()
            return stream
        }

        self.activeManifest = manifest
        self.targetManifest = manifest
        self.targetFilename = manifest.filename
        self.startTime = Date()
        self.lastSpeedCheckTime = Date()
        self.lastBytesWritten = 0
        self.currentSpeedMBs = 0.0

        let (stream, continuation) = AsyncStream<DownloadSnapshot>.makeStream()
        self.progressContinuation = continuation

        let task: URLSessionDownloadTask
        if let resume = resumeData {
            task = session.downloadTask(withResumeData: resume)
            self.resumeData = nil
        } else {
            task = session.downloadTask(with: url)
        }
        self.activeTask = task
        task.resume()

        return stream
    }

    public func pauseDownload() async {
        guard let task = activeTask else { return }
        let data = await task.cancelByProducingResumeData()
        self.resumeData = data
        self.activeTask = nil
        self.progressContinuation?.finish()
    }

    public func cancelDownload() {
        activeTask?.cancel()
        activeTask = nil
        resumeData = nil
        targetFilename = nil
        targetManifest = nil
        progressContinuation?.finish()
        progressContinuation = nil
    }

    // MARK: - URLSessionDownloadDelegate

    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task {
            await self.recordProgress(
                totalWritten: totalBytesWritten,
                totalExpected: totalBytesExpectedToWrite
            )
        }
    }

    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Critical iOS Requirement: URLSession deletes `location` the moment this delegate callback exits.
        // Step 2: We MUST move the temporary file synchronously to intermediate staging before returning!
        let storage = ModelStorageManager.shared
        guard let filename = self.targetFilename else {
            return
        }
        let stagingURL = storage.stagingURL(for: filename)
        do {
            try FileManager.default.createDirectory(at: stagingURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: stagingURL.path) {
                try FileManager.default.removeItem(at: stagingURL)
            }
            try FileManager.default.moveItem(at: location, to: stagingURL)
        } catch {
            print("ModelDownloadManager: Failed to move temp file to staging synchronously: \(error)")
        }

        Task {
            await self.handleDownloadCompletion(stagingURL: stagingURL, filename: filename)
        }
    }

    public nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            Task {
                await self.handleDownloadError(error)
            }
        }
    }

    // MARK: - Internal Handlers

    private func recordProgress(totalWritten: Int64, totalExpected: Int64) {
        let now = Date()
        if let lastCheck = lastSpeedCheckTime, now.timeIntervalSince(lastCheck) >= 0.5 {
            let deltaSeconds = now.timeIntervalSince(lastCheck)
            let deltaBytes = totalWritten - lastBytesWritten
            let bytesPerSec = Double(deltaBytes) / deltaSeconds
            self.currentSpeedMBs = bytesPerSec / (1024 * 1024)
            self.lastSpeedCheckTime = now
            self.lastBytesWritten = totalWritten
        }

        let progress = totalExpected > 0 ? min(1.0, Double(totalWritten) / Double(totalExpected)) : 0.0
        let snapshot = DownloadSnapshot(
            modelId: activeManifest?.id ?? "unknown",
            progress: progress,
            bytesWritten: totalWritten,
            totalBytes: totalExpected,
            speedMBs: currentSpeedMBs
        )
        progressContinuation?.yield(snapshot)
    }

    private func handleDownloadCompletion(stagingURL: URL, filename: String) async {
        guard let manifest = activeManifest else { return }

        do {
            // Steps 3, 4, 5, 6: Verify file exists, byte size, checksum, and GGUF header metadata in staging
            let result = try await ModelIntegrityValidator.shared.validate(
                fileURL: stagingURL,
                expectedSHA256: manifest.expectedSHA256,
                minByteSize: 10_000_000
            )
            print("ModelDownloadManager: Validation succeeded! GGUF v\(result.version), \(result.tensorCount) tensors, SHA256: \(result.sha256)")
            // Step 7: Atomically promote the validated artifact into permanent model storage
            _ = try ModelStorageManager.shared.atomicPromote(stagingURL: stagingURL, filename: filename)
            progressContinuation?.finish()
        } catch {
            print("ModelDownloadManager: Validation/Promotion failed: \(error)")
            // Strict integrity rule: A downloaded model that fails its expected SHA-256 check
            // must NOT be promoted as a trusted model. Move to quarantine directory for inspection.
            if case IntegrityError.checksumMismatch = error {
                print("ModelDownloadManager: Checksum mismatch detected! Quarantining artifact to prevent unauthorized execution.")
                _ = try? ModelStorageManager.shared.quarantine(stagingURL: stagingURL, filename: filename)
            } else {
                try? FileManager.default.removeItem(at: stagingURL)
            }
            progressContinuation?.finish()
        }
    }

    private func handleDownloadError(_ error: Error) {
        progressContinuation?.finish()
        activeTask = nil
    }
}
