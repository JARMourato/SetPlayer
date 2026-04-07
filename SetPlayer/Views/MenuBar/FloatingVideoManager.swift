import AVFoundation
import AVKit
import AppKit

@MainActor @Observable
final class FloatingVideoManager {
    static let shared = FloatingVideoManager()

    var floatWhenCollapsed = false
    private(set) var isFloating = false
    private var videoWindow: NSWindow?
    private var playerView: AVPlayerView?

    private init() {}

    func popoverDidClose(player: AVPlayer) {
        guard floatWhenCollapsed else { return }
        showFloating(player: player)
    }

    func popoverDidOpen() {
        hideFloating()
    }

    func toggleFloat() {
        floatWhenCollapsed.toggle()
        if !floatWhenCollapsed {
            hideFloating()
        }
    }

    // MARK: - Floating Window

    private func showFloating(player: AVPlayer) {
        guard !isFloating else { return }

        let size = NSSize(width: 360, height: 202)
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let origin = NSPoint(
            x: screen.visibleFrame.maxX - size.width - 20,
            y: screen.visibleFrame.maxY - size.height - 20
        )

        let window = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .black
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.title = "SetPlayer"
        window.minSize = NSSize(width: 240, height: 135)
        window.aspectRatio = NSSize(width: 16, height: 9)

        // AVPlayerView with native controls
        let pv = AVPlayerView(frame: NSRect(origin: .zero, size: size))
        pv.player = player
        pv.controlsStyle = .floating
        pv.showsFullScreenToggleButton = false
        pv.autoresizingMask = [.width, .height]
        window.contentView = pv

        // Round corners
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 10
        window.contentView?.layer?.masksToBounds = true

        window.orderFront(nil)

        self.videoWindow = window
        self.playerView = pv
        self.isFloating = true

        // Handle window close
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isFloating = false
                self?.videoWindow = nil
                self?.playerView = nil
            }
        }
    }

    func hideFloating() {
        guard isFloating else { return }
        videoWindow?.orderOut(nil)
        videoWindow = nil
        playerView?.player = nil
        playerView = nil
        isFloating = false
    }
}
