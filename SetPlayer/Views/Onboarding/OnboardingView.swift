import SwiftUI

struct OnboardingView: View {
    var onConnect: (ServerConfig) -> Void

    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    private var canConnect: Bool {
        !serverURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("Connect to Jellyfin")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Enter your server details to get started.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField("Server address (e.g. 192.168.1.100:8096)", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.URL)

                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    connect()
                } label: {
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canConnect || isConnecting)
            }
            .frame(maxWidth: 380)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func connect() {
        let rawURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = normalizeURL(rawURL)
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)

        isConnecting = true
        errorMessage = nil

        Task {
            do {
                let config = try await JellyfinService.authenticate(
                    serverURL: url,
                    username: user,
                    password: password
                )
                config.save()
                onConnect(config)
            } catch {
                errorMessage = error.localizedDescription
            }
            isConnecting = false
        }
    }

    private func normalizeURL(_ raw: String) -> String {
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return raw
        }
        return "http://\(raw)"
    }
}
