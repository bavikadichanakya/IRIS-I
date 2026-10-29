//
//  GmailConnectionView.swift
//  IRIS-I
//
//  User-facing connection card and management interface for linking, inspecting,
//  configuring, and disconnecting Google Gmail OAuth accounts with PKCE on iOS.
//

import SwiftUI
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

public struct GmailConnectionView: View {
    @State private var connectorState: ConnectorState = .disconnected
    @State private var isConfigured: Bool = false
    @State private var isAuthenticating: Bool = false
    @State private var errorMessage: String?
    @State private var showingDisconnectAlert: Bool = false
    @State private var showingConfigSheet: Bool = false
    @State private var inputClientId: String = ""
    @State private var inputRedirectUri: String = ""

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
                    if !isConfigured {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Client ID Required")
                                    .font(.subheadline.bold())
                            }
                            Text("To link your live Google account, configure a Google Cloud iOS OAuth Client ID.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: {
                                showingConfigSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                    Text("Configure Client ID")
                                }
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(8)
                            }
                        }
                    } else {
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
        .sheet(isPresented: $showingConfigSheet) {
            NavigationStack {
                Form {
                    Section(header: Text("Google Cloud OAuth Settings")) {
                        TextField("Client ID (e.g. 123...apps.googleusercontent.com)", text: $inputClientId)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        TextField("Custom Redirect URI (Optional)", text: $inputRedirectUri)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    Section(footer: Text("Register an iOS Client ID in Google Cloud Console with bundle ID 'com.iris.assistant'. The callback scheme is derived automatically.")) {
                        Button("Save Configuration") {
                            Task {
                                await GmailConnector.shared.saveClientConfiguration(
                                    clientId: inputClientId.trimmingCharacters(in: .whitespacesAndNewlines),
                                    redirectUri: inputRedirectUri.trimmingCharacters(in: .whitespacesAndNewlines)
                                )
                                showingConfigSheet = false
                                await refreshState()
                            }
                        }
                        .disabled(inputClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .navigationTitle("OAuth Configuration")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingConfigSheet = false }
                    }
                }
            }
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
                if !isConfigured {
                    Text("Unconfigured")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                } else {
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
        let config = await GmailConnector.shared.oauthConfig
        await MainActor.run {
            self.connectorState = state
            self.isConfigured = config.isConfigured
            self.inputClientId = config.clientId
            self.inputRedirectUri = config.redirectUri
        }
    }

    private func startOAuthFlow() {
        isAuthenticating = true
        errorMessage = nil

        Task {
            do {
                let authURL = try await GmailConnector.shared.startAuthorizationFlow()
                let scheme = await GmailConnector.shared.oauthConfig.callbackScheme

                await MainActor.run {
                    #if canImport(AuthenticationServices)
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

                    #if canImport(UIKit)
                    session.presentationContextProvider = AuthenticationContextProvider.shared
                    #endif
                    session.prefersEphemeralWebBrowserSession = true
                    session.start()
                    #else
                    self.isAuthenticating = false
                    #endif
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticating = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#if canImport(AuthenticationServices) && canImport(UIKit)
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
