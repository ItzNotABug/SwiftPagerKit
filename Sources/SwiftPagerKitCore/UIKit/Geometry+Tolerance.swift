#if canImport(UIKit)
import CoreGraphics

extension CGPoint {
    func isApproximatelyEqual(to other: CGPoint) -> Bool {
        abs(x - other.x) < 0.5 && abs(y - other.y) < 0.5
    }
}

extension CGSize {
    func isApproximatelyEqual(to other: CGSize) -> Bool {
        abs(width - other.width) < 0.5 && abs(height - other.height) < 0.5
    }
}
#endif
