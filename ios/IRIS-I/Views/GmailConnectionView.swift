//
//  GmailConnectionView.swift
//  IRIS-I
//
//  User-facing connection card and management interface for linking, inspecting,
//  and disconnecting Google Gmail OAuth accounts with PKCE on iOS.
//

import SwiftUI
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

public struct GmailConnectionView: View {
    @State private var connectorState: ConnectorState = .disconnected
    @State private var isAuthenticating: Bool = false
    @State private var errorMessage: String?
    @State private var showingDisconnectAlert: Bool = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 26))
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Gmail")
                        .font(.headline)
                    Text("Inbox search, drafts & authenticated email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                stateBadge
            }

            Divider()

            switch connectorState {
            case .connected(let email):
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Linked Account:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(email)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Scopes:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• gmail.readonly (search & read authorized emails)\n• gmail.compose (create local drafts)\n• gmail.send (send emails upon user confirmation)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Button(role: .destructive, action: {
                        showingDisconnectAlert = true
                    }) {
                        HStack {
                            Image(systemName: "link.badge.plus")
                            Text("Disconnect Gmail Account")
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                }

            case .tokenExpired(let email):
                VStack(alignment: .leading, spacing: 8) {
                    Text("Access token for \(email) expired. Re-authenticate to resume inbox queries.")
                        .font(.caption)
                        .foregroundColor(.orange)

                    connectButton(label: "Re-authenticate Account")
                }

            case .disconnected, .error:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Link your Gmail account to check emails from OpenAI, search messages, and manage outgoing emails.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    connectButton(label: "Connect with Google")
                }

            case .connecting:
                HStack {
                    ProgressView()
                        .padding(.trailing, 6)
                    Text("Authenticating with Google OAuth...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .task {
            await refreshState()
        }
        .alert("Disconnect Gmail?", isPresented: $showingDisconnectAlert) {
            Button("Disconnect & Revoke", role: .destructive) {
                Task {
                    try? await GmailConnector.shared.disconnect()
                    await refreshState()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will wipe all stored credentials from Keychain and revoke active session tokens.")
        }
    }

    private var stateBadge: some View {
        Group {
            switch connectorState {
            case .connected:
                Text("Connected")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            case .tokenExpired:
                Text("Expired")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            case .connecting:
                Text("Connecting")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            case .disconnected, .error:
                Text("Not Connected")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.15))
                    .foregroundColor(.secondary)
                    .cornerRadius(8)
            }
        }
    }

    private func connectButton(label: String) -> some View {
        Button(action: {
            startOAuthFlow()
        }) {
            HStack {
                if isAuthenticating {
                    ProgressView()
                        .padding(.trailing, 4)
                } else {
                    Image(systemName: "lock.shield.fill")
                }
                Text(label)
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isAuthenticating)
    }

    private func refreshState() async {
        let state = await GmailConnector.shared.state
        await MainActor.run {
            self.connectorState = state
        }
    }

    private func startOAuthFlow() {
        isAuthenticating = true
        errorMessage = nil

        Task {
            let authURL = await GmailConnector.shared.startAuthorizationFlow()

            await MainActor.run {
                #if canImport(AuthenticationServices)
                let scheme = "com.googleusercontent.apps"
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: scheme
                ) { callbackURL, error in
                    Task {
                        if let error = error {
                            await MainActor.run {
                                self.isAuthenticating = false
                                if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                                    self.errorMessage = error.localizedDescription
                                }
                            }
                            return
                        }

                        if let callbackURL = callbackURL {
                            do {
                                try await GmailConnector.shared.handleAuthorizationRedirect(url: callbackURL)
                                await refreshState()
                            } catch {
                                await MainActor.run {
                                    self.errorMessage = error.localizedDescription
                                }
                            }
                        }

                        await MainActor.run {
                            self.isAuthenticating = false
                        }
                    }
                }

                session.presentationContextProvider = AuthenticationContextProvider.shared
                session.prefersEphemeralWebBrowserSession = true
                session.start()
                #else
                self.isAuthenticating = false
                #endif
            }
        }
    }
}

#if canImport(AuthenticationServices)
final class AuthenticationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthenticationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }
}
#endif
