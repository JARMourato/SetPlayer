import SwiftUI

@main
struct SetPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var jellyfin: JellyfinService
    @State private var playerManager = PlayerManager()
    @State private var libraryViewModel: LibraryViewModel

    init() {
        let jf = JellyfinService(
            serverURL: "http://192.168.1.131:8096",
            apiKey: "4f3363c011d84ae89c12bcc43bd2f25b",
            userId: "ec301241cc6540498cd33b92f8c76192"
        )
        _jellyfin = State(initialValue: jf)
        _libraryViewModel = State(initialValue: LibraryViewModel(jellyfin: jf))
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            LibraryView()
                .environment(jellyfin)
                .environment(playerManager)
                .environment(libraryViewModel)
                .onAppear {
                    // Prevent window from being released on close — just hide it
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

        MenuBarExtra {
            MiniPlayerView()
                .environment(jellyfin)
                .environment(playerManager)
        } label: {
            Image(systemName: playerManager.isPlaying ? "waveform" : "music.note")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    @objc func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Find the real main window — exclude panels and popover/statusbar windows
        if let window = NSApplication.shared.windows.first(where: {
            $0.canBecomeMain && !($0 is NSPanel) && $0.level == .normal
        }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
