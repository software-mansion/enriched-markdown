#import "ENRMHorizontalScrollView.h"

@implementation ENRMHorizontalScrollView

#if !TARGET_OS_OSX
- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    [self.panGestureRecognizer addTarget:self action:@selector(enrm_handlePan:)];
  }
  return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer == self.panGestureRecognizer &&
      ENRMShouldYieldOutwardPan(self.contentOffset.x, -self.adjustedContentInset.left, self.isDecelerating,
                                [self.panGestureRecognizer velocityInView:self])) {
    return NO;
  }
  return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

// React Native's touch handler sits on an ancestor and is not prevented by this pan, so a parent
// Pressable would still fire onPress after a horizontal scroll. Cancel the React Native touch once the
// pan begins, as React Native's own ScrollView does through the responder system.
- (void)enrm_handlePan:(UIPanGestureRecognizer *)pan
{
  if (pan.state != UIGestureRecognizerStateBegan) {
    return;
  }
  Class touchHandlerClass = NSClassFromString(@"RCTSurfaceTouchHandler");
  for (UIView *view = self.superview; view != nil; view = view.superview) {
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
      if ([recognizer isKindOfClass:touchHandlerClass] && recognizer.enabled) {
        recognizer.enabled = NO;
        recognizer.enabled = YES;
        return;
      }
    }
  }
}
#endif

@end
