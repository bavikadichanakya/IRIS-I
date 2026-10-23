//
//  DiagnosticConsoleView.swift
//  IRIS-I
//
//  Phase 2 Diagnostic Screen exposing model lifecycle, installed profiles,
//  import/download progress, context scaling, streaming playground, and benchmark suite.
//

import SwiftUI

public struct DiagnosticConsoleView: View {
    @State private var runnerState: ModelLifecycleState = .uninstalled
    @State private var activeManifest: ModelManifest?
    @State private var activeContextSize: Int = 2048

    @State private var memoryTelemetry: MemoryTelemetry = HardwareTelemetry.shared.currentMemoryUsage()
    @State private var inferenceTelemetry: InferenceTelemetry = .zero
    @State private var thermalStateStr: String = HardwareTelemetry.shared.thermalDescription

    @State private var promptText: String = "Remind me to check the server logs tomorrow at 9 AM."
    @State private var streamingOutput: String = ""
    @State private var isGenerating: Bool = false

    @State private var importTargetManifest: ModelManifest?
    @State private var isShowingFileImporter: Bool = false
    @State private var importProgress: Double = 0.0

    @State private var benchmarkResults: [BenchmarkResult] = []
    @State private var isShowingBenchmarkResults: Bool = false
    @State private var isRunningBenchmarks: Bool = false

    @State private var errorMessage: String?

    private let runner = LocalModelRunner.shared
    private let catalog = ModelCatalog.shared
    private let storage = ModelStorageManager.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Device Banner
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TARGET: iPhone 17 (Apple A19)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Text("Memory Capacity: 8 GB LPDDR5X")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("Zero Cloud Sync")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                    .padding(.horizontal)

                    // 2. Hardware Telemetry Bar
                    TelemetryBarView(
                        telemetry: inferenceTelemetry,
                        memory: memoryTelemetry,
                        thermalState: thermalStateStr
                    )
                    .padding(.horizontal)

                    // 3. Engine Status & Context Size Selector
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Model Lifecycle:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(runnerState.displayTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        if importProgress > 0 && importProgress < 1.0 {
                            ProgressView(value: importProgress)
                                .progressViewStyle(.linear)
                        }

                        Divider()

                        HStack {
                            Text("Context Size:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Context Size", selection: $activeContextSize) {
                                Text("2048 (Base)").tag(2048)
                                Text("3072").tag(3072)
                                Text("4096 (Max)").tag(4096)
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 220)
                            .onChange(of: activeContextSize) { _, newCtx in
                                Task {
                                    if let active = activeManifest {
                                        await loadModel(manifest: active, contextSize: newCtx, forceMock: false)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // 4. Model Profiles Catalog
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AVAILABLE MODEL PROFILES")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        ForEach(catalog.allProfiles) { manifest in
                            ModelProfileCard(
                                manifest: manifest,
                                isInstalled: storage.isModelInstalled(manifest),
                                isActive: activeManifest?.id == manifest.id,
                                fileSizeMB: storage.fileSize(for: manifest).map { Double($0) / (1024 * 1024) },
                                onSelectLoad: {
                                    Task {
                                        let fileExists = storage.isModelInstalled(manifest)
                                        await loadModel(manifest: manifest, contextSize: activeContextSize, forceMock: !fileExists)
                                    }
                                },
                                onUnload: {
                                    Task {
                                        await runner.unloadModel()
                                        await refreshState()
                                    }
                                },
                                onImportTapped: {
                                    self.importTargetManifest = manifest
                                    self.isShowingFileImporter = true
                                },
                                onDeleteTapped: {
                                    try? storage.deleteModel(manifest)
                                    Task { await refreshState() }
                                }
                            )
                            .padding(.horizontal)
                        }
                    }

                    // 5. Live Streaming Playground
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LOCAL INFERENCE PLAYGROUND")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)

                        TextField("Enter prompt...", text: $promptText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)

                        HStack(spacing: 10) {
                            Button(action: runInference) {
                                Label(isGenerating ? "Generating..." : "Generate", systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isGenerating || !runnerState.isLoaded)

                            if isGenerating {
                                Button(action: cancelInference) {
                                    Label("Cancel", systemImage: "xmark.circle.fill")
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }

                        if !streamingOutput.isEmpty {
                            Text("Output Stream:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ScrollView {
                                Text(streamingOutput)
                                    .font(.system(.footnote, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(8)
                            }
                            .frame(maxHeight: 180)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // 6. Benchmark Suite Trigger
                    VStack(spacing: 8) {
                        Button(action: runBenchmarkSuite) {
                            HStack {
                                Image(systemName: "gauge.with.needle.fill")
                                Text(isRunningBenchmarks ? "Running Benchmark Suite..." : "Run Phase 2 Benchmark Suite (TC-1 to TC-5)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .disabled(isRunningBenchmarks || isGenerating)

                        Text("Validates tool selection, schema accuracy, cancellation, and security gate.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("IRIS-I Diagnostic")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .sheet(isPresented: $isShowingBenchmarkResults) {
                BenchmarkResultsView(results: benchmarkResults)
            }
            .task {
                await refreshState()
                // Periodic telemetry poller
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    self.memoryTelemetry = HardwareTelemetry.shared.currentMemoryUsage()
                    self.thermalStateStr = HardwareTelemetry.shared.thermalDescription
                }
            }
        }
    }

    // MARK: - Actions

    private func refreshState() async {
        self.runnerState = await runner.state
        self.activeManifest = await runner.currentManifest
        self.inferenceTelemetry = await runner.latestTelemetry()
        self.memoryTelemetry = HardwareTelemetry.shared.currentMemoryUsage()
    }

    private func loadModel(manifest: ModelManifest, contextSize: Int, forceMock: Bool) async {
        do {
            try await runner.loadModel(
                manifest: manifest,
                contextSize: contextSize,
                forceMockEngine: forceMock
            )
            await refreshState()
        } catch {
            self.errorMessage = error.localizedDescription
            await refreshState()
        }
    }

    private func runInference() {
        guard !promptText.isEmpty else { return }
        self.isGenerating = true
        self.streamingOutput = ""

        Task {
            let stream = await runner.generateStream(prompt: promptText, maxTokens: 256, temperature: 0.7)
            do {
                for try await token in stream {
                    self.streamingOutput += token
                }
            } catch {
                self.streamingOutput += "\n[Error: \(error.localizedDescription)]"
            }
            self.isGenerating = false
            await refreshState()
        }
    }

    private func cancelInference() {
        Task {
            await runner.cancelGeneration()
            self.isGenerating = false
            await refreshState()
        }
    }

    private func runBenchmarkSuite() {
        self.isRunningBenchmarks = true
        Task {
            // Auto-load baseline if nothing loaded
            if !(await runner.isModelLoaded) {
                let isInstalled = storage.isModelInstalled(catalog.baseline3B)
                try? await runner.loadModel(manifest: catalog.baseline3B, contextSize: 2048, forceMockEngine: !isInstalled)
            }

            let results = await BenchmarkRunner.shared.runSuite(runner: runner)
            self.benchmarkResults = results
            self.isRunningBenchmarks = false
            self.isShowingBenchmarkResults = true
            await refreshState()
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let selectedURL = urls.first, let manifest = importTargetManifest else { return }

        Task {
            do {
                self.importProgress = 0.05
                _ = try await storage.importLocalModel(
                    from: selectedURL,
                    manifest: manifest,
                    progressHandler: { p in
                        self.importProgress = p
                    }
                )
                self.importProgress = 1.0
                await refreshState()
            } catch {
                self.errorMessage = "Import failed: \(error.localizedDescription)"
                self.importProgress = 0.0
            }
        }
    }
}
