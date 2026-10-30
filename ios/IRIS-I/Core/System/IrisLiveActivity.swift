//
//  IrisLiveActivity.swift
//  IRIS-I
//
//  Live Activity & Dynamic Island Widget for IRIS Voice Assistant.
//

import WidgetKit
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit) && canImport(WidgetKit)
public struct IrisLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: IrisWidgetAttributes.self) { context in
            // Lock Screen UI
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text("IRIS Voice Assistant")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(context.state.status)
                        .font(.subheadline)
                        .foregroundColor(Color(white: 0.7))
                }

                Spacer()

                // Waveform indicator
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.green)
                            .frame(width: 2.5, height: [8.0, 16.0, 12.0, 7.0][i])
                    }
                }
            }
            .padding()
            .background(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI (When long-pressing / touching the Island)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.white, Color(white: 0.85), Color(red: 0.75, green: 0.80, blue: 0.88)],
                                    center: .topLeading,
                                    startRadius: 2,
                                    endRadius: 16
                                )
                            )
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Hey IRIS")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(context.state.status)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color(white: 0.65))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 6) {
                        // Live waveform simulation bars
                        HStack(spacing: 2) {
                            ForEach(0..<4, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white)
                                    .frame(width: 2, height: [8.0, 15.0, 11.0, 6.0][i])
                            }
                        }
                        Image(systemName: "mic.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }
            } compactLeading: {
                // Compact UI (Left side of the bubble)
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
            } compactTrailing: {
                // Compact UI (Right side of the bubble)
                HStack(spacing: 3) {
                    Text("IRIS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                }
            } minimal: {
                // Minimal UI (If another app is sharing the island)
                Image(systemName: "mic.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.green)
            }
        }
    }
}
#endif
