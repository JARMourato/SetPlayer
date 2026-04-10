import SwiftUI

struct QueueView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(LibraryViewModel.self) private var viewModel
    @Environment(JellyfinService.self) private var jellyfin

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if player.queue.isEmpty {
                emptyState
            } else {
                queueList
            }
        }
        .frame(width: 260)
        .background(Color(nsColor: .windowBackgroundColor))
        .dropDestination(for: String.self) { ids, _ in
            var added = false
            for id in ids {
                if let item = viewModel.items.first(where: { $0.id == id }),
                   let url = jellyfin.streamURL(for: id) {
                    let imageURL = item.imageTags["Primary"].flatMap {
                        jellyfin.imageURL(for: item.id, tag: $0, maxWidth: 80)
                    }
                    player.addToQueue(item, streamURL: url, imageURL: imageURL)
                    added = true
                }
            }
            if added { HapticManager.play(.selection) }
            return added
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Up Next", systemImage: "list.bullet")
                .font(.system(size: 13, weight: .bold))

            Spacer()

            if !player.queue.isEmpty {
                Text("\(player.queue.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary))

                Button("Clear") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        player.clearQueue()
                    }
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("Queue is empty")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Drag sets here or right-click to add")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Queue List

    private var queueList: some View {
        List {
            ForEach(player.queue) { entry in
                queueRow(entry)
            }
            .onDelete { offsets in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    player.removeFromQueue(at: offsets)
                }
            }
            .onMove { source, destination in
                player.moveInQueue(from: source, to: destination)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func queueRow(_ entry: QueueEntry) -> some View {
        HStack(spacing: 10) {
            if let url = entry.imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(nsColor: .controlBackgroundColor)
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                ZStack {
                    Color(nsColor: .controlBackgroundColor)
                    Image(systemName: "music.mic")
                        .font(.system(size: 12))
                        .foregroundStyle(.quaternary)
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.item.artist)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text(entry.item.festival)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if let runtime = entry.item.runtime {
                Text("\(runtime)m")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, 2)
    }
}
