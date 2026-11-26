#import "ENRMOutsideTapDeselection.h"

#if !TARGET_OS_OSX

// The selection handles' knobs reach a little past the text view's bounds; a
// tap on one is not a tap away.
static const CGFloat kENRMSelectionHandleSlop = 12.0;

@interface ENRMOutsideTapDeselection () <UIGestureRecognizerDelegate>
@end

@implementation ENRMOutsideTapDeselection {
  UITapGestureRecognizer *_recognizer;
  __weak UITextView *_textView;
}

- (void)dealloc
{
  [self reset];
}

- (void)textViewDidChangeSelection:(UITextView *)textView
{
  if (textView.selectedRange.length > 0 && textView.window != nil) {
    _textView = textView;
    [self attachToWindow:textView.window];
  } else if (textView == _textView) {
    [self reset];
  }
}

- (void)attachToWindow:(UIWindow *)window
{
  if (_recognizer == nil) {
    _recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedOutside:)];
    _recognizer.cancelsTouchesInView = NO;
    _recognizer.delaysTouchesBegan = NO;
    _recognizer.delaysTouchesEnded = NO;
    _recognizer.delegate = self;
  }
  if (_recognizer.view != window) {
    [_recognizer.view removeGestureRecognizer:_recognizer];
    [window addGestureRecognizer:_recognizer];
  }
}

- (void)reset
{
  [_recognizer.view removeGestureRecognizer:_recognizer];
  _textView = nil;
}

- (void)tappedOutside:(UITapGestureRecognizer *)recognizer
{
  __weak UITextView *weakTextView = _textView;
  [self reset];
  // On the next turn of the run loop, so a control the tap lands on acts on
  // the selection first. The edit menu's touches do not reach a window
  // recognizer on current iOS; this keeps Copy working where they might.
  dispatch_async(dispatch_get_main_queue(), ^{
    UITextView *textView = weakTextView;
    if (textView == nil || textView.selectedRange.length == 0) {
      return;
    }
    ENRMClearSelection(textView);
    if (textView.isFirstResponder) {
      [textView resignFirstResponder];
    }
  });
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
  UITextView *textView = _textView;
  if (textView == nil || textView.selectedRange.length == 0) {
    return NO;
  }
  CGPoint point = [touch locationInView:textView];
  return !CGRectContainsPoint(CGRectInset(textView.bounds, -kENRMSelectionHandleSlop, -kENRMSelectionHandleSlop),
                              point);
}

@end

#endif
