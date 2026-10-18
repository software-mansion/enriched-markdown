#import "ENRMBlockSlotSegmentView.h"
#import "ENRMContainerNodeView.h"
#import <React/RCTUtils.h>

@implementation ENRMBlockSlotSegmentView

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    _slotId = @"";
    _kind = ENRMBlockSlotKindImage;
    _slotHeight = 0;
    _revealFraction = 1;
    self.backgroundColor = [RCTUIColor clearColor];
#if !TARGET_OS_OSX
    self.userInteractionEnabled = NO;
    self.isAccessibilityElement = NO;
#endif
  }
  return self;
}

- (CGFloat)measureHeight:(CGFloat)maxWidth
{
  return self.reservedHeight;
}

- (CGFloat)reservedHeight
{
  // Exactly what the child is laid out at, so it never overlaps the next segment.
  CGFloat scale = RCTScreenScale();
  return ceil(MAX(_slotHeight, 0) * scale) / scale;
}

- (CGFloat)revealedHeight
{
  CGFloat scale = RCTScreenScale();
  return round(self.reservedHeight * _revealFraction * scale) / scale;
}

- (NSArray *)accessibilityElements
{
  RCTUIView *mounted = _mountedView;
  return mounted ? @[ mounted ] : @[];
}

#if TARGET_OS_OSX
- (NSView *)hitTest:(NSPoint)point
{
  return nil;
}
#endif

@end

BOOL ENRMApplyBlockSlotHeights(NSArray<RCTUIView *> *segmentViews, NSDictionary<NSString *, NSNumber *> *heights)
{
  BOOL changed = NO;
  for (RCTUIView *view in segmentViews) {
    if ([view isKindOfClass:[ENRMBlockSlotSegmentView class]]) {
      ENRMBlockSlotSegmentView *slot = (ENRMBlockSlotSegmentView *)view;
      CGFloat height = heights[slot.slotId].doubleValue;
      if (slot.slotHeight != height) {
        slot.slotHeight = height;
        changed = YES;
      }
    } else if ([view isKindOfClass:[ENRMContainerNodeView class]]) {
      if (ENRMApplyBlockSlotHeights(((ENRMContainerNodeView *)view).segmentViews, heights)) {
        changed = YES;
      }
    }
  }
  return changed;
}

void ENRMBindBlockSlotViews(NSArray<RCTUIView *> *segmentViews, NSDictionary<NSString *, RCTUIView *> *views)
{
  for (RCTUIView *view in segmentViews) {
    if ([view isKindOfClass:[ENRMBlockSlotSegmentView class]]) {
      ENRMBlockSlotSegmentView *slot = (ENRMBlockSlotSegmentView *)view;
      slot.mountedView = views[slot.slotId];
    } else if ([view isKindOfClass:[ENRMContainerNodeView class]]) {
      ENRMBindBlockSlotViews(((ENRMContainerNodeView *)view).segmentViews, views);
    }
  }
}
