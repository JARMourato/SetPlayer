import SwiftUI

struct GlowingAlbumArt: View {
    let url: URL?
    var size: CGFloat = 220
    var cornerRadius: CGFloat = 10
    var placeholderIcon: String = "music.mic"

    @State private var image: NSImage?
    @State private var glowColor: Color = .clear

    var body: some View {
        ZStack {
            // Triple-layered glow behind the artwork
            if image != nil {
                glowLayer(scale: 1.22, opacity: 0.34, blur: size * 0.32)
                glowLayer(scale: 1.75, opacity: 0.22, blur: size * 0.62)
                glowLayer(scale: 2.3, opacity: 0.12, blur: size * 0.95)
            }

            // Main image, clipped separately from glow
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color(nsColor: .controlBackgroundColor)
                        Image(systemName: placeholderIcon)
                            .font(.system(size: size * 0.18))
                            .foregroundStyle(.quaternary)
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        .task(id: url) {
            await loadImage()
        }
    }

    @ViewBuilder
    private func glowLayer(scale: CGFloat, opacity: Double, blur: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(glowColor.opacity(opacity))
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .blur(radius: blur)
            .blendMode(.screen)
    }

    private func loadImage() async {
        guard let url else {
            image = nil
            glowColor = .clear
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let nsImage = NSImage(data: data) else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                image = nsImage
                glowColor = nsImage.averageGlowColor() ?? .clear
            }
        } catch {
            // Keep placeholder on failure
        }
    }
}
