import UIKit

/// Refuses a rightward pan that starts settled at the leading edge, so a
/// full-width back gesture can begin instead. Left edge only; RTL is not handled.
package final class HorizontalBlockScrollView: UIScrollView {
    override package func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer,
           Self.shouldYieldOutwardPan(
               contentOffsetX: contentOffset.x,
               leadingBoundary: -adjustedContentInset.left,
               decelerating: isDecelerating,
               velocity: panGestureRecognizer.velocity(in: self)
           ) {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    static func shouldYieldOutwardPan(
        contentOffsetX: CGFloat,
        leadingBoundary: CGFloat,
        decelerating: Bool,
        velocity: CGPoint
    ) -> Bool {
        let outward = velocity.x > abs(velocity.y)
        let settledAtLeadingEdge = !decelerating && abs(contentOffsetX - leadingBoundary) <= 0.5
        return outward && settledAtLeadingEdge
    }
}
