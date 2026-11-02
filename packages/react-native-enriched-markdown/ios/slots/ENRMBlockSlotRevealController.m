#import "ENRMBlockSlotRevealController.h"
#import "ENRMBlockSlotReveal.h"
#import "ENRMBlockSlotRevealAnimator.h"
#import "ENRMBlockSlotSegmentView.h"
#import "ENRMContainerNodeView.h"

@implementation ENRMBlockSlotRevealController {
  ENRMBlockSlotRevealAnimator *_animator;
  NSMutableSet<NSString *> *_shownSlotIds;
}

- (instancetype)initWithFrameHandler:(void (^)(void))onFrame
{
  if (self = [super init]) {
    _animator = [[ENRMBlockSlotRevealAnimator alloc] initWithFrameHandler:onFrame];
    _shownSlotIds = [NSMutableSet set];
  }
  return self;
}

- (void)noteHeights:(NSDictionary<NSString *, NSNumber *> *)heights
         inSegments:(NSArray<RCTUIView *> *)segmentViews
             reveal:(BOOL)reveal
{
  for (RCTUIView *view in segmentViews) {
    if (![view isKindOfClass:[ENRMBlockSlotSegmentView class]]) {
      continue;
    }
    NSString *slotId = ((ENRMBlockSlotSegmentView *)view).slotId;
    if (heights[slotId].doubleValue <= 0 || [_shownSlotIds containsObject:slotId]) {
      continue;
    }
    [_shownSlotIds addObject:slotId];
    if (reveal) {
      [_animator startSlot:slotId];
    }
  }
}

- (void)keepSlotIds:(NSSet<NSString *> *)slotIds
{
  [_shownSlotIds intersectSet:slotIds];
}

- (void)applyToSegments:(NSArray<RCTUIView *> *)segmentViews slotViews:(NSArray *)slotViews
{
  NSMutableDictionary<NSString *, id<ENRMBlockSlotRevealTarget>> *targets = [NSMutableDictionary dictionary];
  for (id view in slotViews) {
    if ([view conformsToProtocol:@protocol(ENRMBlockSlotRevealTarget)]) {
      targets[((id<ENRMBlockSlotRevealTarget>)view).slotId] = view;
    }
  }

  CGFloat missing = 0;
  for (RCTUIView *view in segmentViews) {
    if ([view isKindOfClass:[ENRMBlockSlotSegmentView class]]) {
      ENRMBlockSlotSegmentView *slot = (ENRMBlockSlotSegmentView *)view;
      const CGFloat progress = [_animator progressForSlot:slot.slotId];
      slot.revealFraction = ENRMBlockSlotRevealEaseOut(progress);
      [self reveal:targets
              slotId:slot.slotId
              offset:missing
          clipHeight:progress < 1 ? slot.revealedHeight : ENRMBlockSlotNoClip];
      missing += slot.reservedHeight - slot.revealedHeight;
    } else if (missing > 0 && [view isKindOfClass:[ENRMContainerNodeView class]]) {
      [self offsetSlotsIn:((ENRMContainerNodeView *)view).segmentViews by:missing targets:targets];
    }
  }
  for (id<ENRMBlockSlotRevealTarget> target in targets.allValues) {
    [target setRevealOffset:0 clipHeight:ENRMBlockSlotNoClip];
  }
}

- (void)offsetSlotsIn:(NSArray<RCTUIView *> *)segmentViews
                   by:(CGFloat)offset
              targets:(NSMutableDictionary<NSString *, id<ENRMBlockSlotRevealTarget>> *)targets
{
  for (RCTUIView *view in segmentViews) {
    if ([view isKindOfClass:[ENRMBlockSlotSegmentView class]]) {
      [self reveal:targets
              slotId:((ENRMBlockSlotSegmentView *)view).slotId
              offset:offset
          clipHeight:ENRMBlockSlotNoClip];
    } else if ([view isKindOfClass:[ENRMContainerNodeView class]]) {
      [self offsetSlotsIn:((ENRMContainerNodeView *)view).segmentViews by:offset targets:targets];
    }
  }
}

// Takes the target out of `targets`, so whatever is left there afterwards is reset.
- (void)reveal:(NSMutableDictionary<NSString *, id<ENRMBlockSlotRevealTarget>> *)targets
        slotId:(NSString *)slotId
        offset:(CGFloat)offset
    clipHeight:(CGFloat)clipHeight
{
  [targets[slotId] setRevealOffset:offset clipHeight:clipHeight];
  [targets removeObjectForKey:slotId];
}

- (void)cancel
{
  [_animator cancel];
}

- (void)reset
{
  [_animator cancel];
  [_shownSlotIds removeAllObjects];
}

@end
