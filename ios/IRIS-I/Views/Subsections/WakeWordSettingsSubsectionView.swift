//
//  WakeWordSettingsSubsectionView.swift
//  IRIS-I
//
//  Subsection: Wake Word & Hands-Free Activation Configuration.
//  Configures genuine on-device acoustic wake-word detection, sensitivity calibration,
//  live RMS input telemetry, and honest iOS background execution diagnostic states.
//

import SwiftUI

public struct WakeWordSettingsSubsectionView: View {
    @ObservedObject private var speechManager = SpeechManager.shared
    @ObservedObject private var detector = WakeWordDetector.shared

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

                    Text("Hands-Free Activation (Experimental)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    Text("Experimental on-device acoustic envelope detector (energy & zero-crossing heuristics). Not a neural speech model. Use Action Button or Siri for guaranteed instant activation.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(detector.isListening ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(detector.isListening ? "Heuristic Detector Active" : "Detector Idle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(detector.isListening ? .green : .orange)
                    }
                    .padding(.top, 4)
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
                        ForEach(WakeWordPhrase.allCases, id: \.self) { phrase in
                            Button {
                                detector.selectedPhrase = phrase
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(phrase.rawValue)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.black)
                                        Text(phrase == .heyIris ? "Default bilateral phonetic signature (/heɪ aɪ.rɪs/)" : "Compact single-word acoustic trigger (/aɪ.rɪs/)")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(white: 0.50))
                                    }
                                    Spacer()
                                    if detector.selectedPhrase == phrase {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.purple)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            if phrase != WakeWordPhrase.allCases.last {
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
                        Picker("Sensitivity", selection: $detector.sensitivity) {
                            ForEach(WakeWordSensitivity.allCases, id: \.self) { sens in
                                Text(sens.title).tag(sens)
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
                    Text("LIVE ACOUSTIC TELEMETRY")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        HStack {
                            Text("Acoustic Input Level")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            Spacer()
                            Text(effectiveAudioLevel > 0.05 ? "Signal Detected" : "Quiet")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(effectiveAudioLevel > 0.05 ? .green : .secondary)
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
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(effectiveAudioLevel))), height: 12)
                                    .animation(.easeOut(duration: 0.1), value: effectiveAudioLevel)
                            }
                        }
                        .frame(height: 12)

                        HStack {
                            Text("Threshold: \(String(format: "%.2f", detector.sensitivity.detectionThreshold))")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.50))
                            Spacer()
                            Text("Detections: \(detector.detectionCount)")
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

                // iOS Background Constraints Diagnostic Card
                VStack(alignment: .leading, spacing: 10) {
                    Text("IOS BACKGROUND ARCHITECTURE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                        .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(detector.backgroundExecutionState.isCapableOfAcousticDetection ? Color.green : Color.orange)
                                .frame(width: 10, height: 10)
                            Text("Current State: \(detector.backgroundExecutionState.rawValue)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                        }

                        Text(detector.backgroundExecutionState.explanation)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.40))
                            .lineSpacing(2)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Legitimate Invocation Paths:")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)

                            bulletRow(icon: "button.programmable", text: "Action Button: 100% reliable instant foreground invocation.")
                            bulletRow(icon: "waveform.badge.mic", text: "Siri & App Intents: Available globally even while device is locked.")
                            bulletRow(icon: "slider.horizontal.3", text: "Shortcuts: Integrates with back-tap, Lock Screen, and Control Center.")
                            bulletRow(icon: "mic.fill", text: "Foreground: Continuous acoustic detection for \"Hey IRIS\".")
                        }
                    }
                    .padding(16)
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

    private var effectiveAudioLevel: Float {
        detector.liveRMS > 0.0 ? detector.liveRMS : speechManager.audioLevel
    }

    private func bulletRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.purple)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.45))
        }
    }

    private var sensitivityDescription: String {
        switch detector.sensitivity {
        case .low:
            return "Low (Threshold 0.82): Minimizes false activations in loud rooms. Requires clear speaking volume."
        case .standard:
            return "Standard (Threshold 0.70): Recommended default. Balanced for conversational volume at normal distance."
        case .high:
            return "High (Threshold 0.58): Maximum sensitivity. Detects quieter speech across a quiet room."
        }
    }
}
