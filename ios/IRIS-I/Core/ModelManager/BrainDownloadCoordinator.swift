//
//  BrainDownloadCoordinator.swift
//  IRIS-I
//
//  Central observable coordinator enabling 1-tap download and automatic activation
//  of the local on-device neural brain (Qwen 2.5 3B GGUF) directly on the physical iPhone.
//

import Foundation
import Combine

@MainActor
public final class BrainDownloadCoordinator: ObservableObject {
    public static let shared = BrainDownloadCoordinator()

    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0 // 0.0 to 1.0
    @Published public var downloadSpeedMBs: Double = 0.0
    @Published public var statusMessage: String = "Ready"
    @Published public var isModelInstalled: Bool = false
    @Published public var isModelActive: Bool = false

    private let catalog = ModelCatalog.shared
    private let storage = ModelStorageManager.shared
    private let runner = LocalModelRunner.shared
    private let downloadManager = ModelDownloadManager.shared

    private var downloadTask: Task<Void, Never>?

    private init() {
        self.isModelInstalled = storage.isModelInstalled(catalog.baseline3B)
        Task { @MainActor in
            await self.refreshStateAsync()
        }
    }

    public func refreshState() {
        self.isModelInstalled = storage.isModelInstalled(catalog.baseline3B)
        Task { @MainActor in
            await self.refreshStateAsync()
        }
    }

    public func refreshStateAsync() async {
        self.isModelInstalled = storage.isModelInstalled(catalog.baseline3B)
        let loaded = await runner.isModelLoaded
        let isMock = await runner.isUsingMockEngine
        self.isModelActive = loaded && !isMock
        if isModelActive {
            self.statusMessage = "Brain Active (100% On-Device · Metal)"
        } else if isModelInstalled {
            self.statusMessage = "Model downloaded · Ready to activate"
        } else if !isDownloading {
            self.statusMessage = "No local brain downloaded (1.95 GB)"
        }
    }

    /// One-tap action: downloads the baseline GGUF model and immediately auto-activates it into memory.
    public func downloadAndActivateBrain() {
        let manifest = catalog.baseline3B

        // If already installed, directly activate
        if storage.isModelInstalled(manifest) {
            activateInstalledBrain(manifest: manifest)
            return
        }

        guard let downloadURL = manifest.verifiedDownloadURL else {
            self.statusMessage = "Error: Verified download URL unavailable"
            return
        }

        self.isDownloading = true
        self.downloadProgress = 0.0
        self.downloadSpeedMBs = 0.0
        self.statusMessage = "Connecting to model repository..."

        downloadTask?.cancel()
        downloadTask = Task {
            let stream = await downloadManager.startDownload(manifest: manifest, from: downloadURL)
            for await snapshot in stream {
                guard !Task.isCancelled else { break }
                self.downloadProgress = snapshot.progress
                self.downloadSpeedMBs = snapshot.speedMBs
                let percent = Int(snapshot.progress * 100)
                let speedStr = String(format: "%.1f", snapshot.speedMBs)
                let downloadedMB = Double(snapshot.bytesWritten) / (1024 * 1024)
                let totalMB = Double(snapshot.totalBytes) / (1024 * 1024)
                self.statusMessage = "Downloading: \(percent)% (\(speedStr) MB/s · \(Int(downloadedMB))/\(Int(totalMB)) MB)"
            }

            guard !Task.isCancelled else {
                self.isDownloading = false
                self.statusMessage = "Download stopped"
                return
            }

            // Verify installation on disk
            self.isDownloading = false
            await self.refreshStateAsync()

            if storage.isModelInstalled(manifest) {
                self.statusMessage = "Download complete! Activating neural brain..."
                self.activateInstalledBrain(manifest: manifest)
            } else {
                self.statusMessage = "Download completed but file verification failed."
            }
        }
    }

    /// Loads the on-disk GGUF model into unified RAM and marks it active
    public func activateInstalledBrain(manifest: ModelManifest) {
        Task {
            do {
                self.statusMessage = "Loading Qwen 2.5 3B into Metal unified memory..."
                try await runner.loadModel(manifest: manifest, contextSize: 2048, forceMockEngine: false)
                await self.refreshStateAsync()
                self.statusMessage = "Neural Brain Active (100% On-Device · A19)"
                SpeechManager.shared.speak(text: "Local neural brain downloaded and activated. I'm ready.")
            } catch {
                self.statusMessage = "Engine activation error: \(error.localizedDescription)"
            }
        }
    }

    /// Stops any active model download
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        Task {
            await downloadManager.cancelDownload()
        }
        self.isDownloading = false
        self.statusMessage = "Download cancelled"
    }

    /// Unloads the active model
    public func unloadBrain() {
        Task {
            await runner.unloadModel()
            await self.refreshStateAsync()
            self.statusMessage = "Brain unloaded"
        }
    }
}
