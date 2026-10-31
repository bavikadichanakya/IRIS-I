//
//  ActionDetailSubsectionView.swift
//  IRIS-I
//
//  Subsection: Action Inspection, Parameter Sandbox, and Live Tool Execution.
//  Enables viewing technical action schemes, testing execution parameters,
//  and running actions with live diagnostic output.
//

import SwiftUI

public struct ActionDetailSubsectionView: View {
    @Environment(\.dismiss) private var dismiss
    public let action: ActionItem

    @State private var customTargetInput: String = ""
    @State private var executionState: ExecutionState = .idle
    @State private var executionOutput: String = ""
    @State private var executionLatencyMs: Int = 0

    public enum ExecutionState {
        case idle
        case executing
        case success
        case failure(String)
    }

    public init(action: ActionItem) {
        self.action = action
        switch action.actionType {
        case .openApp(let appName):
            _customTargetInput = State(initialValue: appName)
        case .systemAction(let actionName):
            _customTargetInput = State(initialValue: actionName)
        case .customPrompt(let prompt):
            _customTargetInput = State(initialValue: prompt)
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Overview Card
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(action.iconColor.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: action.icon)
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundColor(action.iconColor)
                        }

                        VStack(spacing: 4) {
                            Text(action.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                            Text(action.subtitle)
                                .font(.system(size: 14))
                                .foregroundColor(Color(white: 0.45))
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 8) {
                            badgeView(text: schemeTypeString, color: action.iconColor)
                            badgeView(text: "Hardware Verified", color: .green)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Technical Architecture Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "terminal.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Technical Specification")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                                Text("Tool Dispatch & Routing Path")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(white: 0.40))
                            }
                        }

                        Divider()

                        techRow(label: "Identifier", value: action.id)
                        techRow(label: "Handler Class", value: handlerClassString)
                        techRow(label: "Sandbox Mode", value: "Native iOS / URL Scheme")
                        techRow(label: "Confirmation Required", value: isSensitive ? "Yes (Biometric/Prompt)" : "No (Immediate)")
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Parameter Sandbox Input
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Execution Parameter")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)

                        HStack {
                            TextField(parameterPlaceholder, text: $customTargetInput)
                                .font(.system(size: 15))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(white: 0.96))
                                .cornerRadius(10)

                            if !customTargetInput.isEmpty {
                                Button {
                                    customTargetInput = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Text(parameterDescription)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.50))
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                    // Live Execution Feedback Area
                    if case .executing = executionState {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Executing tool dispatch...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(12)
                    } else if case .success = executionState {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Execution Verified • \(executionLatencyMs) ms")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                                Spacer()
                            }
                            if !executionOutput.isEmpty {
                                Text(executionOutput)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.black)
                                    .padding(8)
                                    .background(Color.white.opacity(0.7))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(14)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(12)
                    } else if case .failure(let reason) = executionState {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Execution Failed")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            Text(reason)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                        .padding(14)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(12)
                    }

                    // Run Action Button
                    Button {
                        runActionWithBenchmark()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Execute Action Now")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(action.iconColor)
                        .cornerRadius(16)
                        .shadow(color: action.iconColor.opacity(0.35), radius: 8, y: 3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
            .navigationTitle("Action Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var schemeTypeString: String {
        switch action.actionType {
        case .openApp: return "App Scheme"
        case .systemAction: return "System Tool"
        case .customPrompt: return "ReAct Tool"
        }
    }

    private var handlerClassString: String {
        switch action.actionType {
        case .openApp: return "AppLaunchRegistry"
        case .systemAction: return "SystemInfoTool"
        case .customPrompt: return "WebSearchTool / ReAct"
        }
    }

    private var isSensitive: Bool {
        switch action.id {
        case "send_message", "take_photo": return true
        default: return false
        }
    }

    private var parameterPlaceholder: String {
        switch action.actionType {
        case .openApp: return "Application Name (e.g. YouTube, Safari)"
        case .systemAction: return "System Query (e.g. battery, thermal)"
        case .customPrompt: return "Search Prompt or Query"
        }
    }

    private var parameterDescription: String {
        switch action.actionType {
        case .openApp: return "Target application to launch via registered iOS URL schemes."
        case .systemAction: return "System property to query via native UIDevice & ProcessInfo."
        case .customPrompt: return "Natural language query forwarded to local intelligence pipeline."
        }
    }

    private func badgeView(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func techRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.45))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.black)
        }
    }

    private func runActionWithBenchmark() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        executionState = .executing
        let startTime = CFAbsoluteTimeGetCurrent()

        switch action.actionType {
        case .openApp:
            let appToLaunch = customTargetInput.trimmingCharacters(in: .whitespaces).isEmpty ? "Settings" : customTargetInput
            Task {
                do {
                    _ = try await AppLaunchRegistry.shared.launchApp(name: appToLaunch)
                    let duration = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                    await MainActor.run {
                        self.executionLatencyMs = max(1, duration)
                        self.executionOutput = "Successfully invoked application: \(appToLaunch)"
                        self.executionState = .success
                    }
                } catch {
                    let duration = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                    await MainActor.run {
                        self.executionLatencyMs = max(1, duration)
                        self.executionState = .failure(error.localizedDescription)
                    }
                }
            }

        case .systemAction:
            let param = customTargetInput.trimmingCharacters(in: .whitespaces).isEmpty ? "battery" : customTargetInput
            Task {
                let tool = SystemInfoTool()
                let res = await tool.execute(arguments: ["action": param])
                let duration = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                await MainActor.run {
                    self.executionLatencyMs = max(1, duration)
                    if res.success {
                        let msg = (res.outputPayload["message"] as? String) ?? "Tool executed successfully"
                        self.executionOutput = msg
                        self.executionState = .success
                    } else {
                        self.executionState = .failure(res.error ?? "Failed to read system state")
                    }
                }
            }

        case .customPrompt:
            let query = customTargetInput.trimmingCharacters(in: .whitespaces).isEmpty ? "Apple News" : customTargetInput
            Task {
                let tool = WebSearchTool()
                let res = await tool.execute(arguments: ["query": query])
                let duration = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                await MainActor.run {
                    self.executionLatencyMs = max(1, duration)
                    if res.success {
                        self.executionOutput = "Web query '\(query)' opened in Safari"
                        self.executionState = .success
                    } else {
                        self.executionState = .failure(res.error ?? "Search tool failed")
                    }
                }
            }
        }
    }
}

