import SwiftUI

struct SetGridItem: View {
    let item: JellyfinItem
    let isSelected: Bool

    @Environment(JellyfinService.self) private var jellyfin

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.artist)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text(item.festival)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let year = item.year {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: 180)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let tag = item.imageTags["Primary"],
           let url = jellyfin.imageURL(for: item.id, tag: tag) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                placeholderView
            }
            .frame(width: 180, height: 180)
            .clipped()
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .controlBackgroundColor),
                         Color(nsColor: .controlBackgroundColor).opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.mic")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
        }
        .frame(width: 180, height: 180)
    }
}
