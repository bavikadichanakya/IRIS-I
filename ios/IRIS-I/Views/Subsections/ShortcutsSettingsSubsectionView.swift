//
//  ShortcutsSettingsSubsectionView.swift
//  IRIS-I
//
//  Subsection: Action Button, Siri Shortcuts & App Intents Guide.
//  Provides interactive snippet preview, step-by-step Action Button setup,
//  registered App Intents documentation, and direct Shortcuts launch.
//

import SwiftUI
import AppIntents

public struct ShortcutsSettingsSubsectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSimulatingSnippet: Bool = false
    @State private var simulationText: String = "Listening..."
    @State private var feedbackBanner: String?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Interactive Preview Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.pink)
                        Text("Live Island & Action Snippet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Interactive")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.pink.opacity(0.12))
                            .foregroundColor(.pink)
                            .clipShape(Capsule())
                    }

                    IRISShortcutSnippetView(
                        statusText: simulationText,
                        isListening: isSimulatingSnippet,
                        recognizedText: isSimulatingSnippet ? "Open YouTube" : ""
                    )
                    .padding(.vertical, 4)

                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        withAnimation {
                            isSimulatingSnippet.toggle()
                            simulationText = isSimulatingSnippet ? "Processing: Open YouTube..." : "Listening..."
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: isSimulatingSnippet ? "stop.fill" : "play.fill")
                            Text(isSimulatingSnippet ? "Reset Simulation" : "Simulate Action Button Trigger")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(10)
                        .foregroundColor(.primary)
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                // Action Button Setup Guide
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "button.programmable")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Action Button Configuration")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            Text("iPhone 15 Pro & iPhone 16 Pro Series")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.40))
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        guideStepRow(
                            step: 1,
                            title: "Open iOS Settings",
                            detail: "Go to Settings → Action Button on your iPhone."
                        )
                        guideStepRow(
                            step: 2,
                            title: "Select Shortcut Option",
                            detail: "Swipe horizontally until you reach the 'Shortcut' card."
                        )
                        guideStepRow(
                            step: 3,
                            title: "Choose IRIS",
                            detail: "Tap the shortcut selector and select 'IRIS' or 'Start Listening'."
                        )
                        guideStepRow(
                            step: 4,
                            title: "One-Press Activation",
                            detail: "Press and hold the Action Button anytime to launch IRIS with Dynamic Island."
                        )
                    }

                    Button {
                        #if canImport(UIKit)
                        if let url = URL(string: "shortcuts://") {
                            UIApplication.shared.open(url)
                        }
                        #endif
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.forward.app")
                            Text("Open Apple Shortcuts App")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.pink.opacity(0.12))
                        .foregroundColor(.pink)
                        .cornerRadius(12)
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                // Available App Intents
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Registered App Intents")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            Text("Available in Siri & Spotlight")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.40))
                        }
                    }

                    Divider()

                    intentRow(
                        name: "StartListeningIntent",
                        description: "Starts a voice session with Dynamic Island pill.",
                        badge: "Action Button",
                        color: .orange
                    )

                    Divider()

                    intentRow(
                        name: "AskIRISIntent",
                        description: "Spoken query to IRIS via Siri with immediate TTS response.",
                        badge: "Siri Voice",
                        color: .blue
                    )

                    Divider()

                    intentRow(
                        name: "AskIRISWithTextIntent",
                        description: "Automate text queries and pipeline output to other shortcuts.",
                        badge: "Automation",
                        color: .purple
                    )
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
        .navigationTitle("Shortcuts & Intents")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideStepRow(step: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.orange))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.45))
            }
        }
    }

    private func intentRow(name: String, description: String, badge: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.black)
                Spacer()
                Text(badge)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .foregroundColor(color)
                    .clipShape(Capsule())
            }
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.45))
        }
    }
}
