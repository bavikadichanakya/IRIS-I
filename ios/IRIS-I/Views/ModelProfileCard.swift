//
//  ModelProfileCard.swift
//  IRIS-I
//
//  Interactive UI card representing a model profile with controls for loading,
//  unloading, 1-tap downloading, local import, and deletion.
//

import SwiftUI

public struct ModelProfileCard: View {
    public let manifest: ModelManifest
    public let isInstalled: Bool
    public let isActive: Bool
    public let fileSizeMB: Double?
    public let onSelectLoad: () -> Void
    public let onUnload: () -> Void
    public let onImportTapped: () -> Void
    public let onDeleteTapped: () -> Void
    public let onDownloadTapped: (() -> Void)?

    @ObservedObject private var brainCoordinator = BrainDownloadCoordinator.shared

    public init(
        manifest: ModelManifest,
        isInstalled: Bool,
        isActive: Bool,
        fileSizeMB: Double?,
        onSelectLoad: @escaping () -> Void,
        onUnload: @escaping () -> Void,
        onImportTapped: @escaping () -> Void,
        onDeleteTapped: @escaping () -> Void,
        onDownloadTapped: (() -> Void)? = nil
    ) {
        self.manifest = manifest
        self.isInstalled = isInstalled
        self.isActive = isActive
        self.fileSizeMB = fileSizeMB
        self.onSelectLoad = onSelectLoad
        self.onUnload = onUnload
        self.onImportTapped = onImportTapped
        self.onDeleteTapped = onDeleteTapped
        self.onDownloadTapped = onDownloadTapped
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(manifest.displayName)
                            .font(.headline)
                        if manifest.isExperimental {
                            Text("EXPERIMENTAL")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        } else {
                            Text("BASELINE")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }

                    Text("\(manifest.parameterScale.rawValue) • \(manifest.quantization) • Default Ctx: \(manifest.defaultContextSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status Badge
                if isActive {
                    Text("ACTIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(6)
                } else if isInstalled {
                    Text("INSTALLED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(6)
                } else {
                    Text("NOT INSTALLED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            Text(manifest.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            if let size = fileSizeMB {
                Text(String(format: "Installed file size: %.1f MB", size))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Live Download Progress Bar (if this model is downloading)
            if brainCoordinator.isDownloading && manifest.verifiedDownloadURL != nil {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: brainCoordinator.downloadProgress)
                        .tint(.blue)
                    HStack {
                        Text(brainCoordinator.statusMessage)
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Spacer()
                        Button("Cancel") {
                            brainCoordinator.cancelDownload()
                        }
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 4)
            }

            // Action Buttons
            HStack(spacing: 10) {
                if isActive {
                    Button(action: onUnload) {
                        Label("Unload", systemImage: "eject.fill")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else if isInstalled {
                    Button(action: onSelectLoad) {
                        Label("Load Engine", systemImage: "play.fill")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button(role: .destructive, action: onDeleteTapped) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                } else {
                    if let download = onDownloadTapped, manifest.verifiedDownloadURL != nil {
                        Button(action: download) {
                            Label("Download & Activate", systemImage: "arrow.down.circle.fill")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)

                        Button(action: onImportTapped) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(action: onImportTapped) {
                            Label("Import .GGUF File", systemImage: "square.and.arrow.down")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }
}
