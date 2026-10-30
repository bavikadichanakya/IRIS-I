//
//  IrisLiveActivity.swift
//  IRIS-I
//
//  Genuine Dynamic Island & Live Activity Widget for IRIS Voice Assistant.
//  Matches exact hardware specifications and visual design:
//  - Black horizontal capsule
//  - Left: Glossy 3D Pearlescent Orb
//  - Center-Left: Bold white "Hey IRIS" with muted status description
//  - Center-Right: Audio-reactive multi-bar waveform
//  - Far Right: Circular mic button with vivid green icon
//

import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit) && canImport(WidgetKit)

public struct PearlOrbCompactView: View {
    public var size: CGFloat = 24

    public init(size: CGFloat = 24) {
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white,
                        Color(white: 0.90),
                        Color(red: 0.74, green: 0.79, blue: 0.86),
                        Color(red: 0.42, green: 0.47, blue: 0.54)
                    ],
                    center: .init(x: 0.35, y: 0.28),
                    startRadius: 1,
                    endRadius: size * 0.75
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.85), Color.white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: Color.white.opacity(0.25), radius: 2, x: 0, y: 0)
    }
}

public struct DynamicIslandWaveform: View {
    public var audioLevel: Float
    public var barCount: Int = 7
    public var maxHeight: CGFloat = 16

    private let baseRatios: [CGFloat] = [0.25, 0.45, 0.75, 1.0, 0.80, 0.50, 0.30]

    public init(audioLevel: Float, barCount: Int = 7, maxHeight: CGFloat = 16) {
        self.audioLevel = audioLevel
        self.barCount = barCount
        self.maxHeight = maxHeight
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<min(barCount, baseRatios.count), id: \.self) { i in
                let normalized = max(0.15, CGFloat(audioLevel))
                let ratio = baseRatios[i]
                let barHeight = max(3.0, maxHeight * ratio * (0.35 + 0.65 * normalized))

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 2, height: barHeight)
            }
        }
    }
}

public struct GreenMicButton: View {
    public var size: CGFloat = 22

    public init(size: CGFloat = 22) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.16))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.75))
            Image(systemName: "mic.fill")
                .font(.system(size: size * 0.46, weight: .bold))
                .foregroundColor(Color(red: 0.22, green: 0.86, blue: 0.42))
        }
    }
}

public struct IrisLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: IrisWidgetAttributes.self) { context in
            // Lock Screen Live Activity Banner
            HStack(spacing: 14) {
                PearlOrbCompactView(size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hey IRIS")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(context.state.statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.70))
                }

                Spacer()

                DynamicIslandWaveform(audioLevel: context.state.audioLevel, barCount: 7, maxHeight: 22)
                    .padding(.trailing, 4)

                GreenMicButton(size: 32)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI (When touching / long-pressing the Island)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        PearlOrbCompactView(size: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Hey IRIS")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text(context.state.statusText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(white: 0.65))
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 8) {
                        DynamicIslandWaveform(
                            audioLevel: context.state.audioLevel,
                            barCount: 7,
                            maxHeight: 20
                        )

                        GreenMicButton(size: 28)
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }
            } compactLeading: {
                // Compact UI: Left side of the Dynamic Island cutout (fits within 52pt limit)
                PearlOrbCompactView(size: 20)
                    .padding(.leading, 4)
            } compactTrailing: {
                // Compact UI: Right side of the Dynamic Island cutout (fits within 52pt limit)
                HStack(spacing: 4) {
                    if context.state.isListening && context.state.audioLevel > 0.05 {
                        DynamicIslandWaveform(audioLevel: context.state.audioLevel, barCount: 4, maxHeight: 12)
                    } else {
                        GreenMicButton(size: 18)
                    }
                }
                .padding(.trailing, 4)
            } minimal: {
                // Minimal UI: Sharing island with another activity
                PearlOrbCompactView(size: 14)
            }
            .keylineTint(Color.white.opacity(0.3))
        }
    }
}

#endif
