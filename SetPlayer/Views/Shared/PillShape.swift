import SwiftUI

/// A rounded rectangle with independently animatable corner radii.
struct PillShape: Shape {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomLeft: CGFloat
    var bottomRight: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(topLeft, topRight),
                AnimatablePair(bottomLeft, bottomRight)
            )
        }
        set {
            topLeft = newValue.first.first
            topRight = newValue.first.second
            bottomLeft = newValue.second.first
            bottomRight = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let maxRadius = min(rect.width, rect.height) / 2
        let tl = min(topLeft, maxRadius)
        let tr = min(topRight, maxRadius)
        let bl = min(bottomLeft, maxRadius)
        let br = min(bottomRight, maxRadius)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))

        // Top edge → top-right corner
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY + tr),
            radius: tr
        )

        // Right edge → bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX - br, y: rect.maxY),
            radius: br
        )

        // Bottom edge → bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bl),
            radius: bl
        )

        // Left edge → top-left corner
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX + tl, y: rect.minY),
            radius: tl
        )

        path.closeSubpath()
        return path
    }
}

extension PillShape {
    init(cornerRadius: CGFloat) {
        self.init(topLeft: cornerRadius, topRight: cornerRadius, bottomLeft: cornerRadius, bottomRight: cornerRadius)
    }
}
