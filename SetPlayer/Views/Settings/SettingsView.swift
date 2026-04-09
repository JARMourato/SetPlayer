import SwiftUI

struct SettingsView: View {
    @AppStorage("hideDockIcon") private var hideDockIcon = true
    @Environment(\.disconnect) private var disconnect

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Hide dock icon", isOn: $hideDockIcon)
                    .onChange(of: hideDockIcon) { _, newValue in
                        Self.applyDockIconPolicy(hidden: newValue)
                    }

                Text("The app is always accessible from the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Storage") {
                Button("Clear Image Cache") {
                    URLCache.shared.removeAllCachedResponses()
                }

                Text("Removes cached album art and thumbnails.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Account") {
                Button("Disconnect from Server", role: .destructive) {
                    disconnect()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 280)
    }

    static func applyDockIconPolicy(hidden: Bool) {
        NSApp.setActivationPolicy(hidden ? .accessory : .regular)
    }
}

func applyDockIconPolicy(hidden: Bool) {
    SettingsView.applyDockIconPolicy(hidden: hidden)
}
