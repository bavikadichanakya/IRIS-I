//
//  IRISShortcutSnippetView.swift
//  IRIS-I
//
//  Custom Shortcuts System Presentation View matching Image 2 design blueprint:
//  Row 1: [ ( ≡ ) ]  [ (●) Hey IRIS \n Listening...  •••• 🎤 ]  [ ( ✨ ) ]
//  Row 2: [ |||| Listening... ✓                          ⟲ ]
//

import SwiftUI

public struct IRISShortcutSnippetView: View {
    public var statusText: String
    public var isListening: Bool
    public var recognizedText: String

    public init(
        statusText: String = "Listening...",
        isListening: Bool = true,
        recognizedText: String = ""
    ) {
        self.statusText = statusText
        self.isListening = isListening
        self.recognizedText = recognizedText
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Row 1: Left Menu Button | Center Black Capsule | Right Sparkle Button
            HStack(spacing: 12) {
                // Left Menu Button
                Button(action: {}) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
                        )
                }
                .buttonStyle(.plain)

                // Center Black Capsule (Image 2 Blueprint)
                HStack(spacing: 10) {
                    // Leading 3D Pearl Orb
                    PearlOrbView(size: 26, audioLevel: 0.3, isListening: isListening)
                        .frame(width: 26, height: 26)

                    // Typography
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Hey IRIS")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.white)

                        Text(statusText)
                            .font(.system(size: 10.5, weight: .regular))
                            .foregroundColor(Color(white: 0.65))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    // Sound Dots & White Microphone on translucent circular button
                    HStack(spacing: 6) {
                        HStack(spacing: 2.5) {
                            ForEach(0..<4, id: \.self) { _ in
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 3, height: 3)
                            }
                        }

                        ZStack {
                            Circle()
                                .fill(Color(white: 0.20))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle()
                                        .stroke(isListening ? Color.white.opacity(0.85) : Color.white.opacity(0.18), lineWidth: 1.2)
                                )

                            Image(systemName: "mic.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(
                    Capsule()
                        .fill(Color.black)
                        .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
                )

                // Right Sparkle Button
                Button(action: {}) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
                        )
                }
                .buttonStyle(.plain)
            }

            // Row 2: White Pill [ |||| Listening... ✓            ⟲ ]
            HStack(spacing: 8) {
                // Waveform bars
                HStack(spacing: 2.2) {
                    ForEach([6, 12, 10, 5], id: \.self) { h in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black)
                            .frame(width: 2, height: CGFloat(h))
                    }
                }

                Text(recognizedText.isEmpty ? "Listening..." : recognizedText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)

                Image(systemName: "checkmark")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.95))

                Spacer()

                Button(action: {}) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Color(white: 0.45))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

