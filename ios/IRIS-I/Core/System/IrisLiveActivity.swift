//
//  IrisLiveActivity.swift
//  IRIS-I
//
//  Authoritative Dynamic Island & Live Activity Widget for IRIS Voice Assistant.
//  Reproduces exact visual language, proportions, and motion from the reference video:
//  - Black horizontal capsule with smooth rounded ends
//  - Left: Circular IRIS Pearlescent Orb with soft-grey illuminated outer rim
//  - Center-Left: Bold white "Hey IRIS" with dynamic execution state ("Listening...", "Thinking...", "Responding...", "Opening application...", "Completed", "Action failed")
//  - Center-Right: Symmetrical white multi-bar audio waveform reactive to real microphone amplitude and speech playback
//  - Far Right: Circular microphone control with translucent dark-grey surface, white microphone icon, and active illuminated rim
//

import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit) && canImport(WidgetKit)

/// Dual-layer Circular IRIS Pearlescent Orb matching video reference frame_001.png and frame_005.png
public struct PearlOrbDynamicIslandView: View {
    public var size: CGFloat

    public init(size: CGFloat = 20) {
        self.size = size
    }

    public var body: some View {
        let innerSize = max(8, size * 0.74)
        let rimStrokeWidth = max(0.8, size * 0.05)

        ZStack {
            // Outer illuminated translucent soft-grey rim
            Circle()
                .fill(Color(white: 0.28).opacity(0.85))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color(white: 0.65).opacity(0.35),
                                    Color.white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: rimStrokeWidth
                        )
                )

            // Inner circular pearl disc with specular illumination
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            Color(white: 0.94),
                            Color(red: 0.80, green: 0.84, blue: 0.90),
                            Color(red: 0.50, green: 0.55, blue: 0.62)
                        ],
                        center: .init(x: 0.32, y: 0.26),
                        startRadius: 1,
                        endRadius: innerSize * 0.75
                    )
                )
                .frame(width: innerSize, height: innerSize)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.90), Color.white.opacity(0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                )
        }
        .frame(width: size, height: size)
    }
}

public typealias PearlOrbCompactView = PearlOrbDynamicIslandView

/// Symmetrical Animated White Audio Waveform matching video speech envelope
public struct DynamicIslandWaveformView: View {
    public var audioLevel: Float
    public var statusText: String
    public var isListening: Bool
    public var barCount: Int
    public var maxHeight: CGFloat

    // 15-bar symmetrical speech amplitude envelope (two distinct speech lobes)
    private let speechEnvelope15: [CGFloat] = [
        0.18, 0.28, 0.45, 0.70, 0.98, 0.82, 0.55, 0.72, 0.92, 0.68, 0.48, 0.32, 0.22, 0.15, 0.10
    ]

    // 5-bar compact envelope
    private let speechEnvelope5: [CGFloat] = [
        0.30, 0.65, 1.00, 0.70, 0.35
    ]

    public init(
        audioLevel: Float = 0.0,
        statusText: String = "Listening...",
        isListening: Bool = true,
        barCount: Int = 15,
        maxHeight: CGFloat = 22
    ) {
        self.audioLevel = audioLevel
        self.statusText = statusText
        self.isListening = isListening
        self.barCount = barCount
        self.maxHeight = maxHeight
    }

    public var body: some View {
        let envelope = (barCount <= 7) ? speechEnvelope5 : speechEnvelope15
        let count = min(barCount, envelope.count)

        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { i in
                let ratio = envelope[i]
                let barHeight = calculateBarHeight(index: i, ratio: ratio)

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 2, height: barHeight)
            }
        }
    }

    private func calculateBarHeight(index: Int, ratio: CGFloat) -> CGFloat {
        let isThinking = statusText.lowercased().contains("thinking") || statusText.lowercased().contains("processing")
        let isResponding = statusText.lowercased().contains("responding")

        if isThinking {
            // Processing undulation
            let phase = Double(index) * 0.4
            let pulse = (sin(phase) + 1.0) / 2.0
            return max(3.0, maxHeight * (0.25 + 0.45 * CGFloat(pulse)))
        } else if isResponding {
            // Audio playback reaction
            let norm = max(0.20, CGFloat(audioLevel))
            return max(3.0, maxHeight * ratio * (0.30 + 0.70 * norm))
        } else if isListening {
            if audioLevel > 0.05 {
                // Active microphone input reaction
                let norm = min(1.0, max(0.15, CGFloat(audioLevel)))
                return max(3.0, maxHeight * ratio * (0.25 + 0.75 * norm))
            } else {
                // Subtle idle silence envelope (frame_010.png)
                return max(2.5, maxHeight * ratio * 0.25)
            }
        } else {
            // Subtle idle state
            return max(2.0, maxHeight * ratio * 0.20)
        }
    }
}

public typealias DynamicIslandWaveform = DynamicIslandWaveformView

/// Circular Microphone Control with translucent dark-grey surface, white mic icon, and active illuminated rim
public struct CircularMicrophoneButton: View {
    public var isListening: Bool
    public var size: CGFloat

    public init(isListening: Bool = true, size: CGFloat = 30) {
        self.isListening = isListening
        self.size = size
    }

    public var body: some View {
        let iconSize = max(9, size * 0.44)

        ZStack {
            // Subtle translucent dark-grey button surface
            Circle()
                .fill(Color(white: 0.20))
                .frame(width: size, height: size)

            // Outer rim: illuminated white halo when listening, subtle border when idle
            Circle()
                .stroke(
                    isListening ? Color.white.opacity(0.85) : Color.white.opacity(0.18),
                    lineWidth: isListening ? 1.5 : 1.0
                )
                .frame(width: size, height: size)

            // White microphone icon
            Image(systemName: "mic.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

public typealias GreenMicButton = CircularMicrophoneButton

public struct IrisLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: IrisWidgetAttributes.self) { context in
            // Lock Screen Live Activity: Exact match for the horizontal black capsule in the reference video
            HStack(spacing: 12) {
                // Left: Circular IRIS Pearlescent Orb with illuminated outer rim
                PearlOrbDynamicIslandView(size: 38)

                // Center-Left: Primary "Hey IRIS" and Dynamic State
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hey IRIS")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(context.state.statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.65))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Center-Right: Symmetrical White Audio Waveform
                DynamicIslandWaveformView(
                    audioLevel: context.state.audioLevel,
                    statusText: context.state.statusText,
                    isListening: context.state.isListening,
                    barCount: 15,
                    maxHeight: 24
                )

                // Right: Circular Microphone Control
                CircularMicrophoneButton(
                    isListening: context.state.isListening,
                    size: 34
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Presentation: Reproduces the full authoritative video capsule
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        PearlOrbDynamicIslandView(size: 32)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Hey IRIS")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text(context.state.statusText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(white: 0.65))
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 6)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 8) {
                        DynamicIslandWaveformView(
                            audioLevel: context.state.audioLevel,
                            statusText: context.state.statusText,
                            isListening: context.state.isListening,
                            barCount: 13,
                            maxHeight: 22
                        )

                        CircularMicrophoneButton(
                            isListening: context.state.isListening,
                            size: 30
                        )
                    }
                    .padding(.trailing, 6)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if let transcript = context.state.transcript, !transcript.isEmpty {
                        HStack(spacing: 6) {
                            Text(transcript)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color(white: 0.85))
                                .lineLimit(2)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                    } else {
                        EmptyView()
                    }
                }
            } compactLeading: {
                // Compact Leading: 20pt Dual-layer Pearl Orb fitting strictly within 52pt limit
                PearlOrbDynamicIslandView(size: 20)
                    .padding(.leading, 2)
            } compactTrailing: {
                // Compact Trailing: Symmetrical waveform or circular mic button
                HStack(spacing: 2) {
                    if context.state.isListening && context.state.audioLevel > 0.05 {
                        DynamicIslandWaveformView(
                            audioLevel: context.state.audioLevel,
                            statusText: context.state.statusText,
                            isListening: true,
                            barCount: 5,
                            maxHeight: 14
                        )
                    } else {
                        CircularMicrophoneButton(
                            isListening: context.state.isListening,
                            size: 18
                        )
                    }
                }
                .padding(.trailing, 2)
            } minimal: {
                // Minimal Presentation: Sharing island with another system activity
                PearlOrbDynamicIslandView(size: 14)
            }
            .keylineTint(Color.white.opacity(0.3))
        }
    }
}

#endif
