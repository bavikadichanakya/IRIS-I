//
//  ActionApprovalView.swift
//  IRIS-I
//
//  Reusable action authorization sheet conforming to Apple Liquid Glass design.
//  Presents exact parameters, cryptographic expiration, edit capability,
//  and single-use approve/reject controls across Voice and Chat interfaces.
//

import SwiftUI

public struct ActionApprovalView: View {
    public let ticket: ConfirmationTicket
    public var onApprove: (([String: Any]) -> Void)?
    public var onReject: (() -> Void)?

    @StateObject private var coordinator = ActionApprovalCoordinator.shared
    @State private var editableParameters: [String: String] = [:]
    @State private var isExecuting: Bool = false

    public init(
        ticket: ConfirmationTicket,
        onApprove: (([String: Any]) -> Void)? = nil,
        onReject: (() -> Void)? = nil
    ) {
        self.ticket = ticket
        self.onApprove = onApprove
        self.onReject = onReject

        var initialParams: [String: String] = [:]
        for (k, v) in ticket.rawParameters {
            initialParams[k] = "\(v)"
        }
        _editableParameters = State(initialValue: initialParams)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(iconColor.opacity(0.12))
                                .frame(width: 60, height: 60)
                            Image(systemName: iconName)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(iconColor)
                        }

                        VStack(spacing: 4) {
                            Text(titleText)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            Text("Sensitive action requires explicit authorization")
                                .font(.system(size: 13))
                                .foregroundColor(Color(white: 0.45))
                        }

                        HStack(spacing: 8) {
                            badge(text: ticket.toolName, color: iconColor)
                            badge(text: "Single-Use Ticket", color: .purple)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Countdown Expiration Bar
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Security Timeout")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(coordinator.timeRemainingSeconds)s remaining")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(coordinator.timeRemainingSeconds < 30 ? .red : .primary)
                        }

                        ProgressView(value: Double(coordinator.timeRemainingSeconds), total: 300.0)
                            .tint(coordinator.timeRemainingSeconds < 30 ? .red : .blue)
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)

                    // Parameters Inspection & Edit Area
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Action Parameters")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)

                        ForEach(Array(editableParameters.keys.sorted()), id: \.self) { key in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(key.capitalized)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(white: 0.45))

                                if isMultiLineParameter(key) {
                                    TextEditor(text: binding(for: key))
                                        .frame(minHeight: 90)
                                        .padding(8)
                                        .background(Color(white: 0.96))
                                        .cornerRadius(10)
                                } else {
                                    TextField(key, text: binding(for: key))
                                        .padding(10)
                                        .background(Color(white: 0.96))
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            executeApprove()
                        } label: {
                            HStack {
                                if isExecuting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                }
                                Text(isExecuting ? "Executing..." : "Authorize & Proceed")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .cornerRadius(16)
                            .shadow(color: Color.green.opacity(0.3), radius: 8, y: 3)
                        }
                        .disabled(isExecuting)

                        Button(role: .cancel) {
                            executeReject()
                        } label: {
                            Text("Decline & Cancel")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(14)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
            .navigationTitle("Authorization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { executeReject() }
                }
            }
        }
    }

    private var iconName: String {
        switch ticket.toolName {
        case "MessagingTool": return "message.fill"
        case "MailTool": return "envelope.fill"
        case "EventKitTool": return "calendar.badge.plus"
        case "PhoneCallTool": return "phone.fill"
        default: return "shield.lefthalf.filled"
        }
    }

    private var iconColor: Color {
        switch ticket.toolName {
        case "MessagingTool": return .green
        case "MailTool": return .blue
        case "EventKitTool": return .purple
        case "PhoneCallTool": return .teal
        default: return .orange
        }
    }

    private var titleText: String {
        switch ticket.toolName {
        case "MessagingTool": return "Send Text Message"
        case "MailTool": return "Send Authenticated Email"
        case "EventKitTool": return "Modify Calendar & Reminders"
        case "PhoneCallTool": return "Place Outgoing Phone Call"
        default: return "Authorize \(ticket.toolName)"
        }
    }

    private func isMultiLineParameter(_ key: String) -> Bool {
        key.lowercased() == "message" || key.lowercased() == "body" || key.lowercased() == "notes"
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { editableParameters[key] ?? "" },
            set: { editableParameters[key] = $0 }
        )
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func executeApprove() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        isExecuting = true

        var updatedRawParams: [String: Any] = ticket.rawParameters
        for (k, v) in editableParameters {
            updatedRawParams[k] = v
        }

        if let customApprove = onApprove {
            customApprove(updatedRawParams)
        } else {
            Task {
                _ = await coordinator.approve(ticket: ticket, parameters: updatedRawParams)
            }
        }
    }

    private func executeReject() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if let customReject = onReject {
            customReject()
        } else {
            coordinator.reject(ticket: ticket)
        }
    }
}

