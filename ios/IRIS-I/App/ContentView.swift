//
//  ContentView.swift
//  IRIS-I
//
//  Root view hosting the standalone IRIS Assistant with Apple-level Liquid Glass UI.
//

import SwiftUI

public enum MainTabSection: Hashable, CaseIterable {
    case voice
    case chat
    case diagnostics
    case settings
}

public struct ContentView: View {
    @State private var selectedTab: MainTabSection = .voice

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .voice:
                    VoiceAgentView()
                case .chat:
                    AssistantChatView()
                case .diagnostics:
                    DiagnosticConsoleView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Apple-Level Liquid Glass Floating Tab Bar
            GlassTabBar(selection: $selectedTab) {
                GlassTab("Voice", systemImage: "waveform.circle", value: MainTabSection.voice)
                GlassTab("Chat", systemImage: "bubble.left.and.bubble.right", value: MainTabSection.chat)
                GlassTab("Diagnostics", systemImage: "waveform.path.ecg", value: MainTabSection.diagnostics)
                GlassTab("Settings", systemImage: "gearshape", value: MainTabSection.settings)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .glassTheme(.standard)
    }
}

#Preview {
    ContentView()
}
