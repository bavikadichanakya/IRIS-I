//
//  AssistantChatView.swift
//  IRIS-I
//
//  Screen 5: Conversational Interface with Rich Action & File Artifacts.
//  Exposes on-device ReAct execution, real-time token streaming, tool call badges,
//  and rich document artifact cards.
//

import SwiftUI

public struct ChatDisplayMessage: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let role: String // "user", "assistant", "system"
    public let content: String
    public let executedTools: [String]
    public let durationMs: Double?
    public let attachedDocumentName: String?
    public let attachedDocumentSize: String?

    public init(
        role: String,
        content: String,
        executedTools: [String] = [],
        durationMs: Double? = nil,
        attachedDocumentName: String? = nil,
        attachedDocumentSize: String? = nil
    ) {
        self.role = role
        self.content = content
        self.executedTools = executedTools
        self.durationMs = durationMs
        self.attachedDocumentName = attachedDocumentName
        self.attachedDocumentSize = attachedDocumentSize
    }
}

public struct AssistantChatView: View {
    @State private var messages: [ChatDisplayMessage] = [
        ChatDisplayMessage(
            role: "assistant",
            content: "Hello! I am IRIS, your personal on-device assistant. How can I help you today?"
        ),
        ChatDisplayMessage(
            role: "assistant",
            content: "I found the document you requested from your device storage:",
            executedTools: ["FilesTool"],
            durationMs: 14.2,
            attachedDocumentName: "Cybersecurity_Report.pdf",
            attachedDocumentSize: "2.1 MB · Documents"
        )
    ]
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var activeStreamingText: String = ""
    @State private var activeToolName: String? = nil

    @State private var pendingTicket: ConfirmationTicket? = nil
    @State private var isShowingConfirmation: Bool = false
    @State private var isShowingDrawerMenu: Bool = false

    @StateObject private var speechManager = SpeechManager.shared
    @StateObject private var brainCoordinator = BrainDownloadCoordinator.shared

    private let orchestrator = ReActOrchestrator.shared

    private let quickPrompts = [
        "Open Instagram",
        "Battery status",
        "Open Apple Music",
        "Latest updates in AI",
        "Check calendar"
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Clean Canvas
                Color(red: 0.96, green: 0.96, blue: 0.98)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Bar matching Screen 5
                    HStack {
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            isShowingDrawerMenu = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                        }

                        Spacer()

                        Text("IRIS")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)

                        Spacer()

                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            messages = [
                                ChatDisplayMessage(
                                    role: "assistant",
                                    content: "Started a new conversation. What would you like to do?"
                                )
                            ]
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Message Scroll View
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(messages) { msg in
                                    messageBubble(for: msg)
                                }

                                if !activeStreamingText.isEmpty {
                                    streamingBubble()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 12)
                        }
                        .onChange(of: messages.count) { _ in
                            scrollToBottom(proxy: proxy)
                        }
                        .onChange(of: activeStreamingText) { _ in
                            scrollToBottom(proxy: proxy)
                        }
                    }

                    // Quick Prompt Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickPrompts, id: \.self) { prompt in
                                Button {
                                    submitQuery(prompt)
                                } label: {
                                    Text(prompt)
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color.white)
                                        .cornerRadius(16)
                                        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
                                        .foregroundColor(.black)
                                }
                                .disabled(isProcessing)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                    }

                    // Floating Glass Input Bar matching Screen 5
                    HStack(spacing: 10) {
                        TextField("Message IRIS...", text: $inputText)
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                            .textFieldStyle(.plain)
                            .disabled(isProcessing)
                            .onSubmit {
                                if !inputText.isEmpty {
                                    let text = inputText
                                    inputText = ""
                                    submitQuery(text)
                                }
                            }

                        Button {
                            if speechManager.state == .listening {
                                let query = speechManager.stopListening()
                                if !query.isEmpty {
                                    inputText = query
                                    submitQuery(query)
                                }
                            } else {
                                Task {
                                    await speechManager.startListening()
                                }
                            }
                        } label: {
                            Image(systemName: speechManager.state == .listening ? "mic.fill" : "mic")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(speechManager.state == .listening ? .red : .black)
                        }

                        if !inputText.isEmpty || isProcessing {
                            Button {
                                if isProcessing {
                                    Task { await orchestrator.cancel() }
                                } else if !inputText.isEmpty {
                                    let text = inputText
                                    inputText = ""
                                    submitQuery(text)
                                }
                            } label: {
                                Image(systemName: isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.92))
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 96) // Space for floating tab bar
                }
            }
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
            .sheet(isPresented: $isShowingDrawerMenu) {
                QuickDrawerMenuSubsectionView()
            }
        }
    }

    // MARK: - Message Bubble Views

    private func messageBubble(for msg: ChatDisplayMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if msg.role == "assistant" {
                PearlOrbView(size: 28)
                    .padding(.top, 2)
            } else {
                Spacer(minLength: 40)
            }

            VStack(alignment: msg.role == "user" ? .trailing : .leading, spacing: 6) {
                if !msg.executedTools.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(msg.executedTools, id: \.self) { tool in
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 8))
                                Text(tool)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(6)
                        }

                        if let ms = msg.durationMs {
                            Text(String(format: "%.1f ms", ms))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Text(msg.content)
                    .font(.system(size: 15))
                    .foregroundColor(msg.role == "user" ? .white : .black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        msg.role == "user" ?
                        Color.blue :
                        Color.white.opacity(0.92)
                    )
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)

                // Rich Attached Document Artifact Card (Screen 5)
                if let docName = msg.attachedDocumentName, let docSize = msg.attachedDocumentSize {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(docName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.black)
                                Text(docSize)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(white: 0.40))
                            }
                        }

                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        } label: {
                            HStack {
                                Text("Open File")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.blue)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                    .frame(maxWidth: 260)
                }
            }

            if msg.role != "user" {
                Spacer(minLength: 40)
            }
        }
    }

    private func streamingBubble() -> some View {
        HStack(alignment: .top, spacing: 10) {
            PearlOrbView(size: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                if let tool = activeToolName {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Calling \(tool)...")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }

                Text(activeStreamingText)
                    .font(.system(size: 15))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.92))
                    .cornerRadius(18)
            }
            Spacer(minLength: 40)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastId = messages.last?.id {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    private func submitQuery(_ text: String) {
        let userMessage = ChatDisplayMessage(role: "user", content: text)
        messages.append(userMessage)

        self.isProcessing = true
        self.activeStreamingText = ""
        self.activeToolName = nil

        Task {
            let start = CFAbsoluteTimeGetCurrent()
            let response = await orchestrator.process(userPrompt: text)
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

            let assistantMessage = ChatDisplayMessage(
                role: "assistant",
                content: response.textResponse,
                executedTools: response.executedTools,
                durationMs: duration
            )

            await MainActor.run {
                self.messages.append(assistantMessage)
                self.isProcessing = false
                self.activeStreamingText = ""
                self.activeToolName = nil
            }

            if response.requiresConfirmation, let ticket = response.pendingConfirmationTicket {
                await MainActor.run {
                    self.pendingTicket = ticket
                    self.isShowingConfirmation = true
                }
            }
        }
    }

    private func confirmAndExecute(ticket: ConfirmationTicket) {
        Task {
            let start = CFAbsoluteTimeGetCurrent()
            let response = await orchestrator.executeConfirmedAction(
                ticketId: ticket.ticketId,
                parameters: ticket.rawParameters
            )
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

            let assistantMessage = ChatDisplayMessage(
                role: "assistant",
                content: response.textResponse,
                executedTools: response.executedTools,
                durationMs: duration
            )

            await MainActor.run {
                self.messages.append(assistantMessage)
                self.pendingTicket = nil
            }
        }
    }
}

#Preview {
    AssistantChatView()
}
