import UIKit

/// Keeps a block's horizontal scroll position across provider recreation and re-renders.
package protocol HorizontallyScrollingAttachment: AnyObject {
    var preservedContentOffset: CGPoint { get set }
}
