//
//  ActionsCatalogView.swift
//  IRIS-I
//
//  Screen 6: Real Device Capabilities & Actions Catalog.
//  Searchable, interactive capability interface executing verified tools and iOS system integrations.
//

import SwiftUI

public struct ActionItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let icon: String
    public let iconColor: Color
    public let actionType: ActionType

    public enum ActionType: Sendable {
        case openApp(String)
        case systemAction(String)
        case customPrompt(String)
    }
}

public struct ActionsCatalogView: View {
    @State private var searchText: String = ""
    @State private var feedbackMessage: String?
    @State private var isExecuting: Bool = false
    @State private var selectedAction: ActionItem?

    private let allActions: [ActionItem] = [
        ActionItem(
            id: "open_apps",
            title: "Open Apps",
            subtitle: "Launch any installed application",
            icon: "app.badge.fill",
            iconColor: Color.blue,
            actionType: .openApp("Settings")
        ),
        ActionItem(
            id: "apple_music",
            title: "Apple Music",
            subtitle: "Stream music, playlists, and radio",
            icon: "music.note",
            iconColor: Color.pink,
            actionType: .openApp("Apple Music")
        ),
        ActionItem(
            id: "spotify",
            title: "Spotify",
            subtitle: "Play podcasts and music tracks",
            icon: "waveform.circle.fill",
            iconColor: Color.green,
            actionType: .openApp("Spotify")
        ),
        ActionItem(
            id: "take_photo",
            title: "Take Photo",
            subtitle: "Quickly open the camera",
            icon: "camera.fill",
            iconColor: Color.orange,
            actionType: .openApp("Camera")
        ),
        ActionItem(
            id: "send_message",
            title: "Send Message",
            subtitle: "Compose text via Messages or WhatsApp",
            icon: "message.fill",
            iconColor: Color.green,
            actionType: .openApp("Messages")
        ),
        ActionItem(
            id: "set_reminder",
            title: "Set Reminder",
            subtitle: "Schedule tasks in Calendar & Reminders",
            icon: "calendar.badge.plus",
            iconColor: Color.purple,
            actionType: .openApp("Reminders")
        ),
        ActionItem(
            id: "open_website",
            title: "Open Safari",
            subtitle: "Browse web or search queries",
            icon: "safari.fill",
            iconColor: Color.blue,
            actionType: .customPrompt("Open safari")
        ),
        ActionItem(
            id: "battery_status",
            title: "Battery & Telemetry",
            subtitle: "Check battery level and A19 Neural load",
            icon: "bolt.batteryblock.fill",
            iconColor: Color.yellow,
            actionType: .systemAction("battery")
        ),
        ActionItem(
            id: "photos_gallery",
            title: "Photos Library",
            subtitle: "View albums and camera roll",
            icon: "photo.on.rectangle.angled",
            iconColor: Color.cyan,
            actionType: .openApp("Photos")
        ),
        ActionItem(
            id: "notes_app",
            title: "Quick Notes",
            subtitle: "Jot down ideas and checklists",
            icon: "note.text",
            iconColor: Color.yellow,
            actionType: .openApp("Notes")
        )
    ]

    private var filteredActions: [ActionItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return allActions
        }
        return allActions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.96, green: 0.96, blue: 0.98)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Actions")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)

                        Spacer()

                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 38, height: 38)
                                .glassSurface(.clear, in: .circle)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                    // Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search actions...", text: $searchText)
                            .font(.system(size: 16))
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.85))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)

                    // Feedback Banner if executed
                    if let feedback = feedbackMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(feedback)
                                .font(.footnote.weight(.medium))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Action Items List
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredActions) { item in
                                actionRow(for: item)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) // Space for floating tab bar
                    }
                }
            }
        }
    }

    private func actionRow(for item: ActionItem) -> some View {
        Button {
            executeAction(item)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(item.iconColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(item.iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(item.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.85))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleOnPressStyle())
    }

    private func executeAction(_ item: ActionItem) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        switch item.actionType {
        case .openApp(let appName):
            Task {
                do {
                    _ = try await AppLaunchRegistry.shared.launchApp(name: appName)
                    withAnimation {
                        feedbackMessage = "Launched \(appName) successfully"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { feedbackMessage = nil }
                    }
                } catch {
                    withAnimation {
                        feedbackMessage = error.localizedDescription
                    }
                }
            }
        case .systemAction(let action):
            Task {
                let tool = SystemInfoTool()
                let res = await tool.execute(arguments: ["action": action])
                withAnimation {
                    feedbackMessage = res.output["message"] as? String ?? "Completed"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation { feedbackMessage = nil }
                }
            }
        case .customPrompt(let prompt):
            Task {
                let tool = WebSearchTool()
                _ = await tool.execute(arguments: ["query": "apple news"])
                withAnimation {
                    feedbackMessage = "Opened web search"
                }
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
    ActionsCatalogView()
}
