import SwiftUI

struct MenuBarMarqueeText: View {
    let text: String
    let maxChars: Int
    let currentTime: Double

    private let separator = "  ·  "

    private var displayText: String {
        if text.count <= maxChars {
            return text
        }
        let padded = text + separator
        let tick = Int(currentTime * 4)
        let offset = tick % padded.count
        let doubled = padded + padded
        let start = doubled.index(doubled.startIndex, offsetBy: offset)
        let end = doubled.index(start, offsetBy: maxChars)
        return String(doubled[start..<end])
    }

    private let font = Font.system(size: 12, design: .monospaced)

    var body: some View {
        Text(String(repeating: "M", count: maxChars))
            .font(font)
            .hidden()
            .overlay(alignment: .leading) {
                Text(displayText)
                    .font(font)
            }
    }
}
