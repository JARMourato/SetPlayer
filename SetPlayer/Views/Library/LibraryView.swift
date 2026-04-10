import AVKit
import SwiftUI

struct LibraryView: View {
    @Environment(JellyfinService.self) private var jellyfin
    @Environment(PlayerManager.self) private var player
    @Environment(LibraryViewModel.self) private var viewModel

    @State private var selectedItem: JellyfinItem?
    @State private var sidebarSelection: SidebarItem? = .allSets
    @State private var showingDetail = false
    @State private var playerBarState = PlayerBarState()
    @State private var showQueue = false

    struct PlayerBarState {
        var showVideo = false
    }

    private var vm: Bindable<LibraryViewModel> {
        Bindable(viewModel)
    }

    var body: some View {
        Group {
            if playerBarState.showVideo {
                ImmersiveVideoView(showVideo: $playerBarState.showVideo)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        NavigationSplitView {
                            sidebar
                        } detail: {
                            mainContent
                        }
                        .searchable(text: vm.searchText, prompt: "Search sets or tracks...")

                        if showQueue {
                            Divider()
                            QueueView()
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showQueue)

                    BottomPlayerBar(showVideo: $playerBarState.showVideo, showQueue: $showQueue)
                }
            }
        }
        .task {
            await viewModel.loadLibrary()
            // Restore last playing set — only if nothing is currently playing
            if player.currentItem == nil,
               let savedId = player.savedItemId,
               let item = viewModel.items.first(where: { $0.id == savedId }),
               let url = jellyfin.streamURL(for: item.id) {
                player.restoreState(item: item, streamURL: url)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Picker("Sort", selection: vm.sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)

                    Button {
                        Task { await viewModel.loadLibrary() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Refresh Library (⌘R)")

                    Button {
                        withAnimation { showQueue.toggle() }
                    } label: {
                        Image(systemName: showQueue ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                    }
                    .help("Toggle Queue")

                    SettingsLink {
                        Image(systemName: "gearshape")
                    }
                    .help("Settings (⌘,)")
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            Section("Library") {
                Label("All Sets", systemImage: "music.note.list")
                    .tag(SidebarItem.allSets)
                Label("Recently Added", systemImage: "clock")
                    .tag(SidebarItem.recentlyAdded)
                if !viewModel.recentlyPlayed.isEmpty {
                    Label("Recently Played", systemImage: "play.circle")
                        .tag(SidebarItem.recentlyPlayed)
                }
            }

            if !viewModel.collections.isEmpty {
                Section("Collections") {
                    ForEach(viewModel.collections) { collection in
                        Label(collection.name, systemImage: "square.stack")
                            .tag(SidebarItem.collection(collection.id))
                    }
                }
            }

            if !viewModel.artists.isEmpty {
                Section("Artists") {
                    ForEach(viewModel.artists, id: \.self) { artist in
                        Label(artist, systemImage: "person.fill")
                            .tag(SidebarItem.artist(artist))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("SetPlayer")
        .onChange(of: sidebarSelection) { oldValue, newValue in
            showingDetail = false
            selectedItem = nil
            Task {
                switch newValue {
                case .allSets, .none:
                    await viewModel.loadAll()
                case .recentlyAdded:
                    await viewModel.loadAll()
                case .recentlyPlayed:
                    break // uses viewModel.recentlyPlayed directly
                case .collection(let id):
                    if let collection = viewModel.collections.first(where: { $0.id == id }) {
                        await viewModel.loadCollection(collection)
                    }
                case .artist:
                    break
                }
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if showingDetail, let selectedItem {
            SetDetailView(item: selectedItem, onBack: {
                showingDetail = false
                self.selectedItem = nil
            })
        } else {
            gridContent
        }
    }

    @ViewBuilder
    private var gridContent: some View {
        let displayItems: [JellyfinItem] = {
            switch sidebarSelection {
            case .artist(let name):
                return viewModel.items(for: name)
            case .recentlyAdded:
                return Array(viewModel.filteredItems.prefix(20))
            case .recentlyPlayed:
                return viewModel.recentlyPlayed
            default:
                return viewModel.filteredItems
            }
        }()

        if viewModel.isLoading {
            ProgressView("Loading...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if displayItems.isEmpty {
            if viewModel.searchText.isEmpty {
                ContentUnavailableView("No Sets Found", systemImage: "music.mic",
                                       description: Text("Your library appears to be empty"))
            } else {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(navigationTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)],
                        spacing: 24
                    ) {
                        ForEach(displayItems) { item in
                            SetGridItem(item: item, isSelected: selectedItem?.id == item.id)
                                .draggable(item.id)
                                .onTapGesture(count: 2) {
                                    selectedItem = item
                                    if let url = jellyfin.streamURL(for: item.id) {
                                        player.play(item: item, streamURL: url)
                                    }
                                }
                                .onTapGesture {
                                    selectedItem = item
                                    showingDetail = true
                                }
                                .contextMenu {
                                    Button("Play") {
                                        if let url = jellyfin.streamURL(for: item.id) {
                                            player.play(item: item, streamURL: url)
                                        }
                                    }
                                    Divider()
                                    Button("Play Next") {
                                        if let url = jellyfin.streamURL(for: item.id) {
                                            let imageURL = item.imageTags["Primary"].flatMap { jellyfin.imageURL(for: item.id, tag: $0, maxWidth: 80) }
                                            player.playNext(item, streamURL: url, imageURL: imageURL)
                                            HapticManager.play(.selection)
                                        }
                                    }
                                    Button("Add to Queue") {
                                        if let url = jellyfin.streamURL(for: item.id) {
                                            let imageURL = item.imageTags["Primary"].flatMap { jellyfin.imageURL(for: item.id, tag: $0, maxWidth: 80) }
                                            player.addToQueue(item, streamURL: url, imageURL: imageURL)
                                            HapticManager.play(.selection)
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var navigationTitle: String {
        switch sidebarSelection {
        case .allSets, .none: viewModel.selectedCollection?.name ?? "All Sets"
        case .recentlyAdded: "Recently Added"
        case .recentlyPlayed: "Recently Played"
        case .collection: viewModel.selectedCollection?.name ?? "Collection"
        case .artist(let name): name
        }
    }
}

// MARK: - Bottom Player Bar

struct BottomPlayerBar: View {
    @Binding var showVideo: Bool
    @Binding var showQueue: Bool

    @Environment(PlayerManager.self) private var player
    @Environment(JellyfinService.self) private var jellyfin

    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0
    @State private var isHoveringProgress = false
    @State private var progressBounce = false
    @State private var atBoundary = false

    var body: some View {
        if player.currentItem != nil {
            playerContent
                .frame(height: 72)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Divider()
                }
                .task(id: player.currentItem?.id) {
                    await extractArtworkColor()
                }
        }
    }

    private func extractArtworkColor() async {
        guard let item = player.currentItem,
              let tag = item.imageTags["Primary"],
              let url = jellyfin.imageURL(for: item.id, tag: tag, maxWidth: 200) else {
            player.artworkAccentColor = .accentColor
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data), let color = image.averageGlowColor() {
                withAnimation(.easeOut(duration: 0.5)) {
                    player.artworkAccentColor = color
                }
            }
        } catch {
            player.artworkAccentColor = .accentColor
        }
    }

    private var playerContent: some View {
        VStack(spacing: 0) {
            // Scrubbable progress bar
            GeometryReader { geo in
                let displayProgress = isScrubbing ? scrubProgress : player.progress

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                    Rectangle()
                        .fill(player.artworkAccentColor)
                        .frame(width: geo.size.width * displayProgress)

                    // Scrub handle
                    if isHoveringProgress || isScrubbing {
                        Circle()
                            .fill(player.artworkAccentColor)
                            .frame(width: 12, height: 12)
                            .position(
                                x: geo.size.width * displayProgress,
                                y: (isHoveringProgress || isScrubbing) ? 4 : 2
                            )
                    }
                }
                .frame(height: isHoveringProgress || isScrubbing ? 8 : 3)
                .scaleEffect(y: progressBounce ? 1.4 : 1.0, anchor: .center)
                .animation(.spring(response: 0.36, dampingFraction: 0.68), value: progressBounce)
                .animation(.easeOut(duration: 0.15), value: isHoveringProgress)
                .contentShape(Rectangle().size(width: geo.size.width, height: 20))
                .onHover { hovering in
                    isHoveringProgress = hovering
                }
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
            }
            .frame(height: isHoveringProgress || isScrubbing ? 8 : 3)

            HStack(spacing: 16) {
                // Album art + equalizer + track info (left)
                HStack(spacing: 12) {
                    albumArt
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    if player.isPlaying {
                        EqualizerBarsView(isPlaying: true, color: player.artworkAccentColor)
                            .frame(width: 14, height: 14)
                            .transition(.scale.combined(with: .opacity))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentChapter?.name ?? "Unknown Track")
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)

                        Text(player.currentItem?.name ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 250, alignment: .leading)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: player.isPlaying)

                Spacer()

                // Playback controls (center)
                HStack(spacing: 20) {
                    Button {
                        player.previousChapter()
                        HapticManager.play(.navigation)
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    Button {
                        player.togglePlayPause()
                        HapticManager.play(.playPause)
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    Button {
                        player.nextChapter()
                        HapticManager.play(.navigation)
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }

                Spacer()

                // Time display (right)
                HStack(spacing: 6) {
                    Text(formatTime(player.currentTime))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("/")
                        .font(.system(size: 11))
                        .foregroundStyle(.quaternary)
                    Text(formatTime(player.duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 120, alignment: .trailing)

                // Up Next hint
                if let next = player.upNext {
                    Text("Up Next: \(next.item.artist)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: 120)
                }

                // Video toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showVideo.toggle()
                    }
                } label: {
                    Image(systemName: showVideo ? "tv.fill" : "tv")
                        .font(.system(size: 14))
                        .foregroundStyle(showVideo ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(showVideo ? "Hide Video" : "Show Video")

                // Queue toggle
                Button {
                    withAnimation { showQueue.toggle() }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: showQueue ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                            .font(.system(size: 14))
                            .foregroundStyle(showQueue ? Color.accentColor : .secondary)
                        if !player.queue.isEmpty {
                            Text("\(player.queue.count)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 3)
                                .background(Capsule().fill(player.artworkAccentColor))
                                .offset(x: 6, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Toggle Queue")
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var albumArt: some View {
        if let item = player.currentItem,
           let tag = item.imageTags["Primary"],
           let url = jellyfin.imageURL(for: item.id, tag: tag, maxWidth: 100) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                artPlaceholder
            }
        } else {
            artPlaceholder
        }
    }

    private var artPlaceholder: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            Image(systemName: "music.note")
                .font(.title3)
                .foregroundStyle(.quaternary)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Sidebar Item

enum SidebarItem: Hashable {
    case allSets
    case recentlyAdded
    case recentlyPlayed
    case collection(String)
    case artist(String)
}
