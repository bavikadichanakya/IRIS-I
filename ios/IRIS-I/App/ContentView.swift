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
            AssistantChatView()
                .tabItem {
                    Label("Assistant", systemImage: "sparkles")
                }

            DiagnosticConsoleView()
                .tabItem {
                    Label("Diagnostics", systemImage: "waveform.path.ecg")
                }
        }
    }
}

#Preview {
    ContentView()
}
