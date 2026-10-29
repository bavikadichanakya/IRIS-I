//
//  VoiceAgentView.swift
//  IRIS-I
//
//  Interactive full-screen Voice Agent interface featuring an audio-reactive
//  pulsing orb, live speech transcription, and vocalized assistant responses.
//

import SwiftUI

public struct VoiceAgentView: View {
    @StateObject private var speechManager = SpeechManager.shared
    @State private var executedTools: [String] = []
    @State private var orbScale: CGFloat = 1.0
    @State private var isPulsing: Bool = false

    @State private var pendingTicket: ConfirmationTicket? = nil
    @State private var isShowingConfirmation: Bool = false

    private let orchestrator = ReActOrchestrator.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Radial Gradient
                RadialGradient(
                    gradient: Gradient(colors: [
                        backgroundColorForState.opacity(0.35),
                        Color.black.opacity(0.95)
                    ]),
                    center: .center,
                    startRadius: 40,
                    endRadius: 450
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Top Status Bar
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            Text(statusText)
                                .font(.caption.bold())
                                .foregroundColor(statusColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(20)

                        Spacer()

                        Text("100% On-Device Voice")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    Spacer()

                    // Center Interactive Glowing Orb
                    ZStack {
                        // Outer Ambient Glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        orbColor.opacity(0.6),
                                        orbColor.opacity(0.0)
                                    ]),
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 160
                                )
                            )
                            .frame(width: 280, height: 280)
                            .scaleEffect(speechManager.state == .listening ? 1.0 + CGFloat(speechManager.audioLevel * 0.8) : (isPulsing ? 1.1 : 0.95))
                            .animation(.easeInOut(duration: speechManager.state == .listening ? 0.08 : 1.8).repeatForever(autoreverses: true), value: isPulsing)

                        // Middle Glowing Core
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [orbColor, orbSecondaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 140, height: 140)
                            .shadow(color: orbColor.opacity(0.8), radius: 30, x: 0, y: 0)
                            .scaleEffect(speechManager.state == .listening ? 1.0 + CGFloat(speechManager.audioLevel * 0.5) : 1.0)
                            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: speechManager.audioLevel)

                        // Center Icon / Waveform
                        Image(systemName: iconForState)
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundColor(.white)
                            .symbolEffect(.pulse, isActive: speechManager.state == .processing)
                    }
                    .onTapGesture {
                        handleOrbTap()
                    }

                    Spacer()

                    // Live Speech Transcription / Assistant Output
                    VStack(spacing: 12) {
                        if !speechManager.recognizedText.isEmpty {
                            VStack(spacing: 4) {
                                Text("YOU SAID")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.blue.opacity(0.8))
                                Text("\"\(speechManager.recognizedText)\"")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                            }
                            .transition(.opacity)
                        }

                        if !speechManager.spokenResponse.isEmpty && speechManager.state != .listening {
                            VStack(spacing: 6) {
                                Text("IRIS")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.purple.opacity(0.8))

                                if !executedTools.isEmpty {
                                    HStack(spacing: 6) {
                                        ForEach(executedTools, id: \.self) { tool in
                                            HStack(spacing: 4) {
                                                Image(systemName: "bolt.fill")
                                                    .font(.system(size: 8))
                                                Text(tool)
                                                    .font(.system(size: 10, weight: .semibold))
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.25))
                                            .foregroundColor(.orange)
                                            .cornerRadius(6)
                                        }
                                    }
                                }

                                Text(speechManager.spokenResponse)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.horizontal, 28)
                            }
                            .transition(.opacity)
                        } else if speechManager.state == .idle && speechManager.recognizedText.isEmpty {
                            Text("Tap the orb to speak, or ask:")
                                .font(.caption)
                                .foregroundColor(.gray)

                            HStack(spacing: 8) {
                                voiceChip(title: "\"Check my mail\"") {
                                    triggerVoiceQuery("Check my mail for OpenAI")
                                }
                                voiceChip(title: "\"Battery status\"") {
                                    triggerVoiceQuery("What is my battery level?")
                                }
                                voiceChip(title: "\"What time is it?\"") {
                                    triggerVoiceQuery("What time is it?")
                                }
                            }
                        }

                        if let err = speechManager.errorMessage {
                            Text(err)
                                .font(.caption2)
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                        }
                    }
                    .frame(minHeight: 120)

                    Spacer()

                    // Bottom Controls Bar
                    HStack(spacing: 32) {
                        Button(action: {
                            speechManager.stopSpeaking()
                            speechManager.stopListeningInternal()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.gray.opacity(0.7))
                        }

                        // Main Big Microphone Button
                        Button(action: {
                            handleOrbTap()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(speechManager.state == .listening ? Color.red : Color.blue)
                                    .frame(width: 76, height: 76)
                                    .shadow(color: (speechManager.state == .listening ? Color.red : Color.blue).opacity(0.5), radius: 16)

                                Image(systemName: speechManager.state == .listening ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        Button(action: {
                            if !speechManager.spokenResponse.isEmpty {
                                speechManager.speak(text: speechManager.spokenResponse)
                            }
                        }) {
                            Image(systemName: "speaker.wave.2.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.gray.opacity(0.7))
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .onAppear {
                isPulsing = true
            }
            .alert("Confirm Sensitive Action", isPresented: $isShowingConfirmation) {
                Button("Authorize", role: .destructive) {
                    if let ticket = pendingTicket {
                        confirmAndExecute(ticket: ticket)
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingTicket = nil
                }
            } message: {
                if let ticket = pendingTicket {
                    Text("Authorize \(ticket.toolName) to execute with parameter security verification?")
                }
            }
        }
    }

    private func handleOrbTap() {
        if speechManager.state == .listening {
            speechManager.stopListeningAndProcess { query in
                await executeVoiceQuery(query)
            }
        } else if speechManager.state == .speaking {
            speechManager.stopSpeaking()
        } else {
            Task {
                await speechManager.startListening()
            }
        }
    }

    private func triggerVoiceQuery(_ query: String) {
        speechManager.recognizedText = query
        speechManager.stopListeningInternal()
        Task {
            await executeVoiceQuery(query)
        }
    }

    private func executeVoiceQuery(_ query: String) async {
        await MainActor.run {
            self.speechManager.state = .processing
            self.executedTools = []
        }

        let response = await orchestrator.process(userPrompt: query)

        await MainActor.run {
            self.executedTools = response.executedTools
            self.speechManager.spokenResponse = response.textResponse

            if response.requiresConfirmation, let ticket = response.pendingConfirmationTicket {
                self.pendingTicket = ticket
                self.isShowingConfirmation = true
                self.speechManager.speak(text: "This action requires your confirmation. Please tap Authorize to proceed.")
            } else {
                self.speechManager.speak(text: response.textResponse)
            }
        }
    }

    private func confirmAndExecute(ticket: ConfirmationTicket) {
        Task {
            let response = await orchestrator.executeConfirmedAction(
                ticketId: ticket.ticketId,
                parameters: ticket.rawParameters
            )
            await MainActor.run {
                self.executedTools = response.executedTools
                self.speechManager.spokenResponse = response.textResponse
                self.speechManager.speak(text: response.textResponse)
                self.pendingTicket = nil
            }
        }
    }

    private func voiceChip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .cornerRadius(14)
        }
    }

    // Dynamic UI Styling
    private var statusText: String {
        switch speechManager.state {
        case .idle: return "Tap to Speak"
        case .listening: return "Listening..."
        case .processing: return "Reasoning..."
        case .speaking: return "Speaking"
        }
    }

    private var statusColor: Color {
        switch speechManager.state {
        case .idle: return .gray
        case .listening: return .cyan
        case .processing: return .purple
        case .speaking: return .green
        }
    }

    private var orbColor: Color {
        switch speechManager.state {
        case .idle: return Color(red: 0.2, green: 0.4, blue: 0.9)
        case .listening: return Color(red: 0.0, green: 0.8, blue: 0.9)
        case .processing: return Color(red: 0.6, green: 0.2, blue: 0.9)
        case .speaking: return Color(red: 0.1, green: 0.9, blue: 0.5)
        }
    }

    private var orbSecondaryColor: Color {
        switch speechManager.state {
        case .idle: return Color(red: 0.5, green: 0.1, blue: 0.8)
        case .listening: return Color(red: 0.2, green: 0.5, blue: 1.0)
        case .processing: return Color(red: 0.9, green: 0.3, blue: 0.7)
        case .speaking: return Color(red: 0.0, green: 0.7, blue: 0.9)
        }
    }

    private var backgroundColorForState: Color {
        switch speechManager.state {
        case .idle: return Color(red: 0.1, green: 0.1, blue: 0.3)
        case .listening: return Color(red: 0.0, green: 0.25, blue: 0.35)
        case .processing: return Color(red: 0.25, green: 0.05, blue: 0.35)
        case .speaking: return Color(red: 0.05, green: 0.3, blue: 0.2)
        }
    }

    private var iconForState: String {
        switch speechManager.state {
        case .idle: return "mic.fill"
        case .listening: return "waveform"
        case .processing: return "brain.fill"
        case .speaking: return "speaker.wave.3.fill"
        }
    }
}
