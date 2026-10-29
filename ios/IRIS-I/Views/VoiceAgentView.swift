//
//  VoiceAgentView.swift
//  IRIS-I
//
//  Complete 3-Stage Voice Experience matching Screens 1, 2, and 3:
//  - Stage 1: Main Interface ("IRIS / Your personal assistant / Always with you", Pearl Orb, "Hey IRIS" capsule).
//  - Stage 2: Listening / Thinking (Live audio-reactive waveform, radiating ripples, "I'm listening", [X] / [■] controls).
//  - Stage 3: Response / Execution (Top query chip, Apple Intelligence step-by-step checklist, native result card, suggestion pills).
//

import SwiftUI

public struct ExecutionStepItem: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public var isCompleted: Bool
}

public struct VoiceAgentView: View {
    @StateObject private var speechManager = SpeechManager.shared
    @StateObject private var brainCoordinator = BrainDownloadCoordinator.shared

    @State private var executedTools: [String] = []
    @State private var activeAppIcon: String = "app.badge.fill"
    @State private var activeAppName: String = "App"
    @State private var activeResultTitle: String = "Opened successfully"
    @State private var executionSteps: [ExecutionStepItem] = []
    @State private var isShowingResult: Bool = false
    @State private var pendingTicket: ConfirmationTicket? = nil
    @State private var isShowingConfirmation: Bool = false
    @State private var textInputQuery: String = ""
    @State private var isShowingKeyboardInput: Bool = false

    private let orchestrator = ReActOrchestrator.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Clean Pearlescent Canvas
                Color(red: 0.96, green: 0.96, blue: 0.98)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Navigation Header
                    topNavigationHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    Spacer(minLength: 8)

                    // Main Interactive Content Area (Stages 1, 2, or 3)
                    if isShowingResult {
                        executionResultStage
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                removal: .opacity
                            ))
                    } else if speechManager.state == .listening || speechManager.state == .processing {
                        listeningThinkingStage
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                removal: .opacity
                            ))
                    } else {
                        mainIdleStage
                            .transition(.opacity)
                    }

                    Spacer(minLength: 8)

                    // Bottom Floating Action or Controls
                    bottomControlArea
                        .padding(.horizontal, 20)
                        .padding(.bottom, 96) // Space for floating tab bar
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.8), value: speechManager.state)
            .animation(.spring(response: 0.38, dampingFraction: 0.8), value: isShowingResult)
            .confirmationDialog(
                "Action Authorization Required",
                isPresented: $isShowingConfirmation,
                titleVisibility: .visible
            ) {
                if let ticket = pendingTicket {
                    Button("Authorize \(ticket.toolName)") {
                        confirmAndExecute(ticket: ticket)
                    }
                    Button("Cancel", role: .cancel) {
                        pendingTicket = nil
                    }
                }
            } message: {
                if let ticket = pendingTicket {
                    Text("Requires authorization for \(ticket.toolName).")
                }
            }
            .sheet(isPresented: $isShowingKeyboardInput) {
                NavigationStack {
                    VStack(spacing: 20) {
                        TextField("Ask IRIS anything...", text: $textInputQuery)
                            .textFieldStyle(.roundedBorder)
                            .padding()

                        Button("Submit") {
                            isShowingKeyboardInput = false
                            if !textInputQuery.isEmpty {
                                triggerVoiceQuery(textInputQuery)
                                textInputQuery = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .navigationTitle("Type to IRIS")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.fraction(0.35)])
            }
        }
    }

    // MARK: - Stage 1: Main Idle Interface (Screen 1)

    private var mainIdleStage: some View {
        VStack(spacing: 20) {
            // Typography Header
            VStack(spacing: 6) {
                Text("IRIS")
                    .font(.system(size: 38, weight: .bold, design: .default))
                    .tracking(1.5)
                    .foregroundColor(.black)

                Text("Your personal assistant")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(white: 0.35))

                Text("Always with you.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(white: 0.45))
            }
            .padding(.top, 10)

            Spacer(minLength: 16)

            // Center 3D Pearlescent Liquid Glass Orb
            PearlOrbView(
                size: 260,
                audioLevel: speechManager.audioLevel,
                isListening: false,
                isThinking: false
            ) {
                toggleListening()
            }

            Spacer(minLength: 16)
        }
    }

    // MARK: - Stage 2: Listening / Thinking Interface (Screen 2)

    private var listeningThinkingStage: some View {
        VStack(spacing: 16) {
            // Top Status Capsule
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                Text(speechManager.state == .processing ? "Thinking..." : "Listening...")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)

                Spacer()

                Button {
                    speechManager.stopListeningInternal()
                    Task { await speechManager.startListening() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(white: 0.40))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(width: 220)
            .background(Color.white.opacity(0.95))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)

            // Live Audio Reactive Waveform
            LiveWaveformView(audioLevel: speechManager.audioLevel)
                .padding(.horizontal, 24)

            // Center Pearl Orb with Audio Ripples
            PearlOrbView(
                size: 210,
                audioLevel: speechManager.audioLevel,
                isListening: speechManager.state == .listening,
                isThinking: speechManager.state == .processing
            ) {
                toggleListening()
            }

            // State Text
            VStack(spacing: 4) {
                Text(speechManager.state == .processing ? "Processing..." : "I'm listening")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)

                Text(speechManager.recognizedText.isEmpty ? "Speak naturally" : "\"\(speechManager.recognizedText)\"")
                    .font(.system(size: 15))
                    .foregroundColor(Color(white: 0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Stage 3: Response & Execution Interface (Screen 3)

    private var executionResultStage: some View {
        VStack(spacing: 14) {
            // Top Query Chip with Edit Pencil
            HStack(spacing: 8) {
                Text(speechManager.recognizedText.isEmpty ? "Requested Action" : speechManager.recognizedText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.40))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)

            // Step-by-Step Apple Intelligence Progress Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    PearlOrbView(size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("IRIS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(white: 0.40))
                        Text(activeAppName.isEmpty ? "Executing..." : "Opening \(activeAppName)...")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(executionSteps) { step in
                        HStack(spacing: 8) {
                            Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundColor(step.isCompleted ? .black : Color(white: 0.50))
                            Text(step.title)
                                .font(.system(size: 13, weight: step.isCompleted ? .medium : .regular))
                                .foregroundColor(step.isCompleted ? .black : Color(white: 0.40))
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
            .padding(.horizontal, 20)

            // Result App Badge Card
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.85), Color.pink.opacity(0.95), Color.orange.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: activeAppIcon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(activeAppName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)

                Text(activeResultTitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.35))
            }
            .padding(.vertical, 10)

            // Quick Suggestions Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    suggestionChip(title: "Open YouTube", icon: "play.circle.fill") {
                        triggerVoiceQuery("Open YouTube")
                    }
                    suggestionChip(title: "Play music", icon: "music.note") {
                        triggerVoiceQuery("Open Apple Music")
                    }
                    suggestionChip(title: "Take a photo", icon: "camera.fill") {
                        triggerVoiceQuery("Open Camera")
                    }
                    suggestionChip(title: "Open Spotify", icon: "waveform") {
                        triggerVoiceQuery("Open Spotify")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func suggestionChip(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.9))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
            .foregroundColor(.black)
        }
        .buttonStyle(ScaleOnPressStyle())
    }

    // MARK: - Top Navigation Header

    private var topNavigationHeader: some View {
        HStack {
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
            }

            Spacer()

            if speechManager.wakeWordDetected {
                HStack(spacing: 5) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Wake Word Active")
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.12))
                .cornerRadius(12)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    resetToIdle()
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                }
            }
        }
    }

    // MARK: - Bottom Control Area

    private var bottomControlArea: some View {
        Group {
            if isShowingResult {
                // Return to idle / Dismiss bar
                Button {
                    resetToIdle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.black)
                        Text("Ask another request")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                }
                .buttonStyle(ScaleOnPressStyle())
            } else if speechManager.state == .listening || speechManager.state == .processing {
                // Listening Controls: Cancel [X] and Stop [■]
                HStack(spacing: 40) {
                    Button {
                        speechManager.stopListeningInternal()
                        resetToIdle()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(white: 0.35))
                            .frame(width: 52, height: 52)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                    }

                    Button {
                        speechManager.stopListeningInternal()
                        if !speechManager.recognizedText.isEmpty {
                            triggerVoiceQuery(speechManager.recognizedText)
                        } else {
                            resetToIdle()
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black)
                            .frame(width: 18, height: 18)
                            .frame(width: 52, height: 52)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                    }
                }
            } else {
                // Idle "Hey IRIS" Bottom Floating Capsule Card
                Button {
                    toggleListening()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hey IRIS")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            Text("Tap to speak or just say it")
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.40))
                        }

                        Spacer()

                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.06))
                                .frame(width: 38, height: 38)
                            Image(systemName: "mic.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.8), lineWidth: 1.2)
                    )
                }
                .buttonStyle(ScaleOnPressStyle())
            }
        }
    }

    // MARK: - Actions & Logic

    private func resetToIdle() {
        speechManager.recognizedText = ""
        speechManager.spokenResponse = ""
        isShowingResult = false
        speechManager.state = .idle
    }

    private func toggleListening() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if speechManager.state == .listening {
            speechManager.stopListeningInternal()
            if !speechManager.recognizedText.isEmpty {
                triggerVoiceQuery(speechManager.recognizedText)
            }
        } else {
            isShowingResult = false
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

        // Extract app target name if launch query
        let low = query.lowercased()
        if low.contains("instagram") {
            activeAppName = "Instagram"
            activeAppIcon = "camera.circle.fill"
        } else if low.contains("music") {
            activeAppName = "Apple Music"
            activeAppIcon = "music.note"
        } else if low.contains("spotify") {
            activeAppName = "Spotify"
            activeAppIcon = "waveform"
        } else if low.contains("youtube") {
            activeAppName = "YouTube"
            activeAppIcon = "play.circle.fill"
        } else if low.contains("camera") || low.contains("photo") {
            activeAppName = "Camera"
            activeAppIcon = "camera.fill"
        } else {
            activeAppName = "Action"
            activeAppIcon = "sparkles"
        }

        // Initialize progressive checklist
        executionSteps = [
            ExecutionStepItem(title: "Understanding request", isCompleted: true),
            ExecutionStepItem(title: "Resolving capability & device policy", isCompleted: true),
            ExecutionStepItem(title: "Executing \(activeAppName)", isCompleted: false),
            ExecutionStepItem(title: "Done!", isCompleted: false)
        ]

        let response = await orchestrator.process(userPrompt: query)

        self.executedTools = response.executedTools
        self.speechManager.spokenResponse = response.textResponse

        // Mark execution complete
        if executionSteps.count >= 4 {
            executionSteps[2].isCompleted = true
            executionSteps[3].isCompleted = true
        }

        activeResultTitle = response.textResponse
        withAnimation {
            isShowingResult = true
        }

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
}

fileprivate struct ScaleOnPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    VoiceAgentView()
}
