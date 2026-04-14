import AVKit
import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(\.openWindow) private var openWindow

    @State private var isHoveringProgress = false
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0
    @State private var showTracklist = false
    @State private var showQueue = false
    @State private var progressBounce = false
    @State private var atBoundary = false

    var body: some View {
        VStack(spacing: 0) {
            if let item = player.currentItem {
                if showTracklist {
                    tracklistView
                } else if showQueue {
                    miniQueueView
                } else {
                    playerView(item: item)
                }
            } else {
                emptyState
            }
        }
        .frame(width: 300)
        .onAppear {
            FloatingVideoManager.shared.popoverDidOpen()
        }
        .onDisappear {
            FloatingVideoManager.shared.popoverDidClose(player: player.player)
        }
    }

    // MARK: - Player View

    private func playerView(item: JellyfinItem) -> some View {
        VStack(spacing: 0) {
            // Video preview
            AVPlayerViewRepresentable(player: player.player)
                .frame(width: 280, height: 280 / videoAspectRatio)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 10)
                .padding(.top, 10)

            // Track info
            header(item: item)
                .padding(.top, 10)

            // Progress
            progressBar
                .padding(.horizontal, 16)
                .padding(.top, 8)

            HStack {
                Text(formatTime(player.currentTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 16)
            .padding(.top, 2)

            // Controls
            controls
                .padding(.top, 8)

            // Actions
            actions
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Tracklist View

    private var tracklistView: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTracklist = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)

                Text("Tracklist")
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                Text("\(player.chapters.count) tracks")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(player.chapters.enumerated()), id: \.element.id) { index, chapter in
                            miniTrackRow(chapter: chapter, index: index)
                                .id(index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 340)
                .onAppear {
                    proxy.scrollTo(player.currentChapterIndex, anchor: .center)
                }
                .onChange(of: player.currentChapterIndex) { _, newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }

            // Minimal controls at bottom
            HStack(spacing: 24) {
                Button {
                    player.previousChapter()
                    HapticManager.play(.navigation)
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)

                Button {
                    player.togglePlayPause()
                    HapticManager.play(.playPause)
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .medium))
                }
                .buttonStyle(.plain)

                Button {
                    player.nextChapter()
                    HapticManager.play(.navigation)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 10)

            Divider()

            // Back to player
            actions
                .padding(.vertical, 8)
        }
    }

    // MARK: - Mini Queue View

    private var miniQueueView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showQueue = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)

                Text("Up Next")
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                if !player.queue.isEmpty {
                    Text("\(player.queue.count)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary))

                    Button("Clear") {
                        withAnimation { player.clearQueue() }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Shuffle & Repeat
            HStack(spacing: 14) {
                Button {
                    player.toggleShuffle()
                    HapticManager.play(.selection)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 10, weight: .medium))
                        Text("Shuffle")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(player.shuffleEnabled ? player.artworkAccentColor : .secondary)
                }
                .buttonStyle(.plain)

                Button {
                    player.cycleRepeatMode()
                    HapticManager.play(.selection)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: player.repeatMode == .repeatOne ? "repeat.1" : "repeat")
                            .font(.system(size: 10, weight: .medium))
                        Text(player.repeatMode == .off ? "Repeat" : (player.repeatMode == .repeatAll ? "All" : "One"))
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(player.repeatMode != .off ? player.artworkAccentColor : .secondary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            Divider()

            if player.queue.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                        .font(.system(size: 22))
                        .foregroundStyle(.quaternary)
                    Text("Queue is empty")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            } else {
                List {
                    ForEach(player.queue) { entry in
                        miniQueueRow(entry)
                    }
                    .onDelete { offsets in
                        withAnimation {
                            player.removeFromQueue(at: offsets)
                        }
                    }
                    .onMove { source, destination in
                        player.moveInQueue(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: 280)
            }

            // Minimal controls at bottom
            HStack(spacing: 24) {
                Button {
                    player.previousChapter()
                    HapticManager.play(.navigation)
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)

                Button {
                    player.togglePlayPause()
                    HapticManager.play(.playPause)
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .medium))
                }
                .buttonStyle(.plain)

                Button {
                    player.nextChapter()
                    HapticManager.play(.navigation)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 10)

            Divider()

            actions
                .padding(.vertical, 8)
        }
    }

    private func miniQueueRow(_ entry: QueueEntry) -> some View {
        HStack(spacing: 8) {
            if let url = entry.imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(nsColor: .controlBackgroundColor)
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                ZStack {
                    Color(nsColor: .controlBackgroundColor)
                    Image(systemName: "music.mic")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.item.artist)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Text(entry.item.festival)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if let runtime = entry.item.runtime {
                Text("\(runtime)m")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, 1)
    }

    @State private var hoveredTrackIndex: Int?

    private func miniTrackRow(chapter: JellyfinChapter, index: Int) -> some View {
        let isCurrent = index == player.currentChapterIndex
        let isHovered = hoveredTrackIndex == index

        return HStack(spacing: 8) {
            Group {
                if isCurrent && player.isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 9))
                        .symbolEffect(.variableColor.iterative, isActive: true)
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(isCurrent ? .primary : .tertiary)
                }
            }
            .frame(width: 22, alignment: .trailing)

            Text(chapter.name)
                .font(.system(size: 11, weight: isCurrent ? .semibold : .regular))
                .lineLimit(2)

            Spacer(minLength: 4)

            Text(chapter.startFormatted)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isCurrent ? Color.primary.opacity(0.08) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { h in hoveredTrackIndex = h ? index : nil }
        .onTapGesture { player.seekToChapter(at: index) }
    }

    // MARK: - Header

    private func header(item: JellyfinItem) -> some View {
        VStack(spacing: 3) {
            if let chapter = player.currentChapter {
                Text(chapter.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            Text(item.name)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !player.chapters.isEmpty {
                Text("Track \(player.currentChapterIndex + 1) of \(player.chapters.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Progress

    private var progressBar: some View {
        GeometryReader { geo in
            let displayProgress = isScrubbing ? scrubProgress : player.progress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(player.artworkAccentColor)
                    .frame(width: max(0, geo.size.width * displayProgress))

                if isHoveringProgress || isScrubbing {
                    Circle()
                        .fill(player.artworkAccentColor)
                        .frame(width: 10, height: 10)
                        .position(x: geo.size.width * displayProgress, y: 3.5)
                }
            }
            .frame(height: isHoveringProgress || isScrubbing ? 7 : 4)
            .scaleEffect(y: progressBounce ? 1.4 : 1.0, anchor: .center)
            .animation(.spring(response: 0.36, dampingFraction: 0.68), value: progressBounce)
            .contentShape(Rectangle().size(width: geo.size.width, height: 16))
            .onHover { isHoveringProgress = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        scrubProgress = max(0, min(1, value.location.x / geo.size.width))
                        let atEdge = scrubProgress <= 0.001 || scrubProgress >= 0.999
                        if atEdge && !atBoundary {
                            atBoundary = true
                            progressBounce = true
                            HapticManager.play(.selection)
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(300))
                                progressBounce = false
                            }
                        } else if !atEdge {
                            atBoundary = false
                        }
                    }
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        player.seek(to: fraction * player.duration)
                        isScrubbing = false
                        atBoundary = false
                        progressBounce = false
                    }
            )
            .animation(.easeOut(duration: 0.1), value: isHoveringProgress)
        }
        .frame(height: isHoveringProgress || isScrubbing ? 7 : 4)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 6) {
            HStack(spacing: 24) {
                Button {
                    player.previousChapter()
                    HapticManager.play(.navigation)
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)

                Button {
                    player.togglePlayPause()
                    HapticManager.play(.playPause)
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .medium))
                }
                .buttonStyle(.plain)

                Button {
                    player.nextChapter()
                    HapticManager.play(.navigation)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }

            // Shuffle, repeat, tracklist, queue
            HStack(spacing: 16) {
                Button {
                    player.toggleShuffle()
                    HapticManager.play(.selection)
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(player.shuffleEnabled ? player.artworkAccentColor : Color.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    player.cycleRepeatMode()
                    HapticManager.play(.selection)
                } label: {
                    Image(systemName: player.repeatMode == .repeatOne ? "repeat.1" : "repeat")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(player.repeatMode != .off ? player.artworkAccentColor : Color.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showTracklist = true
                    }
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showQueue = true
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "text.line.first.and.arrowtriangle.forward")
                            .font(.system(size: 12))
                        if !player.queue.isEmpty {
                            Text("\(player.queue.count)")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 2)
                                .background(Capsule().fill(player.artworkAccentColor))
                                .offset(x: 6, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 0) {
            Button {
                openMainWindow()
            } label: {
                Label("Open SetPlayer", systemImage: "macwindow")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                FloatingVideoManager.shared.toggleFloat()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: FloatingVideoManager.shared.floatWhenCollapsed ? "pip.fill" : "pip")
                        .font(.system(size: 12))
                    Text("Float")
                        .font(.system(size: 10))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(FloatingVideoManager.shared.floatWhenCollapsed ? .primary : .secondary)
            .help("Keep video floating when menu closes")
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("Nothing playing")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button {
                openMainWindow()
            } label: {
                Label("Open SetPlayer", systemImage: "macwindow")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Video Sizing

    private var videoAspectRatio: CGFloat {
        let size = player.videoSize
        guard size.width > 0, size.height > 0 else { return 16.0 / 9.0 }
        return size.width / size.height
    }

    // MARK: - Helpers

    private func openMainWindow() {
        // Try to show an existing hidden main window first
        if let window = NSApplication.shared.windows.first(where: {
            $0.canBecomeMain && !($0 is NSPanel) && $0.level == .normal
        }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // No window exists — create one via SwiftUI
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
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
