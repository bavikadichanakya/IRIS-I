//
//  LanguageSettingsSubsectionView.swift
//  IRIS-I
//
//  Subsection: Language, Speech Recognition Locales, and Neural Model Details.
//  Configures speech recognizer locale, on-device offline recognition,
//  and inspects local Qwen 2.5 LLM language capabilities.
//

import SwiftUI

public struct LanguageSettingsSubsectionView: View {
    @AppStorage("iris_selected_language") private var selectedLanguage: String = "English (United States)"
    @AppStorage("iris_on_device_dictation") private var onDeviceDictation: Bool = true
    @AppStorage("iris_filter_profanity") private var filterProfanity: Bool = false
    @StateObject private var brainCoordinator = BrainDownloadCoordinator.shared

    private let supportedLocales: [(name: String, code: String, flag: String)] = [
        ("English (United States)", "en-US", "🇺🇸"),
        ("English (United Kingdom)", "en-GB", "🇬🇧"),
        ("English (India)", "en-IN", "🇮🇳"),
        ("English (Australia)", "en-AU", "🇦🇺"),
        ("English (Canada)", "en-CA", "🇨🇦"),
        ("Multilingual Auto-Detect", "auto", "🌐")
    ]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Active Language Card
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "globe.americas.fill")
                            .foregroundColor(.blue)
                        Text("Active Recognition Locale")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(onDeviceDictation ? "100% On-Device" : "Network Assisted")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 14) {
                        Text(supportedLocales.first(where: { $0.name == selectedLanguage })?.flag ?? "🌐")
                            .font(.system(size: 36))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedLanguage)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.black)
                            Text("Apple Speech Framework • High-Accuracy Acoustic Model")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.40))
                        }
                        Spacer()
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                // Locale Selector
                VStack(alignment: .leading, spacing: 14) {
                    Text("Select Language")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)

                    VStack(spacing: 0) {
                        ForEach(0..<supportedLocales.count, id: \.self) { index in
                            let locale = supportedLocales[index]
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation {
                                    selectedLanguage = locale.name
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(locale.flag)
                                        .font(.system(size: 20))

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(locale.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.black)
                                        Text(locale.code)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundColor(Color(white: 0.50))
                                    }

                                    Spacer()

                                    if selectedLanguage == locale.name {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            if index < supportedLocales.count - 1 {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .background(Color(white: 0.98))
                    .cornerRadius(14)
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                // Privacy & Dictation Controls
                VStack(spacing: 0) {
                    toggleRow(
                        icon: "lock.shield.fill",
                        iconColor: .green,
                        title: "On-Device Dictation",
                        subtitle: "Transcribe voice strictly on Neural Engine without sending audio to Apple servers",
                        isOn: $onDeviceDictation
                    )
                    Divider().padding(.leading, 52)
                    toggleRow(
                        icon: "character.bubble.fill",
                        iconColor: .orange,
                        title: "Profanity Filter",
                        subtitle: "Mask recognized sensitive words in assistant transcripts",
                        isOn: $filterProfanity
                    )
                }
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                // Local LLM Brain Specs
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "cpu.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.purple)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Neural Language Model")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            Text("On-device inference pipeline")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.40))
                        }
                    }

                    Divider()

                    specRow(label: "Architecture", value: "Qwen 2.5 3B Instruct")
                    specRow(label: "Quantization", value: "Q4_K_M (4-bit Metal)")
                    specRow(label: "Weights Size", value: "2.10 GB (2,104,932,768 bytes)")
                    specRow(label: "Hardware Acceleration", value: "Apple A19 Pro Metal (MPS)")
                    specRow(label: "Context Length", value: "4,096 tokens")
                    specRow(label: "Model Status", value: brainCoordinator.isModelActive ? "Loaded in Memory" : "Installed On-Device")
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
        .navigationTitle("Language & Speech")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleRow(icon: String, iconColor: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.45))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(16)
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.45))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.black)
        }
    }
}

