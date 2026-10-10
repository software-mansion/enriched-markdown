import UIKit

/// A block attachment hosted in a scrolling view. TextKit 2 recreates the
/// view whenever the block re-enters the viewport, and a re-render replaces
/// the attachment, so the scroll position is kept here and carried over.
package protocol HorizontallyScrollingAttachment: AnyObject {
    var preservedContentOffset: CGPoint { get set }
}
