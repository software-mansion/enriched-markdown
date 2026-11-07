#import "ENRMUIKit.h"

/// Horizontal scroll view shared by code blocks, tables and display math.
///
/// A rightward pan that starts while the view is settled at its leading edge is
/// refused, so a full-width back gesture (react-native-screens
/// `fullScreenGestureEnabled`, iOS 26 content pop) can begin instead. Inward
/// pans, pans from inside the content, and pans during deceleration or bounce
/// scroll as usual. Cost: no bounce on a fresh rightward pan at the leading
/// edge. Left edge only; RTL is not handled.
///
/// On macOS, a predominantly vertical scroll-wheel event goes to the next
/// responder, so the page keeps scrolling while the cursor is over a block.
///
/// TODO: move this decision to react-native-screens. RNSScreenStack already
/// inspects competing scroll-view pans (`shouldRequireFailureOfGestureRecognizer:`
/// on iOS 26, `shouldRecognizeSimultaneouslyWithGestureRecognizer:` before);
/// treating a scroll view settled at its leading edge as not competing would
/// cover every horizontal scroll view, keep the bounce when nothing can pop,
/// and handle RTL. Then this subclass is only needed without RNS.
@interface ENRMHorizontalScrollView : RCTUIScrollView
@end

/// Decision behind `-gestureRecognizerShouldBegin:`, kept pure so it can be
/// tested without a live scroll view. `leadingBoundary` is the content offset
/// at the leading edge, i.e. `-adjustedContentInset.left`.
static inline BOOL ENRMShouldYieldOutwardPan(CGFloat contentOffsetX, CGFloat leadingBoundary, BOOL decelerating,
                                             CGPoint velocity)
{
  BOOL outward = velocity.x > fabs(velocity.y);
  BOOL settledAtLeadingEdge = !decelerating && fabs(contentOffsetX - leadingBoundary) <= 0.5;
  return outward && settledAtLeadingEdge;
}

/// Decision behind macOS `-scrollWheel:`: vertical wheel and trackpad motion
/// belongs to the enclosing scroll view, not to a horizontal block.
static inline BOOL ENRMIsPredominantlyVerticalScroll(CGFloat deltaX, CGFloat deltaY)
{
  return fabs(deltaY) > fabs(deltaX);
}
