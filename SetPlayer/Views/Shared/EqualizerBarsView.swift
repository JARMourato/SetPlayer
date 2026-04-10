import SwiftUI

struct EqualizerBarsView: View {
    let isPlaying: Bool
    var color: Color = .primary
    var barCount: Int = 4
    var barWidth: CGFloat = 2.5
    var spacing: CGFloat = 2

    @State private var heights: [CGFloat] = []

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(color)
                    .frame(width: barWidth)
                    .scaleEffect(y: heights.indices.contains(index) ? heights[index] : 0.3, anchor: .bottom)
            }
        }
        .onAppear {
            heights = Array(repeating: CGFloat(0.3), count: barCount)
        }
        .task(id: isPlaying) {
            if isPlaying {
                while !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        heights = (0..<barCount).map { _ in CGFloat.random(in: 0.3...1.0) }
                    }
                    try? await Task.sleep(for: .milliseconds(300))
                }
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    heights = Array(repeating: CGFloat(0.3), count: barCount)
                }
            }
        }
    }
}
