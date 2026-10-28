#import "ENRMBlockSlotRevealAnimator.h"
#include <TargetConditionals.h>

static const CFTimeInterval kRevealDuration = 0.20;

@implementation ENRMBlockSlotRevealAnimator {
  void (^_onFrame)(void);
  NSMutableDictionary<NSString *, NSNumber *> *_starts;
  // Set while the handler runs, so one frame reads one time.
  CFTimeInterval _frameTime;
#if !TARGET_OS_OSX
  CADisplayLink *_displayLink;
#endif
}

- (instancetype)initWithFrameHandler:(void (^)(void))onFrame
{
  if (self = [super init]) {
    _onFrame = [onFrame copy];
    _starts = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)startSlot:(NSString *)slotId
{
#if !TARGET_OS_OSX
  _starts[slotId] = @(CACurrentMediaTime());
  if (_displayLink == nil) {
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(step:)];
    _displayLink.preferredFramesPerSecond = 0;
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
  }
#else
  // TODO: Grow slots in on macOS once a display-sync callback is wired up (see ENRMTailFadeInAnimator).
#endif
}

- (CGFloat)progressForSlot:(NSString *)slotId
{
  NSNumber *start = _starts[slotId];
  if (start == nil) {
    return 1;
  }
  CFTimeInterval now = _frameTime > 0 ? _frameTime : CACurrentMediaTime();
  return fmin(fmax((now - start.doubleValue) / kRevealDuration, 0.0), 1.0);
}

- (void)cancel
{
  [_starts removeAllObjects];
#if !TARGET_OS_OSX
  [_displayLink invalidate];
  _displayLink = nil;
#endif
}

#if !TARGET_OS_OSX
- (void)step:(CADisplayLink *)link
{
  _frameTime = link.targetTimestamp;
  // The handler sees the slots that just finished at 1, then they are dropped.
  _onFrame();
  for (NSString *slotId in _starts.allKeys) {
    if (_frameTime - _starts[slotId].doubleValue >= kRevealDuration) {
      [_starts removeObjectForKey:slotId];
    }
  }
  _frameTime = 0;
  if (_starts.count == 0) {
    [self cancel];
  }
}
#endif

@end
