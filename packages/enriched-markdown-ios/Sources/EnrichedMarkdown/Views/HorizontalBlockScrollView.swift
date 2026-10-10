import UIKit

/// Horizontal scroll view shared by scrollable code blocks, tables and
/// display math.
///
/// A rightward pan that starts while the view is settled at its leading
/// edge is refused, so a full-width back gesture can begin instead. Inward
/// pans, pans from inside the content, and pans during deceleration or
/// bounce scroll as usual. Cost: no bounce on a fresh rightward pan at the
/// leading edge. Left edge only; RTL is not handled.
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

    /// `leadingBoundary` is the content offset at the leading edge.
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
