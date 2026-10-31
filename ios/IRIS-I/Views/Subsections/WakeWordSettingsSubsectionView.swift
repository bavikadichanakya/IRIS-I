//
//  WakeWordSettingsSubsectionView.swift
//  IRIS-I
//
//  Subsection: Wake Word & Hands-Free Activation Configuration.
//  Configures wake word sensitivity, background listener, and threshold calibration.
//

import SwiftUI

public struct WakeWordSettingsSubsectionView: View {
    @ObservedObject private var speechManager = SpeechManager.shared
    @State private var selectedPhrase: String = "Hey IRIS"
    @State private var sensitivityIndex: Int = 1 // 0: Low, 1: Standard, 2: High
    @State private var isCalibrating: Bool = false
    @State private var liveAudioLevel: Float = 0.0

    private let phraseOptions = ["Hey IRIS", "IRIS"]
    private let sensitivityLevels = ["Low", "Standard", "High"]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Visual
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundColor(.purple)
                    }

                    Text("Hands-Free Activation")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    Text("Trigger IRIS without touching your screen using high-efficiency on-device neural acoustic detection.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
                .padding(.horizontal, 20)

                // Wake Phrase Picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("ACTIVATION PHRASE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                        .padding(.horizontal, 24)

                    VStack(spacing: 0) {
                        ForEach(phraseOptions, id: \.self) { phrase in
                            Button {
                                selectedPhrase = phrase
                            } label: {
                                HStack {
                                    Text(phrase)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                    Spacer()
                                    if selectedPhrase == phrase {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.purple)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            if phrase != phraseOptions.last {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                    .padding(.horizontal, 20)
                }

                // Sensitivity Control
                VStack(alignment: .leading, spacing: 10) {
                    Text("DETECTION SENSITIVITY")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                        .padding(.horizontal, 24)

                    VStack(spacing: 14) {
                        Picker("Sensitivity", selection: $sensitivityIndex) {
                            ForEach(0..<sensitivityLevels.count, id: \.self) { idx in
                                Text(sensitivityLevels[idx]).tag(idx)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(sensitivityDescription)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                    .padding(.horizontal, 20)
                }

                // Live Calibration / Meter
                VStack(alignment: .leading, spacing: 10) {
                    Text("MIC SENSITIVITY CALIBRATION")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        HStack {
                            Text("Acoustic Input Level")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            Spacer()
                            Text(speechManager.audioLevel > 0.05 ? "Signal Detected" : "Quiet")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(speechManager.audioLevel > 0.05 ? .green : .secondary)
                        }

                        // Live audio level gauge
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.06))
                                    .frame(height: 12)

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, .yellow, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(speechManager.audioLevel))), height: 12)
                                    .animation(.easeOut(duration: 0.1), value: speechManager.audioLevel)
                            }
                        }
                        .frame(height: 12)

                        HStack {
                            Text("Threshold")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.50))
                            Spacer()
                            Text("A19 Neural Acoustic Engine")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                    .padding(.horizontal, 20)
                }

                // Background Toggle
                VStack(alignment: .leading, spacing: 10) {
                    Text("BACKGROUND OPERATION")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                        .padding(.horizontal, 24)

                    VStack(spacing: 0) {
                        Toggle(isOn: $speechManager.isBackgroundWakeWordEnabled) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Listen While In Background")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black)
                                Text("Requires AVAudioSession background audio capability")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.45))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 40)
        }
        .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
        .navigationTitle("Wake Word")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sensitivityDescription: String {
        switch sensitivityIndex {
        case 0:
            return "Low: Reduces false activations in noisy environments. Requires louder speaking voice."
        case 1:
            return "Standard: Recommended default. Balanced for conversational volume at arm's length."
        default:
            return "High: Detects whispering and distant triggers across the room."
        }
    }
}

#Preview {
    NavigationStack {
        WakeWordSettingsSubsectionView()
    }
}

