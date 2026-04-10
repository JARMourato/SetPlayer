import SwiftUI

struct SetDetailView: View {
    let item: JellyfinItem
    let onBack: () -> Void

    @Environment(JellyfinService.self) private var jellyfin
    @Environment(PlayerManager.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                Divider()
                    .padding(.horizontal, 24)

                tracklistSection
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            GlowingAlbumArt(
                url: item.imageTags["Primary"].flatMap { jellyfin.imageURL(for: item.id, tag: $0, maxWidth: 500) },
                size: 220,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                    .frame(height: 8)

                Text(item.artist)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(2)

                Text(item.festival)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 16) {
                    if let year = item.year {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let runtime = item.runtime {
                        Text("\(runtime) min")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(item.chapters.count) tracks")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)

                if let overview = item.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
                        .padding(.top, 4)
                }

                HStack(spacing: 12) {
                    Button {
                        if let url = jellyfin.streamURL(for: item.id) {
                            player.play(item: item, streamURL: url)
                            HapticManager.play(.playPause)
                        }
                    } label: {
                        Label(isCurrentSet ? "Playing" : "Play", systemImage: isCurrentSet && player.isPlaying ? "waveform" : "play.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .controlSize(.large)
                    .disabled(isCurrentSet && player.isPlaying)

                    Menu {
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
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 32)
                }
                .padding(.top, 8)

                Spacer()
                    .frame(height: 8)
            }
        }
    }

    // MARK: - Tracklist

    private var tracklistSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: 36, alignment: .trailing)
                Text("Title")
                    .padding(.leading, 16)
                Spacer()
                Text("Time")
                    .frame(width: 72, alignment: .trailing)
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)

            Divider()

            ForEach(Array(item.chapters.enumerated()), id: \.element.id) { index, chapter in
                TrackRow(
                    chapter: chapter,
                    index: index,
                    isCurrent: isCurrentSet && index == player.currentChapterIndex,
                    isPlaying: isCurrentSet && index == player.currentChapterIndex && player.isPlaying,
                    onTap: {
                        if !isCurrentSet, let url = jellyfin.streamURL(for: item.id) {
                            player.play(item: item, streamURL: url)
                        }
                        player.seekToChapter(at: index)
                    }
                )

                if index < item.chapters.count - 1 {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
    }

    private var isCurrentSet: Bool {
        player.currentItem?.id == item.id
    }
}

// MARK: - Track Row

struct TrackRow: View {
    let chapter: JellyfinChapter
    let index: Int
    let isCurrent: Bool
    let isPlaying: Bool
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            // Track number / playing indicator
            Group {
                if isCurrent && isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                } else if isHovering {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 13, design: .default))
                        .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                }
            }
            .frame(width: 36, alignment: .trailing)

            Text(chapter.name)
                .font(.system(size: 13))
                .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                .lineLimit(1)
                .padding(.leading, 16)

            Spacer()

            Text(chapter.startFormatted)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isCurrent ? Color.accentColor.opacity(0.08) : (isHovering ? Color.primary.opacity(0.04) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(perform: onTap)
    }
}
