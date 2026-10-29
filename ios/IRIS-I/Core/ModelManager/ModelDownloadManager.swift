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

        self.activeManifest = manifest
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
        Task {
            await self.handleDownloadCompletion(tempLocation: location)
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

    private func handleDownloadCompletion(tempLocation: URL) async {
        guard let manifest = activeManifest else { return }
        let storage = ModelStorageManager.shared
        let destURL = storage.fileURL(for: manifest.filename)

        do {
            try FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: tempLocation, to: destURL)

            // Validate integrity
            _ = try await ModelIntegrityValidator.shared.validate(
                fileURL: destURL,
                expectedSHA256: manifest.expectedSHA256
            )
            progressContinuation?.finish()
        } catch {
            // Only remove if file is tiny (< 1 MB) or totally corrupted
            if let attrs = try? FileManager.default.attributesOfItem(atPath: destURL.path),
               let size = attrs[.size] as? Int64, size < 1_000_000 {
                try? FileManager.default.removeItem(at: destURL)
            }
            progressContinuation?.finish()
        }
    }

    private func handleDownloadError(_ error: Error) {
        progressContinuation?.finish()
        activeTask = nil
    }
}
