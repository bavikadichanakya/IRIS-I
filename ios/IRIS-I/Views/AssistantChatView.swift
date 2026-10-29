//
//  AssistantChatView.swift
//  IRIS-I
//
//  Main conversational interface for the standalone IRIS assistant.
//  Exposes on-device ReAct execution, real-time token streaming, tool call badges,
//  and latency breakdown metrics.
//

import SwiftUI

public struct ChatDisplayMessage: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let role: String // "user", "assistant", "system"
    public let content: String
    public let executedTools: [String]
    public let durationMs: Double?

    public init(role: String, content: String, executedTools: [String] = [], durationMs: Double? = nil) {
        self.role = role
        self.content = content
        self.executedTools = executedTools
        self.durationMs = durationMs
    }
}

public struct AssistantChatView: View {
    @State private var messages: [ChatDisplayMessage] = [
        ChatDisplayMessage(
            role: "assistant",
            content: "Hello! I am IRIS, your on-device AI assistant. How can I help you today?"
        )
    ]
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var activeStreamingText: String = ""
    @State private var activeToolName: String? = nil

    @State private var pendingTicket: ConfirmationTicket? = nil
    @State private var isShowingConfirmation: Bool = false

    private let orchestrator = ReActOrchestrator.shared

    private let quickPrompts = [
        "What is the time?",
        "Latest updates in AI",
        "Check my mail for OpenAI",
        "Battery status",
        "Open Spotify"
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("IRIS Standalone")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    Text("100% On-Device • Apple A19")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)

            // Message Scroll View
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { msg in
                            messageBubble(for: msg)
                        }

                        if !activeStreamingText.isEmpty {
                            streamingBubble()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
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
                        Button(action: {
                            submitQuery(prompt)
                        }) {
                            Text(prompt)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .cornerRadius(16)
                        }
                        .disabled(isProcessing)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }

            Divider()

            // Input Bar
            HStack(spacing: 8) {
                TextField("Ask IRIS anything...", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                    .disabled(isProcessing)
                    .onSubmit {
                        if !inputText.isEmpty {
                            let text = inputText
                            inputText = ""
                            submitQuery(text)
                        }
                    }

                Button(action: {
                    if isProcessing {
                        Task { await orchestrator.cancel() }
                    } else if !inputText.isEmpty {
                        let text = inputText
                        inputText = ""
                        submitQuery(text)
                    }
                }) {
                    Image(systemName: isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(isProcessing ? .red : .blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
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
                Text("Tool: \(ticket.toolName)\nAre you sure you want to proceed with this sensitive action?")
            }
        }
    }

    private func messageBubble(for msg: ChatDisplayMessage) -> some View {
        HStack {
            if msg.role == "user" {
                Spacer()
                Text(msg.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(18)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    // Tool badges if any tools were executed
                    if !msg.executedTools.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(msg.executedTools, id: \.self) { tName in
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 8))
                                    Text(tName)
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                            }
                        }
                    }

                    Text(msg.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(18)

                    if let ms = msg.durationMs {
                        Text(String(format: "%.1f ms", ms))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .padding(.leading, 6)
                    }
                }
                Spacer()
            }
        }
    }

    private func streamingBubble() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let tool = activeToolName {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 9))
                        Text("Running \(tool)...")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }

                Text(activeStreamingText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(18)
            }
            Spacer()
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func submitQuery(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        messages.append(ChatDisplayMessage(role: "user", content: query))
        isProcessing = true
        activeStreamingText = ""
        activeToolName = nil

        Task {
            let response = await orchestrator.process(
                userPrompt: query,
                progressStream: { chunk in
                    Task { @MainActor in
                        if chunk.contains("[Executing ") {
                            let toolPart = chunk.replacingOccurrences(of: "\n[Executing ", with: "")
                                .replacingOccurrences(of: "...]\n", with: "")
                            self.activeToolName = toolPart
                        } else {
                            self.activeStreamingText += chunk
                        }
                    }
                }
            )

            await MainActor.run {
                self.isProcessing = false
                self.activeStreamingText = ""
                self.activeToolName = nil

                if response.requiresConfirmation, let ticket = response.pendingConfirmationTicket {
                    self.pendingTicket = ticket
                    self.isShowingConfirmation = true
                }

                self.messages.append(ChatDisplayMessage(
                    role: "assistant",
                    content: response.textResponse,
                    executedTools: response.executedTools,
                    durationMs: response.totalDurationMs
                ))
            }
        }
    }

    private func confirmAndExecute(ticket: ConfirmationTicket) {
        isProcessing = true
        activeToolName = ticket.toolName
        Task {
            let response = await orchestrator.executeConfirmedAction(
                ticketId: ticket.ticketId,
                parameters: ticket.rawParameters
            )
            await MainActor.run {
                self.isProcessing = false
                self.activeToolName = nil
                self.pendingTicket = nil
                self.messages.append(ChatDisplayMessage(
                    role: "assistant",
                    content: response.textResponse,
                    executedTools: response.executedTools,
                    durationMs: response.totalDurationMs
                ))
            }
        }
    }
}

