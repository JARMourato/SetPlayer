import AppKit
import SwiftUI

extension NSImage {
    /// Extracts the average color from image pixels, boosted for glow visibility.
    /// Downsamples to 50x50 for performance.
    func averageGlowColor() -> Color? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let sampleSize = 50
        guard let context = CGContext(
            data: nil,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
        guard let data = context.data else { return nil }

        let totalPixels = sampleSize * sampleSize
        let pointer = data.bindMemory(to: UInt32.self, capacity: totalPixels)
        var totalR: UInt64 = 0, totalG: UInt64 = 0, totalB: UInt64 = 0

        for i in 0..<totalPixels {
            let pixel = pointer[i]
            totalR += UInt64(pixel & 0xFF)
            totalG += UInt64((pixel >> 8) & 0xFF)
            totalB += UInt64((pixel >> 16) & 0xFF)
        }

        let avgR = CGFloat(totalR) / CGFloat(totalPixels) / 255.0
        let avgG = CGFloat(totalG) / CGFloat(totalPixels) / 255.0
        let avgB = CGFloat(totalB) / CGFloat(totalPixels) / 255.0

        // Near-black artwork gets a neutral glow
        if avgR < 0.03 && avgG < 0.03 && avgB < 0.03 {
            return Color(nsColor: NSColor(white: 0.5, alpha: 1.0))
        }

        let nsColor = NSColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)
        let rgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // Boost saturation and brightness so glow is visible on dark backgrounds
        return Color(nsColor: NSColor(
            hue: h,
            saturation: min(max(s * 1.15, 0.55), 1.0),
            brightness: min(max(b * 1.18, 0.72), 1.0),
            alpha: a
        ))
    }
}
