//
//  VoiceSettingsSubsectionView.swift
//  IRIS-I
//
//  Subsection: Voice & Speech Output Configuration.
//  Configures voice personality, speaking rate, pitch, and audio feedback.
//

import SwiftUI
import AVFoundation

public struct VoiceOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let sampleText: String
    public let icon: String
}

public struct VoiceSettingsSubsectionView: View {
    @Binding public var selectedVoice: String
    @State private var speakingRate: Double = 1.0
    @State private var voicePitch: Double = 1.0
    @State private var isPlayingSample: Bool = false
    @State private var autoRouteAirPods: Bool = true
    @State private var hapticFeedbackOnResponse: Bool = true

    private let synthesizer = AVSpeechSynthesizer()

    private let availableVoices: [VoiceOption] = [
        VoiceOption(
            id: "iris_default",
            name: "IRIS (Neural)",
            description: "Warm, natural, and expressive default assistant voice",
            sampleText: "Hello! I am IRIS, ready to assist you on your device.",
            icon: "sparkles"
        ),
        VoiceOption(
            id: "nova_expressive",
            name: "Nova (Expressive)",
            description: "Energetic and crisp female tone",
            sampleText: "All system parameters are nominal and running smoothly.",
            icon: "waveform"
        ),
        VoiceOption(
            id: "alloy_neutral",
            name: "Alloy (Neutral)",
            description: "Balanced, calm, and objective speech",
            sampleText: "I have prepared your daily agenda and notifications.",
            icon: "person.wave.2.fill"
        ),
        VoiceOption(
            id: "echo_smooth",
            name: "Echo (Deep Male)",
            description: "Authoritative and resonant male voice",
            sampleText: "Neural inference running with zero cloud latency.",
            icon: "mic.fill"
        )
    ]

    public init(selectedVoice: Binding<String>? = nil) {
        if let binding = selectedVoice {
            self._selectedVoice = binding
        } else {
            self._selectedVoice = .constant("IRIS (Neural)")
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Visual Orb Card
                VStack(spacing: 12) {
                    PearlOrbView(size: 70, audioLevel: isPlayingSample ? 0.6 : 0.0, isResponding: isPlayingSample)
                    Text("Speech & Audio Output")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    Text("Select voice personality and tune speech characteristics.")
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

                // Voice Selection List
                VStack(alignment: .leading, spacing: 10) {
                    Text("ASSISTANT VOICES")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                        .padding(.horizontal, 24)

                    VStack(spacing: 0) {
                        ForEach(availableVoices) { voice in
                            Button {
                                selectedVoice = voice.name
                                playSample(for: voice)
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(selectedVoice == voice.name ? Color.blue.opacity(0.15) : Color.black.opacity(0.05))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: voice.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(selectedVoice == voice.name ? .blue : .gray)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(voice.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.black)
                                        Text(voice.description)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(white: 0.45))
                                    }

                                    Spacer()

                                    if selectedVoice == voice.name {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }

                            if voice.id != availableVoices.last?.id {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                    .padding(.horizontal, 20)
                }

                // Tuning Sliders
                VStack(alignment: .leading, spacing: 10) {
                    Text("SPEECH CHARACTERISTICS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                        .padding(.horizontal, 24)

                    VStack(spacing: 16) {
                        // Rate Slider
                        VStack(spacing: 8) {
                            HStack {
                                Text("Speaking Rate")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black)
                                Spacer()
                                Text(String(format: "%.1fx", speakingRate))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            Slider(value: $speakingRate, in: 0.5...1.8, step: 0.1)
                                .tint(.blue)
                        }

                        Divider()

                        // Pitch Slider
                        VStack(spacing: 8) {
                            HStack {
                                Text("Voice Pitch")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black)
                                Spacer()
                                Text(String(format: "%.1fx", voicePitch))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            Slider(value: $voicePitch, in: 0.5...1.5, step: 0.1)
                                .tint(.blue)
                        }

                        Divider()

                        // Test Audio Button
                        Button {
                            playCurrentSettingsSample()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isPlayingSample ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(isPlayingSample ? "Stop Audio Sample" : "Play Voice Preview")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(18)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                    .padding(.horizontal, 20)
                }

                // Audio Routing Toggles
                VStack(alignment: .leading, spacing: 10) {
                    Text("HARDWARE & ROUTING")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                        .padding(.horizontal, 24)

                    VStack(spacing: 0) {
                        Toggle(isOn: $autoRouteAirPods) {
                            HStack(spacing: 12) {
                                Image(systemName: "airpodspro")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                Text("AirPods Priority Routing")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().padding(.leading, 46)

                        Toggle(isOn: $hapticFeedbackOnResponse) {
                            HStack(spacing: 12) {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(.orange)
                                Text("Haptic Response Pulse")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black)
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
        .navigationTitle("Voice & Speech")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func playSample(for voice: VoiceOption) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: voice.sampleText)
        utterance.rate = Float(speakingRate * 0.5)
        utterance.pitchMultiplier = Float(voicePitch)
        isPlayingSample = true
        synthesizer.speak(utterance)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            isPlayingSample = false
        }
    }

    private func playCurrentSettingsSample() {
        if isPlayingSample {
            synthesizer.stopSpeaking(at: .immediate)
            isPlayingSample = false
        } else {
            let utterance = AVSpeechUtterance(string: "Testing IRIS voice parameters. All systems are operating normally.")
            utterance.rate = Float(speakingRate * 0.5)
            utterance.pitchMultiplier = Float(voicePitch)
            isPlayingSample = true
            synthesizer.speak(utterance)

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                isPlayingSample = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        VoiceSettingsSubsectionView()
    }
}

