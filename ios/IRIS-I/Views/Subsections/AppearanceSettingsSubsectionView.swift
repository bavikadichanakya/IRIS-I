//
//  AppearanceSettingsSubsectionView.swift
//  IRIS-I
//
//  Subsection: Appearance, Liquid Glass Presets, and Theme Customization.
//  Offers real-time visual preview of glass finishes, accent tints,
//  and ambient luminous aura settings.
//

import SwiftUI

public struct AppearanceSettingsSubsectionView: View {
    @AppStorage("iris_appearance_theme") private var selectedTheme: String = "Liquid Glass"
    @AppStorage("iris_accent_color") private var selectedAccent: String = "Deep Blue"
    @AppStorage("iris_enable_ambient_aura") private var enableAmbientAura: Bool = true
    @AppStorage("iris_enable_orb_pulse") private var enableOrbPulse: Bool = true
    @AppStorage("iris_glass_blur_intensity") private var blurIntensity: Double = 0.8

    private let themes = [
        ("Liquid Glass", "Signature Apple luminous ice aesthetic", "sparkles"),
        ("Frosted Pearl", "Diffused soft glass with pastel undertones", "snowflake"),
        ("Deep Titanium", "Dark-toned high-contrast glass for night usage", "moon.stars.fill"),
        ("Minimal Monolith", "Ultra-clean stark typography with sharp edges", "square.fill")
    ]

    private let accents: [(name: String, color: Color)] = [
        ("Deep Blue", Color(red: 0.15, green: 0.45, blue: 0.95)),
        ("Iris Violet", Color(red: 0.60, green: 0.35, blue: 0.95)),
        ("Sunset Amber", Color(red: 0.95, green: 0.55, blue: 0.15)),
        ("Emerald Mint", Color(red: 0.18, green: 0.75, blue: 0.48)),
        ("Carbon", Color(white: 0.20))
    ]

    public init() {}

    private var activeAccentColor: Color {
        accents.first(where: { $0.name == selectedAccent })?.color ?? Color.blue
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Real-time Visual Preview Card
                VStack(spacing: 14) {
                    HStack {
                        Image(systemName: "eye.fill")
                            .foregroundColor(activeAccentColor)
                        Text("Live Theme Preview")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(selectedTheme)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(activeAccentColor.opacity(0.12))
                            .foregroundColor(activeAccentColor)
                            .clipShape(Capsule())
                    }

                    ZStack {
                        // Ambient glow representation
                        if enableAmbientAura {
                            Circle()
                                .fill(activeAccentColor.opacity(0.20))
                                .frame(width: 140, height: 140)
                                .blur(radius: 25)
                                .offset(x: -30, y: -20)

                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 120, height: 120)
                                .blur(radius: 20)
                                .offset(x: 40, y: 30)
                        }

                        // Glass pill mock
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                PearlOrbView(size: 34, audioLevel: enableOrbPulse ? 0.35 : 0.0)
                                    .frame(width: 34, height: 34)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("IRIS Intelligence")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(selectedTheme == "Deep Titanium" ? .white : .black)
                                    Text("Neural Engine Active • A19 Pro")
                                        .font(.system(size: 11))
                                        .foregroundColor(selectedTheme == "Deep Titanium" ? Color(white: 0.7) : Color(white: 0.45))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(activeAccentColor)
                            }
                        }
                        .padding(16)
                        .background(
                            selectedTheme == "Deep Titanium"
                                ? Color(white: 0.12).opacity(0.92)
                                : Color.white.opacity(0.85)
                        )
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.6), lineWidth: 1.2)
                        )
                    }
                    .frame(height: 100)
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                // Glass Presets
                VStack(alignment: .leading, spacing: 14) {
                    Text("Liquid Glass Style")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)

                    VStack(spacing: 10) {
                        ForEach(themes, id: \.0) { theme in
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedTheme = theme.0
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: theme.2)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(selectedTheme == theme.0 ? activeAccentColor : Color(white: 0.45))
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(theme.0)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.black)
                                        Text(theme.1)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(white: 0.45))
                                    }

                                    Spacer()

                                    if selectedTheme == theme.0 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(activeAccentColor)
                                            .font(.system(size: 18))
                                    }
                                }
                                .padding(14)
                                .background(selectedTheme == theme.0 ? activeAccentColor.opacity(0.06) : Color(white: 0.97))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedTheme == theme.0 ? activeAccentColor.opacity(0.3) : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                // Accent Color Palette
                VStack(alignment: .leading, spacing: 14) {
                    Text("Accent Tint Color")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)

                    HStack(spacing: 12) {
                        ForEach(accents, id: \.name) { item in
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation {
                                    selectedAccent = item.name
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(item.color)
                                            .frame(width: 44, height: 44)
                                            .shadow(color: item.color.opacity(0.3), radius: 4, y: 2)

                                        if selectedAccent == item.name {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }

                                    Text(item.name.components(separatedBy: " ").last ?? item.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(selectedAccent == item.name ? .black : Color(white: 0.50))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                // Visual Effects Toggles
                VStack(spacing: 0) {
                    toggleRow(
                        title: "Ambient Depth Aura",
                        subtitle: "Dynamic colorful gradient blurs in background",
                        isOn: $enableAmbientAura
                    )
                    Divider().padding(.leading, 16)
                    toggleRow(
                        title: "Pearl Orb Audio Pulse",
                        subtitle: "Animate orb scale and luminosity in sync with speech",
                        isOn: $enableOrbPulse
                    )
                }
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
        .navigationTitle("Appearance & Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
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
                .tint(activeAccentColor)
                .labelsHidden()
        }
        .padding(16)
    }
}
