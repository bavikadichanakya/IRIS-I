//
//  LiveWaveformView.swift
//  IRIS-I
//
//  Interactive audio-reactive waveform visualizer matching Apple Siri / Intelligence voice dynamics.
//

import SwiftUI

public struct LiveWaveformView: View {
    public let audioLevel: Float
    public let barCount: Int

    @State private var phase: Double = 0.0

    public init(audioLevel: Float = 0.0, barCount: Int = 36) {
        self.audioLevel = audioLevel
        self.barCount = barCount
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                let norm = Double(i) / Double(barCount)
                // Center-weighted Gaussian bell curve for Apple-like waveform envelope
                let bell = exp(-pow((norm - 0.5) * 4.0, 2.0))
                let dynamicHeight = CGFloat(8.0 + (Double(audioLevel) * 54.0 + sin(phase + norm * .pi * 3.5) * 8.0) * bell)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.70, blue: 0.85).opacity(0.85),
                                Color(red: 0.75, green: 0.82, blue: 0.95).opacity(0.95),
                                Color(red: 0.55, green: 0.70, blue: 0.85).opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: max(4, dynamicHeight))
                    .animation(.easeOut(duration: 0.08), value: audioLevel)
            }
        }
        .frame(height: 70)
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

