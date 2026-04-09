import SwiftUI

@main
struct SetPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var serverConfig: ServerConfig? = ServerConfig.load()
    @State private var playerManager = PlayerManager()

    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                if let config = serverConfig {
                    ConnectedView(config: config, onDisconnect: disconnect)
                        .id(config)
                } else {
                    OnboardingView { config in
                        serverConfig = config
                    }
                }
            }
            .environment(playerManager)
            .onAppear {
                DispatchQueue.main.async {
                    for window in NSApplication.shared.windows
                    where window.canBecomeMain && !(window is NSPanel) && window.level == .normal {
                        window.isReleasedWhenClosed = false
                    }
                }
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView()
                .environment(\.disconnect, disconnect)
        }

        MenuBarExtra {
            MiniPlayerView()
                .environment(playerManager)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: playerManager.isPlaying ? "waveform" : "music.note")
                if playerManager.isPlaying, let chapter = playerManager.currentChapter {
                    MenuBarMarqueeText(text: chapter.name, maxChars: 14, currentTime: playerManager.currentTime)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func disconnect() {
        playerManager.stop()
        ServerConfig.clear()
        serverConfig = nil
    }
}

// MARK: - Connected View

struct ConnectedView: View {
    @State private var jellyfin: JellyfinService
    @State private var libraryViewModel: LibraryViewModel
    let onDisconnect: () -> Void

    init(config: ServerConfig, onDisconnect: @escaping () -> Void) {
        let jf = JellyfinService(
            serverURL: config.serverURL,
            apiKey: config.apiKey,
            userId: config.userId
        )
        _jellyfin = State(initialValue: jf)
        _libraryViewModel = State(initialValue: LibraryViewModel(jellyfin: jf))
        self.onDisconnect = onDisconnect
    }

    var body: some View {
        LibraryView()
            .environment(jellyfin)
            .environment(libraryViewModel)
            .environment(\.disconnect, onDisconnect)
    }
}

// MARK: - Disconnect Environment Key

private struct DisconnectKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var disconnect: () -> Void {
        get { self[DisconnectKey.self] }
        set { self[DisconnectKey.self] = newValue }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let hide = UserDefaults.standard.object(forKey: "hideDockIcon") as? Bool ?? true
        SettingsView.applyDockIconPolicy(hidden: hide)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    @objc func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let window = NSApplication.shared.windows.first(where: {
            $0.canBecomeMain && !($0 is NSPanel) && $0.level == .normal
        }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
