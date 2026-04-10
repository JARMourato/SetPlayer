import SwiftUI

// MARK: - Marquee Text

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let speed: Double // points per second

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animating = false

    private var needsScrolling: Bool { textWidth > containerWidth }

    var body: some View {
        GeometryReader { geo in
            let cw = geo.size.width
            ZStack(alignment: .leading) {
                // Measure text
                Text(text)
                    .font(font)
                    .fixedSize()
                    .background(GeometryReader { tg in
                        Color.clear.onAppear { textWidth = tg.size.width }
                    })
                    .hidden()

                if needsScrolling {
                    HStack(spacing: 40) {
                        Text(text).font(font).foregroundStyle(color)
                        Text(text).font(font).foregroundStyle(color)
                    }
                    .fixedSize()
                    .offset(x: offset)
                    .onAppear {
                        containerWidth = cw
                        startAnimation()
                    }
                    .onChange(of: text) { _, _ in
                        offset = 0
                        textWidth = 0
                        // Reset will trigger re-measure
                    }
                } else {
                    Text(text)
                        .font(font)
                        .foregroundStyle(color)
                }
            }
            .clipped()
            .onAppear { containerWidth = cw }
        }
    }

    private func startAnimation() {
        guard needsScrolling else { return }
        let totalScroll = textWidth + 40 // text width + gap
        let duration = totalScroll / speed

        // Start after a pause
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                offset = -totalScroll
            }
        }
    }
}

// MARK: - Immersive Video View

struct ImmersiveVideoView: View {
    @Binding var showVideo: Bool

    @Environment(PlayerManager.self) private var player
    @Environment(JellyfinService.self) private var jellyfin

    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>?
    @State private var showTracklist = false

    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0
    @State private var isHoveringProgress = false
    @State private var isInteracting = false
    @State private var savedWindowFrame: NSRect = .zero

    var body: some View {
        ZStack {
            VideoLayerView(player: player.player)
                .ignoresSafeArea()
                .background(.black)
                .gesture(
                    DragGesture(minimumDistance: 50)
                        .onEnded { value in
                            let h = value.translation.width
                            guard abs(h) > abs(value.translation.height) * 1.5 else { return }
                            if h < -50 {
                                player.nextChapter()
                                HapticManager.play(.navigation)
                            } else if h > 50 {
                                player.previousChapter()
                                HapticManager.play(.navigation)
                            }
                            revealControls()
                        }
                )

            if showControls {
                topOverlay
            }
            if showControls {
                bottomOverlay
            }
            if showTracklist && showControls {
                tracklistPanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showControls)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showTracklist)
        .onHover { hovering in
            if hovering { revealControls() }
        }
        .onContinuousHover { phase in
            if case .active = phase { revealControls() }
        }
        .onAppear {
            makeWindowTransparent(true)
            scheduleHide()
        }
        .onDisappear {
            makeWindowTransparent(false)
            hideTask?.cancel()
        }
    }

    // MARK: - Top Overlay

    private var topOverlay: some View {
        VStack {
            VStack(alignment: .leading, spacing: 6) {
                if let item = player.currentItem {
                    Text(item.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.7), radius: 6, x: 0, y: 2)
                }
                if let chapter = player.currentChapter {
                    MarqueeText(
                        text: chapter.name,
                        font: .system(size: 15, weight: .medium),
                        color: .white.opacity(0.85),
                        speed: 40
                    )
                    .frame(height: 20)
                    .frame(maxWidth: 500)
                    .shadow(color: .black.opacity(0.7), radius: 6, x: 0, y: 2)
                }

                // Chapter progress
                if !player.chapters.isEmpty {
                    Text("Track \(player.currentChapterIndex + 1) of \(player.chapters.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 52)
            .background(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.7), location: 0),
                        .init(color: .black.opacity(0.4), location: 0.5),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
                .allowsHitTesting(false),
                alignment: .top
            )

            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Bottom Overlay

    private var bottomOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 6) {
                progressBar

                HStack(spacing: 0) {
                    // Time left
                    Text(formatTime(player.currentTime))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 60, alignment: .leading)

                    Spacer()

                    // Controls
                    HStack(spacing: 28) {
                        controlButton(icon: "backward.end.fill", size: 15) {
                            player.previousChapter()
                            HapticManager.play(.navigation)
                        }

                        controlButton(
                            icon: player.isPlaying ? "pause.fill" : "play.fill",
                            size: 22
                        ) {
                            player.togglePlayPause()
                            HapticManager.play(.playPause)
                        }

                        controlButton(icon: "forward.end.fill", size: 15) {
                            player.nextChapter()
                            HapticManager.play(.navigation)
                        }
                    }

                    Spacer()

                    // Right side buttons
                    HStack(spacing: 16) {
                        controlButton(
                            icon: "list.bullet",
                            size: 13,
                            tint: showTracklist ? .white : .white.opacity(0.5)
                        ) {
                            showTracklist.toggle()
                        }

                        controlButton(icon: "rectangle.inset.filled", size: 13) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showVideo = false
                            }
                        }

                        Text(formatTime(player.duration))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(width: 140, alignment: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            .background(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.5), location: 0.4),
                        .init(color: .black.opacity(0.75), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            )
        }
        .transition(.opacity)
    }

    private func controlButton(icon: String, size: CGFloat, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(tint)
                .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tracklist Panel

    private var tracklistPanel: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Tracklist")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(player.chapters.count) tracks")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .background(.white.opacity(0.15))

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(player.chapters.enumerated()), id: \.element.id) { index, chapter in
                                tracklistRow(chapter: chapter, index: index)
                                    .id(index)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: player.currentChapterIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
            .frame(width: 340)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.trailing, 16)
            .padding(.top, 56)
            .padding(.bottom, 80)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    @State private var hoveredTrackIndex: Int?

    private func tracklistRow(chapter: JellyfinChapter, index: Int) -> some View {
        let isCurrent = index == player.currentChapterIndex
        let isHovered = hoveredTrackIndex == index

        return HStack(spacing: 10) {
            // Number / icon
            Group {
                if isCurrent && player.isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, isActive: true)
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(isCurrent ? .white : .white.opacity(0.35))
                }
            }
            .frame(width: 24, alignment: .trailing)

            // Track name — marquee if current
            if isCurrent {
                MarqueeText(
                    text: chapter.name,
                    font: .system(size: 12, weight: .medium),
                    color: .white,
                    speed: 30
                )
                .frame(height: 16)
            } else {
                Text(chapter.name)
                    .font(.system(size: 12))
                    .foregroundStyle(isHovered ? .white : .white.opacity(0.8))
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Text(chapter.startFormatted)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isCurrent ? Color.white.opacity(0.15) : (isHovered ? Color.white.opacity(0.07) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { h in hoveredTrackIndex = h ? index : nil }
        .onTapGesture { player.seekToChapter(at: index) }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            let displayProgress = isScrubbing ? scrubProgress : player.progress

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.2))

                // Filled track
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(0, geo.size.width * displayProgress))

                // Scrub handle
                if isHoveringProgress || isScrubbing {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                        .frame(width: 14, height: 14)
                        .position(x: geo.size.width * displayProgress, y: (isHoveringProgress || isScrubbing) ? 5 : 2.5)
                }
            }
            .frame(height: isHoveringProgress || isScrubbing ? 10 : 5)
            .contentShape(Rectangle().size(width: geo.size.width, height: 24))
            .onHover { hovering in
                isHoveringProgress = hovering
                if hovering { revealControls() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        isInteracting = true
                        scrubProgress = max(0, min(1, value.location.x / geo.size.width))
                        revealControls()
                    }
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        player.seek(to: fraction * player.duration)
                        isScrubbing = false
                        isInteracting = false
                        scheduleHide()
                    }
            )
        }
        .frame(height: isHoveringProgress || isScrubbing ? 10 : 5)
        .padding(.horizontal, 20)
        .animation(.easeOut(duration: 0.15), value: isHoveringProgress)
    }

    // MARK: - Window Management

    private func makeWindowTransparent(_ transparent: Bool) {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.mainWindow else { return }
            if transparent {
                savedWindowFrame = window.frame
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                window.backgroundColor = .black
                resizeWindowToVideo(window: window)
            } else {
                window.titlebarAppearsTransparent = false
                window.titleVisibility = .visible
                window.styleMask.remove(.fullSizeContentView)
                window.backgroundColor = .windowBackgroundColor
                if savedWindowFrame.size.width > 0 {
                    window.setFrame(savedWindowFrame, display: true, animate: true)
                }
            }
        }
    }

    private func resizeWindowToVideo(window: NSWindow) {
        let videoSize = player.videoSize
        guard videoSize.width > 0, videoSize.height > 0 else {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                if player.videoSize.width > 0 {
                    guard let win = NSApplication.shared.mainWindow else { return }
                    performResize(window: win, videoSize: player.videoSize)
                }
            }
            return
        }
        performResize(window: window, videoSize: videoSize)
    }

    private func performResize(window: NSWindow, videoSize: CGSize) {
        guard let screen = window.screen else { return }
        let aspect = videoSize.width / videoSize.height
        let screenFrame = screen.visibleFrame
        let maxWidth = screenFrame.width * 0.9
        let maxHeight = screenFrame.height * 0.9

        var newWidth = maxWidth
        var newHeight = newWidth / aspect
        if newHeight > maxHeight {
            newHeight = maxHeight
            newWidth = newHeight * aspect
        }

        let newFrame = NSRect(
            x: screenFrame.midX - newWidth / 2,
            y: screenFrame.midY - newHeight / 2,
            width: newWidth,
            height: newHeight
        )
        window.setFrame(newFrame, display: true, animate: true)
    }

    // MARK: - Auto-hide

    private func revealControls() {
        showControls = true
        scheduleHide()
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !isInteracting, !isHoveringProgress, !showTracklist else { return }
            showControls = false
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
