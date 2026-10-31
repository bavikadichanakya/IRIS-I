//
//  QuickDrawerMenuSubsectionView.swift
//  IRIS-I
//
//  Subsection: Quick Assistant Drawer & Diagnostic Hub.
//  Accessible via the hamburger menu icon (line.3.horizontal)
//  on VoiceAgentView and AssistantChatView.
//

import SwiftUI

public struct QuickDrawerMenuSubsectionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingDiagnostics: Bool = false
    @State private var isShowingShortcuts: Bool = false
    @State private var isShowingVoiceSettings: Bool = false
    @State private var isShowingWakeWord: Bool = false
    @State private var isShowingAppearance: Bool = false
    @State private var isShowingLanguage: Bool = false
    @State private var isShowingGmail: Bool = false
    @State private var selectedVoice: String = "IRIS (Default)"
    @State private var quickActionBanner: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Top Assistant Profile Card
                    HStack(spacing: 14) {
                        PearlOrbView(size: 48)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("IRIS Assistant")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                            Text("Qwen 2.5 3B • Metal Acceleration")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.45))
                        }

                        Spacer()

                        HStack(spacing: 5) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text("Online")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Quick Action Banner
                    if let banner = quickActionBanner {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(banner)
                                .font(.footnote.weight(.medium))
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Navigation Subsections Group 1: Intelligence & Shortcuts
                    VStack(spacing: 0) {
                        drawerRow(
                            icon: "cpu.fill",
                            iconColor: .purple,
                            title: "Neural Engine Diagnostics",
                            subtitle: "View llama.cpp inference logs & memory"
                        ) {
                            isShowingDiagnostics = true
                        }

                        Divider().padding(.leading, 56)

                        drawerRow(
                            icon: "button.programmable",
                            iconColor: .orange,
                            title: "Action Button & Shortcuts",
                            subtitle: "Hardware Action Button setup & intents"
                        ) {
                            isShowingShortcuts = true
                        }

                        Divider().padding(.leading, 56)

                        drawerRow(
                            icon: "envelope.fill",
                            iconColor: .red,
                            title: "Google / Gmail Account",
                            subtitle: "OAuth 2.0 mail & calendar connection"
                        ) {
                            isShowingGmail = true
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Navigation Subsections Group 2: Audio & System
                    VStack(spacing: 0) {
                        drawerRow(
                            icon: "speaker.wave.2.fill",
                            iconColor: .blue,
                            title: "Voice & Speech Synthesis",
                            subtitle: "Voice pitch, rate, and audio routing"
                        ) {
                            isShowingVoiceSettings = true
                        }

                        Divider().padding(.leading, 56)

                        drawerRow(
                            icon: "waveform.circle.fill",
                            iconColor: .indigo,
                            title: "Wake Word Detection",
                            subtitle: "Acoustic sensitivity & phrase config"
                        ) {
                            isShowingWakeWord = true
                        }

                        Divider().padding(.leading, 56)

                        drawerRow(
                            icon: "paintbrush.fill",
                            iconColor: .cyan,
                            title: "Appearance & Theme",
                            subtitle: "Liquid glass finishes & accent colors"
                        ) {
                            isShowingAppearance = true
                        }

                        Divider().padding(.leading, 56)

                        drawerRow(
                            icon: "globe",
                            iconColor: .teal,
                            title: "Language & Recognition",
                            subtitle: "Speech locales & offline dictation"
                        ) {
                            isShowingLanguage = true
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Quick Management Actions
                    VStack(spacing: 12) {
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            SpeechManager.shared.cancelSpeech()
                            withAnimation {
                                quickActionBanner = "Voice session reset successfully."
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation { quickActionBanner = nil }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset Active Voice Session")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(white: 0.94))
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }

                        Button {
                            #if canImport(UIKit)
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                            #endif
                        } label: {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open iOS System Permissions")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.10))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                    }

                    // Build Footer
                    VStack(spacing: 4) {
                        Text("IRIS Intelligence Assistant • v1.0 (74)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(white: 0.50))
                        Text("Apple A19 Pro • Metal Performance Shaders • Native Liquid Glass")
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.60))
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
            .navigationTitle("Assistant Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingDiagnostics) {
                DiagnosticConsoleView()
            }
            .sheet(isPresented: $isShowingShortcuts) {
                NavigationStack {
                    ShortcutsSettingsSubsectionView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { isShowingShortcuts = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $isShowingVoiceSettings) {
                NavigationStack {
                    VoiceSettingsSubsectionView(selectedVoice: $selectedVoice)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { isShowingVoiceSettings = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $isShowingWakeWord) {
                NavigationStack {
                    WakeWordSettingsSubsectionView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { isShowingWakeWord = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $isShowingAppearance) {
                NavigationStack {
                    AppearanceSettingsSubsectionView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { isShowingAppearance = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $isShowingLanguage) {
                NavigationStack {
                    LanguageSettingsSubsectionView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { isShowingLanguage = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $isShowingGmail) {
                NavigationStack {
                    GmailConnectionView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { isShowingGmail = false }
                            }
                        }
                }
            }
        }
    }

    private func drawerRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.45))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(white: 0.65))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
