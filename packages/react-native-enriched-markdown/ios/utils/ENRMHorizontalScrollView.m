#import "ENRMHorizontalScrollView.h"
#import "ENRMScrollWheelRouting.h"

#if TARGET_OS_OSX
@interface ENRMHorizontalScrollView () {
  ENRMScrollWheelTarget _scrollWheelLatch;
}
@end
#endif

@implementation ENRMHorizontalScrollView

#if !TARGET_OS_OSX
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer == self.panGestureRecognizer &&
      ENRMShouldYieldOutwardPan(self.contentOffset.x, -self.adjustedContentInset.left, self.isDecelerating,
                                [self.panGestureRecognizer velocityInView:self])) {
    return NO;
  }
  return [super gestureRecognizerShouldBegin:gestureRecognizer];
}
#else
// Overriding -scrollWheel: opts out of responsive scrolling; RN-macOS's RCTCustomScrollView forwards wheel events
// the same way and opts back in.
+ (BOOL)isCompatibleWithResponsiveScrolling
{
  return YES;
}

- (void)scrollWheel:(NSEvent *)event
{
  BOOL canScrollHorizontally = self.contentSize.width > NSWidth(self.contentView.bounds) + 0.5;
  if (ENRMRouteScrollWheel(&_scrollWheelLatch, event.phase, event.momentumPhase, event.scrollingDeltaX,
                           event.scrollingDeltaY, canScrollHorizontally) == ENRMScrollWheelTargetNextResponder) {
    [self.nextResponder scrollWheel:event];
    return;
  }
  [super scrollWheel:event];
}
#endif

@end
