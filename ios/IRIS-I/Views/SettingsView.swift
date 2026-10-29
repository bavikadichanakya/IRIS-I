//
//  SettingsView.swift
//  IRIS-I
//
//  Application settings, model residency introspection, and account connections.
//

import SwiftUI

public struct SettingsView: View {
    @State private var activeManifest: ModelManifest?
    @State private var runnerState: ModelLifecycleState = .uninstalled

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Account Connectors")) {
                    GmailConnectionView()
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowBackground(Color.clear)
                }

                Section(header: Text("Security & Confirmation Gates")) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send Actions")
                                .font(.subheadline)
                            Text("Requires single-use cryptographic approval")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("Enforced")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "trash.slash.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Destructive Operations")
                                .font(.subheadline)
                            Text("Strict ticket verification with parameter hashing")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("Enforced")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Local Intelligence Configuration")) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Configured Baseline Profile")
                                .font(.subheadline)
                            Text("Qwen 2.5 3B Instruct (ChatML / Q4_K_M)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("A19 Pinned")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "memorychip")
                            .foregroundColor(activeManifest != nil ? .green : .gray)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Active Memory Residency")
                                .font(.subheadline)
                            if let manifest = activeManifest {
                                Text("\(manifest.displayName) (\(manifest.quantization))")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            } else {
                                Text("No model loaded (Standby / Cold)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if activeManifest != nil {
                            Text("Loaded")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                        } else {
                            Text("Cold")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.15))
                                .foregroundColor(.secondary)
                                .cornerRadius(6)
                        }
                    }

                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fast Intent Dispatch")
                                .font(.subheadline)
                            Text("Sub-10ms deterministic system routing")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("<10 ms")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                let manifest = await LocalModelRunner.shared.currentManifest
                let state = await LocalModelRunner.shared.state
                await MainActor.run {
                    self.activeManifest = manifest
                    self.runnerState = state
                }
            }
        }
    }
}
