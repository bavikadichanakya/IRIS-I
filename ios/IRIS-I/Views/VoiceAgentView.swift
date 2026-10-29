//
//  VoiceAgentView.swift
//  IRIS-I
//
//  Interactive full-screen Voice Agent interface featuring an audio-reactive
//  pulsing orb, wake-word detection ("Hey IRIS"), 1-tap local brain download & auto-activation,
//  live speech transcription, and vocalized assistant responses.
//

import SwiftUI

public struct VoiceAgentView: View {
    @StateObject private var speechManager = SpeechManager.shared
    @StateObject private var brainCoordinator = BrainDownloadCoordinator.shared

    @State private var executedTools: [String] = []
    @State private var isPulsing: Bool = false
    @State private var pendingTicket: ConfirmationTicket? = nil
    @State private var isShowingConfirmation: Bool = false

    private let orchestrator = ReActOrchestrator.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Dynamic Radial Gradient
                RadialGradient(
                    gradient: Gradient(colors: [
                        backgroundColorForState.opacity(0.35),
                        Color.black.opacity(0.96)
                    ]),
                    center: .center,
                    startRadius: 40,
                    endRadius: 500
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Top Bar: Status & Wake-word pill
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

                        HStack(spacing: 4) {
                            Image(systemName: "waveform.badge.mic")
                                .font(.caption2)
                            Text("\"Hey IRIS\"")
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(speechManager.wakeWordDetected ? Color.green.opacity(0.2) : Color.white.opacity(0.06))
                        .foregroundColor(speechManager.wakeWordDetected ? .green : .gray)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // 1-Tap Brain Download & Auto-Activation Card
                    brainDownloadBanner
                        .padding(.horizontal, 16)

                    Spacer(minLength: 10)

                    // Center Interactive Glowing Orb
                    ZStack {
                        // Outer Ambient Halo
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        orbColor.opacity(0.55),
                                        orbColor.opacity(0.0)
                                    ]),
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 160
                                )
                            )
                            .frame(width: 280, height: 280)
                            .scaleEffect(speechManager.state == .listening ? 1.0 + CGFloat(speechManager.audioLevel * 0.9) : (isPulsing ? 1.08 : 0.94))
                            .animation(.easeInOut(duration: speechManager.state == .listening ? 0.08 : 2.0).repeatForever(autoreverses: true), value: isPulsing)

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
                            .shadow(color: orbColor.opacity(0.85), radius: 32, x: 0, y: 0)
                            .scaleEffect(speechManager.state == .listening ? 1.0 + CGFloat(speechManager.audioLevel * 0.6) : 1.0)
                            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: speechManager.audioLevel)

                        // Center Icon
                        Image(systemName: iconForState)
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundColor(.white)
                            .symbolEffect(.pulse, isActive: speechManager.state == .processing)
                    }
                    .onTapGesture {
                        handleOrbTap()
                    }

                    Spacer(minLength: 10)

                    // Live Speech Transcription / Assistant Output
                    VStack(spacing: 10) {
                        if !speechManager.recognizedText.isEmpty {
                            VStack(spacing: 4) {
                                Text("YOU SAID")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.blue.opacity(0.85))
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
                                    .foregroundColor(.purple.opacity(0.85))

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
                                    .foregroundColor(.white.opacity(0.92))
                                    .padding(.horizontal, 24)
                            }
                            .transition(.opacity)
                        } else if speechManager.state == .idle && speechManager.recognizedText.isEmpty {
                            Text("Say \"Hey IRIS\" or tap to ask:")
                                .font(.caption)
                                .foregroundColor(.gray)

                            HStack(spacing: 8) {
                                voiceChip(title: "\"Open Apple Music\"") {
                                    triggerVoiceQuery("Open Apple Music")
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
                    .frame(minHeight: 110)

                    Spacer(minLength: 10)

                    // Bottom Controls Bar
                    HStack(spacing: 36) {
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
                                    .shadow(color: (speechManager.state == .listening ? Color.red : Color.blue).opacity(0.55), radius: 18)

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
                    .padding(.bottom, 18)
                }
            }
            .onAppear {
                isPulsing = true
                brainCoordinator.refreshState()
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

    // MARK: - Brain Download Banner

    @ViewBuilder
    private var brainDownloadBanner: some View {
        if brainCoordinator.isDownloading {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Downloading Qwen 2.5 3B Brain")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(brainCoordinator.downloadProgress * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                }

                ProgressView(value: brainCoordinator.downloadProgress)
                    .tint(.cyan)

                HStack {
                    Text(brainCoordinator.statusMessage)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                    Button("Cancel") {
                        brainCoordinator.cancelDownload()
                    }
                    .font(.caption2.bold())
                    .foregroundColor(.red)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.07))
            .cornerRadius(12)
        } else if !brainCoordinator.isModelInstalled && !brainCoordinator.isModelActive {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🧠 Neural Brain (Qwen 2.5 · 1.95 GB)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text("Tap to download & auto-activate locally")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button(action: {
                    brainCoordinator.downloadAndActivateBrain()
                }) {
                    Text("Download")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Button(action: {
                    brainCoordinator.activateInstantMockBrain()
                }) {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                        .padding(6)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.yellow)
                        .cornerRadius(8)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
        } else if brainCoordinator.isModelActive {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.green)
                Text("Brain: Qwen 2.5 3B Active (100% On-Device)")
                    .font(.caption2.bold())
                    .foregroundColor(.green)
                Spacer()
                Text("A19 Neural")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.12))
            .cornerRadius(10)
        }
    }

    // MARK: - Actions

    private func handleOrbTap() {
        if speechManager.state == .listening {
            let text = speechManager.stopListening()
            if !text.isEmpty {
                Task {
                    await executeVoiceQuery(text)
                }
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
        self.speechManager.state = .processing
        self.executedTools = []

        let response = await orchestrator.process(userPrompt: query)

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

    private func confirmAndExecute(ticket: ConfirmationTicket) {
        Task {
            let response = await orchestrator.executeConfirmedAction(
                ticketId: ticket.ticketId,
                parameters: ticket.rawParameters
            )
            self.executedTools = response.executedTools
            self.speechManager.spokenResponse = response.textResponse
            self.speechManager.speak(text: response.textResponse)
            self.pendingTicket = nil
        }
    }

    private func voiceChip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(14)
        }
    }

    // MARK: - Orb Visual State Mappings

    private var statusText: String {
        switch speechManager.state {
        case .idle:
            return "READY"
        case .listening:
            return "LISTENING..."
        case .processing:
            return "THINKING..."
        case .speaking:
            return "SPEAKING"
        }
    }

    private var statusColor: Color {
        switch speechManager.state {
        case .idle:
            return .green
        case .listening:
            return .blue
        case .processing:
            return .purple
        case .speaking:
            return .orange
        }
    }

    private var orbColor: Color {
        switch speechManager.state {
        case .idle:
            return Color.blue
        case .listening:
            return Color.cyan
        case .processing:
            return Color.purple
        case .speaking:
            return Color.pink
        }
    }

    private var orbSecondaryColor: Color {
        switch speechManager.state {
        case .idle:
            return Color.purple.opacity(0.8)
        case .listening:
            return Color.indigo
        case .processing:
            return Color.blue
        case .speaking:
            return Color.orange
        }
    }

    private var backgroundColorForState: Color {
        switch speechManager.state {
        case .idle:
            return Color.blue
        case .listening:
            return Color.indigo
        case .processing:
            return Color.purple
        case .speaking:
            return Color.pink
        }
    }

    private var iconForState: String {
        switch speechManager.state {
        case .idle:
            return "sparkles"
        case .listening:
            return "waveform"
        case .processing:
            return "brain.head.profile"
        case .speaking:
            return "speaker.wave.3.fill"
        }
    }
}
