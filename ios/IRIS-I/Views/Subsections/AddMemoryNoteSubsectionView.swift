//
//  AddMemoryNoteSubsectionView.swift
//  IRIS-I
//
//  Subsection: Add User Preference or Memory Note.
//  Enables persisting custom assistant preferences and guidance
//  into the local semantic memory store.
//

import SwiftUI

public struct AddMemoryNoteSubsectionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var noteText: String = ""
    @State private var selectedCategory: String = "Preferences"
    @State private var priority: String = "Normal"

    public var onSave: ((String) -> Void)?

    private let categories = ["Preferences", "Reminders", "Daily Routine", "Media & Apps", "Work"]
    private let priorities = ["Normal", "High", "Critical"]

    public init(onSave: ((String) -> Void)? = nil) {
        self.onSave = onSave
    }

    private var isValid: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Instruction Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.purple)
                            Text("Context & Guidance")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        Text("Add persistent facts, preferences, or behavior rules that IRIS will retain across voice sessions.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.40))
                    }
                    .padding(16)
                    .background(Color.purple.opacity(0.06))
                    .cornerRadius(16)

                    // Note Editor
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Note or Preference")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)

                        TextEditor(text: $noteText)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(white: 0.96))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )

                        Text("Example: 'Always prefer Spotify when asking for rock music' or 'Home address is 123 Cupertino Way'.")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.50))
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Category & Priority
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Classification")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(white: 0.40))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(categories, id: \.self) { cat in
                                        Button {
                                            selectedCategory = cat
                                        } label: {
                                            Text(cat)
                                                .font(.system(size: 13, weight: selectedCategory == cat ? .semibold : .medium))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(selectedCategory == cat ? Color.purple.opacity(0.15) : Color(white: 0.95))
                                                .foregroundColor(selectedCategory == cat ? .purple : .black)
                                                .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Priority Level")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(white: 0.40))

                            Picker("Priority", selection: $priority) {
                                ForEach(priorities, id: \.self) { p in
                                    Text(p).tag(p)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Save Button
                    Button {
                        saveNote()
                    } label: {
                        Text("Save to Memory")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isValid ? Color.purple : Color.gray.opacity(0.4))
                            .cornerRadius(16)
                            .shadow(color: isValid ? Color.purple.opacity(0.35) : Color.clear, radius: 8, y: 3)
                    }
                    .disabled(!isValid)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveNote() {
        guard isValid else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave?(trimmed)
        dismiss()
    }
}

