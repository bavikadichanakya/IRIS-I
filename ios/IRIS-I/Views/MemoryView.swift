//
//  MemoryView.swift
//  IRIS-I
//
//  Screen 7: Memory & Context Timeline.
//  Preserves verified interaction history, user preferences, and captured assistant context.
//  Backed by local SQLite PersonalMemoryStore.
//

import SwiftUI

public struct MemoryItem: Identifiable, Sendable {
    public let id: UUID
    public let recordId: String
    public let title: String
    public let timestamp: String
    public let icon: String
    public let iconColor: Color
    public let category: String

    public init(
        id: UUID = UUID(),
        recordId: String = UUID().uuidString,
        title: String,
        timestamp: String,
        icon: String,
        iconColor: Color,
        category: String
    ) {
        self.id = id
        self.recordId = recordId
        self.title = title
        self.timestamp = timestamp
        self.icon = icon
        self.iconColor = iconColor
        self.category = category
    }
}

public struct MemoryView: View {
    @State private var selectedSegment: Int = 0 // 0: Recent, 1: Notes, 2: Preferences
    @State private var selectedMemory: MemoryItem? = nil
    @State private var isShowingAddNote: Bool = false
    private let segments = ["Recent", "Notes", "Preferences"]

    @State private var recentHistory: [MemoryItem] = []
    @State private var notes: [PersonalNoteItem] = []
    @State private var preferences: [PreferenceItem] = []

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
                        Text("Memory")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.black)

                        Spacer()

                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            isShowingAddNote = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                    // Segmented Control
                    HStack(spacing: 6) {
                        ForEach(0..<segments.count, id: \.self) { index in
                            let isSelected = selectedSegment == index
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedSegment = index
                                }
                            } label: {
                                Text(segments[index])
                                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                                    .foregroundColor(isSelected ? .black : Color(white: 0.40))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background {
                                        if isSelected {
                                            Capsule()
                                                .fill(Color.white)
                                                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 1)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.black.opacity(0.04))
                    .cornerRadius(24)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // Content View
                    ScrollView {
                        VStack(spacing: 12) {
                            if selectedSegment == 0 {
                                recentTimelineView
                            } else if selectedSegment == 1 {
                                notesView
                            } else {
                                preferencesView
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) // Floating tab bar buffer
                    }
                }
            }
            .onAppear {
                loadMemoryData()
            }
            .sheet(item: $selectedMemory) { item in
                MemoryDetailSubsectionView(item: item) { idToDelete in
                    PersonalMemoryStore.shared.deleteInteraction(id: item.recordId)
                    recentHistory.removeAll(where: { $0.id == idToDelete })
                }
            }
            .sheet(isPresented: $isShowingAddNote) {
                AddMemoryNoteSubsectionView { newNoteText in
                    _ = PersonalMemoryStore.shared.addNote(
                        title: "Personal Note",
                        content: newNoteText,
                        category: "User Note",
                        importance: 2
                    )
                    loadMemoryData()
                }
            }
        }
    }

    private func loadMemoryData() {
        let interactions = PersonalMemoryStore.shared.recentInteractions(limit: 30)
        self.recentHistory = interactions.map { item in
            let icon: String
            let color: Color
            let tool = item.toolName?.lowercased() ?? ""

            if tool.contains("app") {
                icon = "arrow.up.forward.app.fill"
                color = .purple
            } else if tool.contains("event") || tool.contains("calendar") {
                icon = "calendar"
                color = .red
            } else if tool.contains("remind") {
                icon = "checklist"
                color = .orange
            } else if tool.contains("mail") {
                icon = "envelope.fill"
                color = .blue
            } else if tool.contains("messag") {
                icon = "message.fill"
                color = .green
            } else if tool.contains("contact") || tool.contains("phone") {
                icon = "phone.fill"
                color = .teal
            } else {
                icon = "bubble.left.and.bubble.right.fill"
                color = .indigo
            }

            return MemoryItem(
                id: UUID(),
                recordId: item.id,
                title: item.userRequest,
                timestamp: item.formattedTimestamp,
                icon: icon,
                iconColor: color,
                category: item.toolName ?? "Conversation"
            )
        }

        self.notes = PersonalMemoryStore.shared.allNotes()
        self.preferences = PersonalMemoryStore.shared.allPreferences()
    }

    private var recentTimelineView: some View {
        LazyVStack(spacing: 10) {
            if recentHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(Color(white: 0.6))
                    Text("No Interaction Records Yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    Text("Commands, tool operations, and verified actions will appear here.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.45))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                ForEach(recentHistory) { item in
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        selectedMemory = item
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(item.iconColor.opacity(0.12))
                                    .frame(width: 42, height: 42)
                                Image(systemName: item.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(item.iconColor)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                Text(item.timestamp)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.40))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(white: 0.60))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var notesView: some View {
        VStack(spacing: 10) {
            if notes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundColor(Color(white: 0.6))
                    Text("No Personal Notes")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    Text("Tap + to add important facts or reminders for IRIS.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.45))
                }
                .padding(.vertical, 40)
            } else {
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(note.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                            Spacer()
                            Text(note.category)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(6)
                        }

                        Text(note.content)
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.35))

                        Text("Updated: \(note.formattedDate)")
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.55))
                            .padding(.top, 2)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                }
            }
        }
    }

    private var preferencesView: some View {
        VStack(spacing: 10) {
            if preferences.isEmpty {
                preferenceRow(label: "Default Voice", value: "Samantha (Enhanced Local)")
                preferenceRow(label: "Hands-Free Trigger", value: "Hey IRIS")
                preferenceRow(label: "Confirmation Threshold", value: "Sensitive Actions Only")
                preferenceRow(label: "On-Device Neural Engine", value: "Qwen 2.5 3B / Qwen 3.5 0.8B")
            } else {
                ForEach(preferences) { pref in
                    preferenceRow(label: pref.key.replacingOccurrences(of: "_", with: " ").capitalized, value: pref.value)
                }
            }
        }
    }

    private func preferenceRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.black)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.40))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }
}

#Preview {
    MemoryView()
}
