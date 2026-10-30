//
//  DynamicIslandPillView.swift
//  IRIS-I
//
//  Dynamic Island Floating Interactive Pill matching design blueprint:
//  [ (●) Pearl Orb ]  [ Hey IRIS \n Listening... ]  [ |||||| (mic) ]
//

import SwiftUI

public struct DynamicIslandPillView: View {
    @ObservedObject var speechManager = SpeechManager.shared

    public init() {}

    public var body: some View {
        if speechManager.state == .listening || speechManager.state == .processing || speechManager.state == .speaking || speechManager.wakeWordDetected {
            pillContent
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity).combined(with: .move(edge: .top)),
                    removal: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top))
                ))
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: speechManager.state)
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: speechManager.wakeWordDetected)
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
                // Leading 3D Pearl Orb (matches blueprint)
                PearlOrbView(
                    size: 24,
                    audioLevel: speechManager.audioLevel,
                    isListening: speechManager.state == .listening
                )

                // Center Typography: Title & Live Status
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hey IRIS")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)

                    Text(statusDescription)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(white: 0.70))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Trailing Live Waveform & Microphone
                HStack(spacing: 6) {
                    miniWaveform
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(speechManager.state == .listening ? Color.green : Color.white)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .padding(.vertical, 8)
            .frame(width: 236, height: 42)
            .background(
                Capsule()
                    .fill(Color.black)
                    .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.05), Color.clear],
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
        HStack(spacing: 2.5) {
            ForEach(0..<4, id: \.self) { i in
                let scale = waveformHeight(for: i)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: 2.5, height: max(4, 16 * CGFloat(scale)))
            }
        }
    }

    private func waveformHeight(for index: Int) -> Float {
        let base = [0.4, 0.9, 0.7, 0.5][index]
        let reactive = speechManager.audioLevel * Float([0.6, 1.0, 0.8, 0.5][index])
        return min(1.0, Float(base) * 0.3 + reactive * 0.7)
    }
}

