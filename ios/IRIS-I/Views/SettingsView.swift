//
//  SettingsView.swift
//  IRIS-I
//
//  Application settings and account connection screen.
//

import SwiftUI

public struct SettingsView: View {
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

                Section(header: Text("Local Intelligence")) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Model")
                                .font(.subheadline)
                            Text("SmolLM3-3B (On-Device via Apple Silicon Metal)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
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
        }
    }
}
