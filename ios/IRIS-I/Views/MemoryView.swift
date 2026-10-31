//
//  MemoryView.swift
//  IRIS-I
//
//  Screen 7: Memory & Context Timeline.
//  Preserves verified interaction history, user preferences, and captured assistant context.
//

import SwiftUI

public struct MemoryItem: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let timestamp: String
    public let icon: String
    public let iconColor: Color
    public let category: String
}

public struct MemoryView: View {
    @State private var selectedSegment: Int = 0 // 0: Recent, 1: Notes, 2: Preferences
    @State private var selectedMemory: MemoryItem? = nil
    @State private var isShowingAddNote: Bool = false
    private let segments = ["Recent", "Notes", "Preferences"]

    @State private var recentHistory: [MemoryItem] = [
        MemoryItem(
            title: "Opened Instagram",
            timestamp: "Today, 9:54 AM",
            icon: "camera.circle.fill",
            iconColor: Color.purple,
            category: "App Launch"
        ),
        MemoryItem(
            title: "Played Apple Music",
            timestamp: "Today, 8:26 AM",
            icon: "music.note.circle.fill",
            iconColor: Color.pink,
            category: "Media"
        ),
        MemoryItem(
            title: "Found file: Cybersecurity_Report.pdf",
            timestamp: "Today, 8:18 AM",
            icon: "doc.fill",
            iconColor: Color.blue,
            category: "Files"
        ),
        MemoryItem(
            title: "Took a photo",
            timestamp: "Today, 8:20 AM",
            icon: "camera.fill",
            iconColor: Color.orange,
            category: "Camera"
        ),
        MemoryItem(
            title: "Opened YouTube",
            timestamp: "Today, 8:00 AM",
            icon: "play.circle.fill",
            iconColor: Color.red,
            category: "App Launch"
        ),
        MemoryItem(
            title: "Checked battery status (80% Charging)",
            timestamp: "Yesterday, 10:15 PM",
            icon: "bolt.fill",
            iconColor: Color.yellow,
            category: "Telemetry"
        )
    ]

    @State private var sampleNotes: [String] = [
        "Prefers Apple Music over Spotify for Siri commands.",
        "Set daily reminder for standup meeting at 10:00 AM.",
        "Default location: Cupertino / San Francisco."
    ]

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
            .sheet(item: $selectedMemory) { item in
                MemoryDetailSubsectionView(item: item) { idToDelete in
                    recentHistory.removeAll(where: { $0.id == idToDelete })
                }
            }
            .sheet(isPresented: $isShowingAddNote) {
                AddMemoryNoteSubsectionView { newNote in
                    sampleNotes.insert(newNote, at: 0)
                }
            }
        }
    }

    private var recentTimelineView: some View {
        LazyVStack(spacing: 10) {
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

    private var notesView: some View {
        VStack(spacing: 10) {
            ForEach(sampleNotes, id: \.self) { note in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "note.text")
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                    Text(note)
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
            }
        }
    }

    private var preferencesView: some View {
        VStack(spacing: 10) {
            preferenceRow(label: "Default Music Player", value: "Apple Music")
            preferenceRow(label: "Wake Word Activation", value: "Hey IRIS")
            preferenceRow(label: "Confirmation Threshold", value: "Sensitive Actions Only")
            preferenceRow(label: "On-Device Neural Engine", value: "Qwen 2.5 3B (Metal)")
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

