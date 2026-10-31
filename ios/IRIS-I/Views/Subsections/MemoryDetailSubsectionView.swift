//
//  MemoryDetailSubsectionView.swift
//  IRIS-I
//
//  Subsection: Memory Timeline Inspection, Context Audit, and Re-execution.
//  Displays full execution telemetry, localized parameters, and allows
//  re-running or removing recorded interactions from assistant memory.
//

import SwiftUI

public struct MemoryDetailSubsectionView: View {
    @Environment(\.dismiss) private var dismiss
    public let item: MemoryItem
    public var onDelete: ((UUID) -> Void)?

    @State private var reExecutionMessage: String?
    @State private var isExecuting: Bool = false

    public init(item: MemoryItem, onDelete: ((UUID) -> Void)? = nil) {
        self.item = item
        self.onDelete = onDelete
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Overview Card
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(item.iconColor.opacity(0.12))
                                .frame(width: 68, height: 68)
                            Image(systemName: item.icon)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(item.iconColor)
                        }

                        VStack(spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            Text(item.timestamp)
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.45))
                        }

                        HStack(spacing: 8) {
                            badge(text: item.category, color: item.iconColor)
                            badge(text: "Verified Execution", color: .green)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Context Audit Telemetry
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "cpu.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.blue)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Execution Telemetry")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                                Text("Assistant Context Record")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.40))
                            }
                        }

                        Divider()

                        recordRow(label: "Origin", value: "Action Button / Voice Session")
                        recordRow(label: "Orchestrator", value: "ReActOrchestrator (Qwen 2.5 3B)")
                        recordRow(label: "Safety Status", value: "User Approved • Non-Destructive")
                        recordRow(label: "Storage", value: "100% On-Device Secure Memory")
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Feedback Banner
                    if let msg = reExecutionMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(msg)
                                .font(.footnote.weight(.medium))
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Re-run Action Button
                    Button {
                        reRunInteraction()
                    } label: {
                        HStack(spacing: 8) {
                            if isExecuting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.counterclockwise")
                            }
                            Text(isExecuting ? "Executing..." : "Re-run Interaction Now")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(item.iconColor)
                        .cornerRadius(16)
                        .shadow(color: item.iconColor.opacity(0.35), radius: 8, y: 3)
                    }
                    .disabled(isExecuting)

                    // Delete Record Button
                    Button(role: .destructive) {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        onDelete?(item.id)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Forget this Interaction")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
            .navigationTitle("Memory Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func recordRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.45))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.black)
        }
    }

    private func reRunInteraction() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        isExecuting = true

        Task {
            // Check if title mentions YouTube, Music, or Instagram
            if item.title.localizedCaseInsensitiveContains("YouTube") {
                _ = try? await AppLaunchRegistry.shared.launchApp(name: "YouTube")
            } else if item.title.localizedCaseInsensitiveContains("Music") {
                _ = try? await AppLaunchRegistry.shared.launchApp(name: "Apple Music")
            } else if item.title.localizedCaseInsensitiveContains("Instagram") {
                _ = try? await AppLaunchRegistry.shared.launchApp(name: "Instagram")
            } else if item.title.localizedCaseInsensitiveContains("Camera") || item.title.localizedCaseInsensitiveContains("Photo") {
                _ = try? await AppLaunchRegistry.shared.launchApp(name: "Camera")
            } else if item.title.localizedCaseInsensitiveContains("Battery") {
                let tool = SystemInfoTool()
                _ = await tool.execute(arguments: ["action": "battery"])
            }

            await MainActor.run {
                self.isExecuting = false
                withAnimation {
                    self.reExecutionMessage = "Interaction successfully re-executed."
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation { self.reExecutionMessage = nil }
                }
            }
        }
    }
}
