//
//  BenchmarkResultsView.swift
//  IRIS-I
//
//  Sheet presenting the evaluation results for TC-1 through TC-5.
//

import SwiftUI

public struct BenchmarkResultsView: View {
    public let results: [BenchmarkResult]
    @Environment(\.dismiss) private var dismiss

    public init(results: [BenchmarkResult]) {
        self.results = results
    }

    public var allPassed: Bool {
        results.allSatisfy { $0.passed }
    }

    public var isMock: Bool {
        results.first?.isMockEngine ?? false
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(allPassed ? "Suite Passed" : "Issues Detected")
                                .font(.headline)
                                .foregroundColor(allPassed ? .green : .orange)

                            Text(isMock ? "Executed in MOCK SIMULATOR mode" : "Executed on PHYSICAL A19 METAL ENGINE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(isMock ? .orange : .green)
                        }

                        Spacer()

                        Image(systemName: allPassed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(allPassed ? .green : .orange)
                    }
                    .padding(.vertical, 4)
                }

                Section("Scenario Breakdown") {
                    ForEach(results) { res in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(res.scenarioId): \(res.scenarioName)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Spacer()

                                if res.passed {
                                    Text("PASS")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15))
                                        .cornerRadius(4)
                                } else {
                                    Text("FAIL")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }

                            Text("Prompt: \"\(res.prompt)\"")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(res.reason)
                                .font(.caption2)
                                .foregroundColor(res.passed ? .secondary : .red)

                            HStack {
                                Text(String(format: "Latency: %.0f ms", res.durationMs))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "Footprint: %.0f MB", res.memoryMB))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Benchmark Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
