//
//  SettingsView.swift
//  IRIS-I
//
//  Screen 8: Settings & Customization matching design blueprint.
//  Includes Neural Brain model status card, Voice, Wake Word, Background Mode,
//  Siri Shortcuts, and Diagnostics introspection sheet.
//

import SwiftUI

public struct SettingsView: View {
    @StateObject private var brainCoordinator = BrainDownloadCoordinator.shared
    @StateObject private var speechManager = SpeechManager.shared

    @State private var isShowingDiagnostics: Bool = false
    @State private var isShowingGmailConnector: Bool = false
    @State private var gmailStatus: String = "Configure"
    @State private var selectedVoice: String = "IRIS (Default)"
    @State private var isConfirmationMode: Bool = true
    @State private var isBackgroundMode: Bool = true

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Clean Canvas
                Color(red: 0.96, green: 0.96, blue: 0.98)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                    ScrollView {
                        VStack(spacing: 16) {
                            // Top Neural Brain Card matching Screen 8
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                isShowingDiagnostics = true
                            } label: {
                                HStack(spacing: 14) {
                                    PearlOrbView(size: 46)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("IRIS")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.black)
                                        Text(brainCoordinator.isModelActive ? "Qwen 2.5 3B (A19 Metal)" : "Tap to manage brain")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(white: 0.40))
                                    }

                                    Spacer()

                                    HStack(spacing: 5) {
                                        if brainCoordinator.isModelActive {
                                            Circle().fill(Color.green).frame(width: 8, height: 8)
                                            Text("Active")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.green)
                                        } else if brainCoordinator.isDownloading {
                                            Circle().fill(Color.blue).frame(width: 8, height: 8)
                                            Text("Downloading")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.blue)
                                        } else if brainCoordinator.isModelInstalled {
                                            Circle().fill(Color.orange).frame(width: 8, height: 8)
                                            Text("Installed")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.orange)
                                        } else {
                                            Circle().fill(Color.secondary).frame(width: 8, height: 8)
                                            Text("Not Installed")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Color(white: 0.50))
                                        }
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(white: 0.60))
                                }
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(18)
                                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                                )
                            }
                            .buttonStyle(ScaleOnPressStyle())

                            // Settings Group 1: Voice & Wake Word
                            VStack(spacing: 0) {
                                settingsRow(
                                    icon: "speaker.wave.2.fill",
                                    iconColor: .blue,
                                    title: "Voice",
                                    value: selectedVoice
                                )
                                Divider().padding(.leading, 52)
                                settingsRow(
                                    icon: "waveform.circle.fill",
                                    iconColor: .purple,
                                    title: "Wake Word",
                                    value: "Hey IRIS"
                                )
                                Divider().padding(.leading, 52)
                                settingsToggleRow(
                                    icon: "shield.lefthalf.filled",
                                    iconColor: .orange,
                                    title: "Action Confirmations",
                                    isOn: $isConfirmationMode
                                )
                            }
                            .background(Color.white.opacity(0.92))
                            .cornerRadius(18)
                            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)

                            // Settings Group 2: System & Background
                            VStack(spacing: 0) {
                                settingsToggleRow(
                                    icon: "antenna.radiowaves.left.and.right",
                                    iconColor: .green,
                                    title: "Background Mode",
                                    isOn: $isBackgroundMode
                                )
                                .onChange(of: isBackgroundMode) { _, enabled in
                                    speechManager.isBackgroundWakeWordEnabled = enabled
                                }
                                Divider().padding(.leading, 52)
                                Button {
                                    #if canImport(UIKit)
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                    #endif
                                } label: {
                                    settingsRow(
                                        icon: "hand.raised.fill",
                                        iconColor: .indigo,
                                        title: "Permissions",
                                        value: "Manage access"
                                    )
                                }
                                Divider().padding(.leading, 52)
                                settingsRow(
                                    icon: "square.2.layers.3d.top.filled",
                                    iconColor: .pink,
                                    title: "Shortcuts",
                                    value: "Siri & App Intents"
                                )
                            }
                            .background(Color.white.opacity(0.92))
                            .cornerRadius(18)
                            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)

                            // Settings Group 3: Appearance & Accounts
                            VStack(spacing: 0) {
                                settingsRow(
                                    icon: "paintbrush.fill",
                                    iconColor: .cyan,
                                    title: "Appearance",
                                    value: "Liquid Glass"
                                )
                                Divider().padding(.leading, 52)
                                settingsRow(
                                    icon: "globe",
                                    iconColor: .blue,
                                    title: "Language",
                                    value: "English (US)"
                                )
                                Divider().padding(.leading, 52)
                                Button {
                                    isShowingGmailConnector = true
                                } label: {
                                    settingsRow(
                                        icon: "envelope.fill",
                                        iconColor: .red,
                                        title: "Google Gmail",
                                        value: gmailStatus
                                    )
                                }
                            }
                            .background(Color.white.opacity(0.92))
                            .cornerRadius(18)
                            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 110) // Space for floating tab bar
                    }
                }
            }
            .task {
                await refreshGmailStatus()
            }
            .onChange(of: isShowingGmailConnector) { _, isShowing in
                if !isShowing {
                    Task { await refreshGmailStatus() }
                }
            }
            .sheet(isPresented: $isShowingDiagnostics) {
                DiagnosticConsoleView()
            }
            .sheet(isPresented: $isShowingGmailConnector) {
                NavigationStack {
                    GmailConnectionView()
                        .navigationTitle("Google Account")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { isShowingGmailConnector = false }
                            }
                        }
                }
            }
        }
    }

    private func settingsRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.black)

            Spacer()

            Text(value)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.40))

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(white: 0.65))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func settingsToggleRow(icon: String, iconColor: Color, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.black)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func refreshGmailStatus() async {
        let state = await GmailConnector.shared.state
        let config = await GmailConnector.shared.oauthConfig
        await MainActor.run {
            switch state {
            case .connected:
                self.gmailStatus = "Connected"
            case .tokenExpired:
                self.gmailStatus = "Expired"
            case .connecting:
                self.gmailStatus = "Connecting..."
            case .disconnected, .error:
                self.gmailStatus = config.isConfigured ? "Not Connected" : "Configure"
            }
        }
    }
}

fileprivate struct ScaleOnPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    SettingsView()
}
