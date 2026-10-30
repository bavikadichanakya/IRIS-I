//
//  ContentView.swift
//  IRIS-I
//
//  Root view hosting the complete 5-screen IRIS assistant matching the design blueprint:
//  [Chat] [Actions] [(●) Home] [Memory] [Settings]
//

import SwiftUI

public enum MainTabSection: Hashable, CaseIterable {
    case chat
    case actions
    case home
    case memory
    case settings
}

public struct ContentView: View {
    @State private var selectedTab: MainTabSection = .home
    @StateObject private var speechManager = SpeechManager.shared

    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            // Main Tab Content Area
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case .chat:
                        AssistantChatView()
                    case .actions:
                        ActionsCatalogView()
                    case .home:
                        VoiceAgentView()
                    case .memory:
                        MemoryView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Apple-Level Liquid Glass Floating Tab Bar (5 Tabs)
                GlassTabBar(selection: $selectedTab) {
                    GlassTab("Chat", systemImage: "bubble.left.and.bubble.right", value: MainTabSection.chat)
                    GlassTab("Actions", systemImage: "square.grid.2x2", value: MainTabSection.actions)
                    GlassTab("Home", systemImage: "sparkles", value: MainTabSection.home)
                    GlassTab("Memory", systemImage: "clock.arrow.circlepath", value: MainTabSection.memory)
                    GlassTab("Settings", systemImage: "gearshape", value: MainTabSection.settings)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            // Top Hardware Dynamic Island Floating Pill
            DynamicIslandPillView()
                .padding(.top, 11)
                .ignoresSafeArea(edges: .top)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .glassTheme(.standard)
        .preferredColorScheme(.light)
        .onAppear {
            Task {
                await speechManager.startListening()
            }
        }
    }
}

#Preview {
    ContentView()
}
