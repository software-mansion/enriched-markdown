#import "ENRMHorizontalScrollView.h"

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
- (void)scrollWheel:(NSEvent *)event
{
  if (ENRMIsPredominantlyVerticalScroll(event.scrollingDeltaX, event.scrollingDeltaY)) {
    [self.nextResponder scrollWheel:event];
    return;
  }
  [super scrollWheel:event];
}
#endif

@end
