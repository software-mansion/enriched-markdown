#import "ENRMTextViewport.h"
#import "ENRMVisibleArea.h"

#if !TARGET_OS_OSX
// The drawn rect moves in steps, so scrolling moves it (and draws a new tile) once per step.
static const CGFloat kENRMViewportStep = 256;

@implementation ENRMTextViewportContainer

- (void)setSize:(CGSize)size
{
  if (!_sizeHeld) {
    [super setSize:size];
  }
}

- (void)setHeldSize:(CGSize)size
{
  if (!CGSizeEqualToSize(self.size, size)) {
    [super setSize:size];
  }
}

@end

#endif

@implementation ENRMTextViewport {
  __weak ENRMPlatformTextView *_textView;
#if !TARGET_OS_OSX
  ENRMVisibleArea *_visibleArea;
  __weak UIView *_visibleAreaView;
  CGFloat _drawnTop;
  CGFloat _drawnBottom;
  CGRect _appliedContentFrame;
#endif
}

- (instancetype)initWithTextView:(ENRMPlatformTextView *)textView
{
  if (self = [super init]) {
    _textView = textView;
#if !TARGET_OS_OSX
    // The viewport sizes the container: UIKit would size it to the frame.
    textView.textContainer.heightTracksTextView = NO;
    [self heldContainer].sizeHeld = YES;
    _appliedContentFrame = CGRectNull;
#endif
  }
  return self;
}

- (void)setContentFrame:(CGRect)contentFrame
{
  _contentFrame = contentFrame;
  [self update];
}

#if !TARGET_OS_OSX
- (nullable ENRMTextViewportContainer *)heldContainer
{
  NSTextContainer *container = _textView.textContainer;
  return [container isKindOfClass:[ENRMTextViewportContainer class]] ? (ENRMTextViewportContainer *)container : nil;
}

- (ENRMTextLayoutResult)measureLayoutAtWidth:(CGFloat)width
{
  ENRMTextViewportContainer *heldContainer = [self heldContainer];
  if (heldContainer == nil) {
    return ENRMMeasureTextLayout(_textView, width);
  }
  [heldContainer setHeldSize:CGSizeMake(width, CGFLOAT_MAX)];
  if (width != _appliedContentFrame.size.width) {
    // The next update sizes the container back to the frame.
    _appliedContentFrame = CGRectNull;
  }
  NSLayoutManager *layoutManager = _textView.layoutManager;
  [layoutManager ensureLayoutForTextContainer:heldContainer];
  ENRMTextLayoutResult result;
  result.usedRect = [layoutManager usedRectForTextContainer:heldContainer];
  result.extraLineFragmentRect = layoutManager.extraLineFragmentRect;
  return result;
}

- (void)update
{
  UITextView *textView = _textView;
  if (textView == nil) {
    return;
  }
  UIView *host = textView.superview;
  if (host != _visibleAreaView) {
    _visibleAreaView = host;
    __weak ENRMTextViewport *weakSelf = self;
    _visibleArea = host != nil ? [[ENRMVisibleArea alloc] initWithView:host onChange:^{ [weakSelf update]; }] : nil;
  }
  // Read first: it stops observing the scroll views once the text view left the window.
  CGRect visible = _visibleArea != nil ? [_visibleArea visibleRect] : CGRectNull;
  CGRect content = _contentFrame;
  if (content.size.width <= 0) {
    // Not laid out yet: the text view keeps the frame it has.
    return;
  }
  CGFloat height = content.size.height;
  CGFloat top = 0;
  CGFloat bottom = height;
  id<ENRMTextViewportView> drawingView =
      [textView conformsToProtocol:@protocol(ENRMTextViewportView)] ? (id<ENRMTextViewportView>)textView : nil;
  if (drawingView != nil && !CGRectIsInfinite(visible) && height > 0) {
    visible = CGRectOffset(visible, -content.origin.x, -content.origin.y);
    if (CGRectIsEmpty(visible)) {
      // Off screen or out of the window (null): nothing drawn (the window attach draws it again).
      bottom = 0;
    } else {
      top = MAX(0, floor((CGRectGetMinY(visible) - ENRMVisibleAreaMargin) / kENRMViewportStep) * kENRMViewportStep);
      bottom =
          MIN(height, ceil((CGRectGetMaxY(visible) + ENRMVisibleAreaMargin) / kENRMViewportStep) * kENRMViewportStep);
      bottom = MAX(bottom, top);
    }
  }

  if (top == _drawnTop && bottom == _drawnBottom && CGRectEqualToRect(content, _appliedContentFrame)) {
    return;
  }
  _drawnTop = top;
  _drawnBottom = bottom;
  _appliedContentFrame = content;

  if (!CGRectEqualToRect(textView.frame, content)) {
    textView.frame = content;
  }
  CGSize containerSize = CGSizeMake(content.size.width, CGFLOAT_MAX);
  ENRMTextViewportContainer *heldContainer = [self heldContainer];
  if (heldContainer != nil) {
    [heldContainer setHeldSize:containerSize];
  } else if (!CGSizeEqualToSize(textView.textContainer.size, containerSize)) {
    textView.textContainer.size = containerSize;
  }
  [drawingView setDrawnRect:CGRectMake(0, top, content.size.width, bottom - top)];
}

- (void)refreshLayout
{
  UITextView *textView = _textView;
  textView.contentOffset = CGPointZero;
  NSUInteger length = textView.textStorage.length;
  if (length > 0) {
    [textView.layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, length) actualCharacterRange:NULL];
  }
  _appliedContentFrame = CGRectNull;
  [self update];
  ENRMSetNeedsDisplay(textView);
  if ([textView conformsToProtocol:@protocol(ENRMTextViewportView)]) {
    [(id<ENRMTextViewportView>)textView setNeedsDisplayFromGlyphIndex:0];
  }
}
#else
- (ENRMTextLayoutResult)measureLayoutAtWidth:(CGFloat)width
{
  return ENRMMeasureTextLayout(_textView, width);
}

- (void)update
{
  _textView.frame = _contentFrame;
}

- (void)refreshLayout
{
  [self update];
  ENRMRefreshTextViewLayout(_textView);
}
#endif

@end
