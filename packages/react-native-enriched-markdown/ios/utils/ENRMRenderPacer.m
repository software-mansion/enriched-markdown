#import "ENRMRenderPacer.h"
#import <QuartzCore/QuartzCore.h>

// A render whose apply never comes (dropped as superseded, or rendering nothing) holds the next back no longer.
static const CFTimeInterval kENRMPacedRenderTimeout = 0.25;
static const NSUInteger kENRMMaxRenderStride = 4;
// Applying a render beyond this share of a frame raises the stride; this many in a row within it lower it again.
static const CFTimeInterval kENRMApplyBudgetShare = 0.7;
static const NSUInteger kENRMHealthyAppliesToRelax = 8;

@class ENRMRenderPacer;

// The display link's target: it would retain the pacer.
@interface ENRMRenderPacerTicker : NSObject
@property (nonatomic, weak) ENRMRenderPacer *pacer;
@end

@interface ENRMRenderPacer ()
- (void)tick:(CFTimeInterval)frameDuration;
@end

@implementation ENRMRenderPacerTicker

- (void)tick:(id)sender
{
#if TARGET_OS_OSX
  [self.pacer tick:1.0 / 60];
#else
  CADisplayLink *link = sender;
  [self.pacer tick:link.targetTimestamp - link.timestamp];
#endif
}

@end

@implementation ENRMRenderPacer {
  BOOL (^_render)(void);
  BOOL _requested;
  CFTimeInterval _inFlightSince;
  NSUInteger _stride;
  NSUInteger _framesUntilRender;
  NSUInteger _healthyApplies;
  CFTimeInterval _frameDuration;
#if TARGET_OS_OSX
  NSTimer *_link;
#else
  CADisplayLink *_link;
#endif
}

- (instancetype)initWithRender:(BOOL (^)(void))render
{
  if (self = [super init]) {
    _render = [render copy];
    _stride = 1;
    _frameDuration = 1.0 / 60;
  }
  return self;
}

- (void)dealloc
{
  [_link invalidate];
}

- (BOOL)inFlight
{
  return _inFlightSince != 0 && CACurrentMediaTime() - _inFlightSince < kENRMPacedRenderTimeout;
}

- (void)requestRender
{
  _requested = YES;
  [self updateLink];
}

- (void)renderAppliedIn:(CFTimeInterval)duration
{
  _inFlightSince = 0;
  if (duration > _frameDuration * kENRMApplyBudgetShare) {
    _stride = MIN(_stride * 2, kENRMMaxRenderStride);
    _healthyApplies = 0;
  } else if (_stride > 1 && ++_healthyApplies >= kENRMHealthyAppliesToRelax) {
    _stride /= 2;
    _healthyApplies = 0;
  }
  [self updateLink];
}

- (void)cancel
{
  _requested = NO;
  _inFlightSince = 0;
  [self updateLink];
}

- (void)reset
{
  [self cancel];
  _stride = 1;
  _framesUntilRender = 0;
  _healthyApplies = 0;
}

// Runs the display link while a render waits for a frame, also behind one in flight, which is let
// go on a frame past the timeout.
- (void)updateLink
{
  if (_requested) {
    if (_link == nil) {
      ENRMRenderPacerTicker *ticker = [[ENRMRenderPacerTicker alloc] init];
      ticker.pacer = self;
#if TARGET_OS_OSX
      // macOS has no CADisplayLink.
      _link = [NSTimer timerWithTimeInterval:1.0 / 60 target:ticker selector:@selector(tick:) userInfo:nil repeats:YES];
      [NSRunLoop.mainRunLoop addTimer:_link forMode:NSRunLoopCommonModes];
#else
      _link = [CADisplayLink displayLinkWithTarget:ticker selector:@selector(tick:)];
      [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
#endif
    }
#if !TARGET_OS_OSX
    _link.paused = NO;
#endif
  } else {
#if TARGET_OS_OSX
    [_link invalidate];
    _link = nil;
#else
    _link.paused = YES;
#endif
  }
}

- (void)tick:(CFTimeInterval)frameDuration
{
  if (frameDuration > 0) {
    _frameDuration = frameDuration;
  }
  if (!_requested || [self inFlight]) {
    return;
  }
  if (_framesUntilRender > 0) {
    _framesUntilRender--;
    return;
  }
  _requested = NO;
  _framesUntilRender = _stride - 1;
  [self updateLink];
  if (_render()) {
    _inFlightSince = CACurrentMediaTime();
  }
}

@end
