//
//  DynamicIslandPillView.swift
//  IRIS-I
//
//  Dynamic Island Floating Interactive Pill matching design blueprint:
//  [ (●) Pearl Orb ]  [ Hey IRIS \n Listening... ]  [ ||||||| (mic) ]
//

import SwiftUI

public struct DynamicIslandPillView: View {
    @ObservedObject var speechManager = SpeechManager.shared

    public init() {}

    public var body: some View {
        if speechManager.state == .listening || speechManager.state == .processing || speechManager.state == .speaking || speechManager.wakeWordDetected {
            pillContent
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.88).combined(with: .opacity).combined(with: .move(edge: .top)),
                    removal: .scale(scale: 0.90).combined(with: .opacity).combined(with: .move(edge: .top))
                ))
                .animation(.spring(response: 0.36, dampingFraction: 0.75), value: speechManager.state)
                .animation(.spring(response: 0.36, dampingFraction: 0.75), value: speechManager.wakeWordDetected)
        }
    }

    private var pillContent: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            if speechManager.state == .listening {
                speechManager.stopListeningInternal()
            } else {
                Task { await speechManager.startListening() }
            }
        } label: {
            HStack(spacing: 10) {
                // Leading 3D Pearl Orb
                PearlOrbView(
                    size: 28,
                    audioLevel: speechManager.audioLevel,
                    isListening: speechManager.state == .listening
                )
                .frame(width: 28, height: 28)

                // Center Typography: Title & Live Status
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hey IRIS")
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .foregroundColor(.white)

                    Text(statusDescription)
                        .font(.system(size: 10.5, weight: .regular, design: .default))
                        .foregroundColor(Color(white: 0.65))
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                // Trailing Live Waveform & Microphone Button (Matching Blueprint)
                HStack(spacing: 8) {
                    miniWaveform

                    // Circular Microphone Icon Badge
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.20))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(speechManager.state == .listening ? Color.white.opacity(0.85) : Color.white.opacity(0.18), lineWidth: 1.2)
                            )

                        Image(systemName: "mic.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .padding(.vertical, 7)
            .frame(width: 252, height: 44)
            .background(
                Capsule()
                    .fill(Color.black)
                    .shadow(color: Color.black.opacity(0.45), radius: 12, y: 5)
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.08), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var statusDescription: String {
        switch speechManager.state {
        case .listening:
            return speechManager.recognizedText.isEmpty ? "Listening..." : speechManager.recognizedText
        case .processing:
            return "Thinking..."
        case .speaking:
            return speechManager.spokenResponse.isEmpty ? "Responding..." : speechManager.spokenResponse
        case .idle:
            return "Ready"
        }
    }

    private var miniWaveform: some View {
        HStack(spacing: 2.2) {
            ForEach(0..<7, id: \.self) { i in
                let scale = waveformHeight(for: i)
                Capsule()
                    .fill(Color.white)
                    .frame(width: 2.2, height: max(3.5, 17 * CGFloat(scale)))
            }
        }
    }

    private func waveformHeight(for index: Int) -> Float {
        let baseEnvelope: [Float] = [0.35, 0.55, 0.85, 1.0, 0.85, 0.55, 0.35]
        let base = baseEnvelope[index]
        let reactive = speechManager.audioLevel * Float([0.5, 0.8, 1.0, 1.2, 1.0, 0.8, 0.5][index])
        return min(1.0, base * 0.35 + reactive * 0.65)
    }
}
