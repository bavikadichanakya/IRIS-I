//
//  AddCustomActionSubsectionView.swift
//  IRIS-I
//
//  Subsection: Create and Register Custom iOS Action.
//  Allows defining custom app schemes, AI prompts, or system tools,
//  selecting iconography, and appending to the live Actions Catalog.
//

import SwiftUI

public struct AddCustomActionSubsectionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var targetSchemeOrPrompt: String = ""
    @State private var selectedType: Int = 0 // 0: Open App, 1: System Tool, 2: AI Prompt
    @State private var selectedIcon: String = "app.fill"
    @State private var selectedColorIndex: Int = 0

    public var onSave: ((ActionItem) -> Void)?

    private let availableIcons = [
        "app.fill", "bolt.fill", "message.fill", "bubble.left.fill",
        "network", "cart.fill", "star.fill", "heart.fill",
        "bell.fill", "magnifyingglass", "house.fill", "briefcase.fill"
    ]

    private let availableColors: [(name: String, color: Color)] = [
        ("Blue", Color.blue),
        ("Purple", Color.purple),
        ("Pink", Color.pink),
        ("Orange", Color.orange),
        ("Green", Color.green),
        ("Cyan", Color.cyan)
    ]

    public init(onSave: ((ActionItem) -> Void)? = nil) {
        self.onSave = onSave
    }

    private var selectedColor: Color {
        availableColors[selectedColorIndex].color
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !targetSchemeOrPrompt.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Live Card Preview
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Preview in Catalog")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedColor.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(selectedColor)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(title.isEmpty ? "Action Title" : title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                Text(subtitle.isEmpty ? "Action description or purpose" : subtitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(white: 0.40))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(white: 0.65))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                    }
                    .padding(16)
                    .background(Color(white: 0.98))
                    .cornerRadius(18)

                    // Form Fields
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Action Details")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Title")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(white: 0.40))
                            TextField("e.g. Open Slack", text: $title)
                                .padding(12)
                                .background(Color(white: 0.96))
                                .cornerRadius(10)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(white: 0.40))
                            TextField("e.g. Launch workspace messaging", text: $subtitle)
                                .padding(12)
                                .background(Color(white: 0.96))
                                .cornerRadius(10)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Action Type")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(white: 0.40))

                            Picker("Action Type", selection: $selectedType) {
                                Text("Launch App").tag(0)
                                Text("System Action").tag(1)
                                Text("AI Prompt").tag(2)
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(targetFieldLabel)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(white: 0.40))
                            TextField(targetFieldPlaceholder, text: $targetSchemeOrPrompt)
                                .padding(12)
                                .background(Color(white: 0.96))
                                .cornerRadius(10)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Icon Picker
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Select Icon")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    selectedIcon = icon
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedIcon == icon ? selectedColor.opacity(0.18) : Color(white: 0.96))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: icon)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(selectedIcon == icon ? selectedColor : Color(white: 0.35))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Color Picker
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Select Color")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)

                        HStack(spacing: 14) {
                            ForEach(0..<availableColors.count, id: \.self) { idx in
                                let item = availableColors[idx]
                                Button {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    selectedColorIndex = idx
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(item.color)
                                            .frame(width: 38, height: 38)
                                        if selectedColorIndex == idx {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Save Action Button
                    Button {
                        saveAction()
                    } label: {
                        Text("Add to Actions Catalog")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isValid ? selectedColor : Color.gray.opacity(0.4))
                            .cornerRadius(16)
                            .shadow(color: isValid ? selectedColor.opacity(0.3) : Color.clear, radius: 8, y: 3)
                    }
                    .disabled(!isValid)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
            .navigationTitle("New Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var targetFieldLabel: String {
        switch selectedType {
        case 0: return "Application Name or URL Scheme"
        case 1: return "System Command (e.g. battery, storage)"
        default: return "Assistant Prompt Template"
        }
    }

    private var targetFieldPlaceholder: String {
        switch selectedType {
        case 0: return "e.g. Slack or slack://"
        case 1: return "e.g. battery or thermal"
        default: return "e.g. What is the weather in Paris?"
        }
    }

    private func saveAction() {
        guard isValid else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let actionType: ActionItem.ActionType
        switch selectedType {
        case 0: actionType = .openApp(targetSchemeOrPrompt)
        case 1: actionType = .systemAction(targetSchemeOrPrompt)
        default: actionType = .customPrompt(targetSchemeOrPrompt)
        }

        let newAction = ActionItem(
            id: UUID().uuidString.lowercased(),
            title: title.trimmingCharacters(in: .whitespaces),
            subtitle: subtitle.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            iconColor: selectedColor,
            actionType: actionType
        )

        onSave?(newAction)
        dismiss()
    }
}
