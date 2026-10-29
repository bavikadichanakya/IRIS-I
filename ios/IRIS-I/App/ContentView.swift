//
//  ContentView.swift
//  IRIS-I
//
//  Root view hosting the standalone IRIS Assistant and the Diagnostic Console.
//

import SwiftUI

public struct ContentView: View {
    public init() {}

    public var body: some View {
        TabView {
            VoiceAgentView()
                .tabItem {
                    Label("Voice", systemImage: "waveform.circle.fill")
                }

            AssistantChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }

            DiagnosticConsoleView()
                .tabItem {
                    Label("Diagnostics", systemImage: "waveform.path.ecg")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
}
