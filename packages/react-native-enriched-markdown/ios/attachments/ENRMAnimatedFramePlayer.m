#import "ENRMAnimatedFramePlayer.h"
#import "ENRMAnimatedImage.h"
#import <QuartzCore/QuartzCore.h>
#include <TargetConditionals.h>

// Frames decoded ahead of the one on screen.
static const NSUInteger kPrefetchCount = 2;
// Budget for processed frames while playing; dropped on pause.
static const NSUInteger kFrameCacheCostLimit = 1024 * 1024 * 8; // 8 MB
// Retry interval while the next frame is still decoding.
static const NSTimeInterval kRetryDelay = 0.03;

static inline NSUInteger ENRMFrameByteCost(RCTUIImage *image)
{
  CGImageRef cgImage = image.CGImage;
  if (!cgImage)
    return 0;
  return CGImageGetBytesPerRow(cgImage) * CGImageGetHeight(cgImage);
}

@interface ENRMAnimatedFramePlayer ()

@property (nonatomic, weak) id<ENRMAnimatedFramePlayerDelegate> delegate;
@property (nonatomic, strong) NSHashTable<ENRMPlatformTextView *> *hosts;

// Geometry the cached frames belong to; a reset replaces both.
@property (nonatomic, copy, nullable) NSString *geometryKey;
@property (nonatomic, assign) ENRMFrameGeometry geometry;

@property (nonatomic, strong, nullable) NSCache<NSNumber *, RCTUIImage *> *frameCache;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *framesBeingDecoded;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *failedFrames;

@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) NSUInteger currentFrameIndex;
// Bumped on every start/pause so a tick queued for an earlier run is ignored.
@property (nonatomic, assign) NSUInteger generation;
// When the current frame is due to be replaced.
@property (nonatomic, assign) CFTimeInterval frameDeadline;

@end

@implementation ENRMAnimatedFramePlayer

- (instancetype)initWithAnimatedImage:(ENRMAnimatedImage *)animatedImage
                             delegate:(id<ENRMAnimatedFramePlayerDelegate>)delegate
{
  self = [super init];
  if (self) {
    _animatedImage = animatedImage;
    _delegate = delegate;
    _hosts = [NSHashTable weakObjectsHashTable];
    _framesBeingDecoded = [NSMutableSet set];
    _failedFrames = [NSMutableSet set];
  }
  return self;
}

#pragma mark - Control

- (void)resetForKey:(NSString *)key geometry:(ENRMFrameGeometry)geometry
{
  self.geometryKey = key;
  self.geometry = geometry;
  self.currentFrameIndex = 0;
  [self.frameCache removeAllObjects];
  [self.framesBeingDecoded removeAllObjects];
  [self.failedFrames removeAllObjects];
}

- (void)addHost:(ENRMPlatformTextView *)host
{
  [self.hosts addObject:host];
}

- (void)startIfNeeded
{
#if TARGET_OS_OSX
  return;
#else
  ENRMAnimatedImage *animated = self.animatedImage;
  if (self.playing || self.geometryKey == nil || animated.frameCount < 2)
    return;
  if (ENRMShouldReduceMotion())
    return;

  if (!self.frameCache) {
    self.frameCache = [[NSCache alloc] init];
    self.frameCache.totalCostLimit = kFrameCacheCostLimit;
    self.frameCache.countLimit = animated.frameCount;
  }

  self.playing = YES;
  self.generation += 1;
  self.currentFrameIndex = animated.lastDisplayedFrameIndex % animated.frameCount;
  self.frameDeadline = CACurrentMediaTime() + [animated durationAtIndex:self.currentFrameIndex];
  [self prefetchFramesStartingAt:self.currentFrameIndex + 1];
  [self scheduleTickAtDeadline];
#endif
}

- (void)pause
{
  self.playing = NO;
  self.generation += 1;
  self.frameCache = nil;
  [self.framesBeingDecoded removeAllObjects];
}

#pragma mark - Tick loop

- (void)scheduleTickAtDeadline
{
  [self scheduleTickAfter:MAX(0, self.frameDeadline - CACurrentMediaTime())];
}

- (void)scheduleTickAfter:(NSTimeInterval)delay
{
  NSUInteger generation = self.generation;
  __weak typeof(self) weakSelf = self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (strongSelf && strongSelf.generation == generation) {
      [strongSelf tick];
    }
  });
}

- (void)tick
{
  NSArray<ENRMPlatformTextView *> *hosts = [self onWindowHosts];
  if (hosts.count == 0) {
    [self pause];
    return;
  }

  NSUInteger next = [self nextPlayableFrameAfter:self.currentFrameIndex];
  if (next == NSNotFound) {
    // Nothing else decodes (corrupt file): stay on the current frame.
    [self pause];
    return;
  }

  RCTUIImage *frame = [self.frameCache objectForKey:@(next)];
  if (!frame) {
    // Decoder hasn't caught up; hold the current frame and try again shortly.
    [self prefetchFramesStartingAt:next];
    [self scheduleTickAfter:kRetryDelay];
    return;
  }

  [self showFrame:frame atIndex:next inHosts:hosts];
  [self prefetchFramesStartingAt:next + 1];
  [self advanceDeadlineBy:[self.animatedImage durationAtIndex:next]];
  [self scheduleTickAtDeadline];
}

- (void)showFrame:(RCTUIImage *)frame atIndex:(NSUInteger)index inHosts:(NSArray<ENRMPlatformTextView *> *)hosts
{
  self.currentFrameIndex = index;
  self.animatedImage.lastDisplayedFrameIndex = index;
  [self.delegate framePlayer:self showFrame:frame];
  for (ENRMPlatformTextView *host in hosts) {
    if (![self.delegate framePlayer:self redrawInHost:host]) {
      [self.hosts removeObject:host];
    }
  }
}

// Advance by the frame's delay so a late tick is absorbed rather than
// accumulated. If we fell more than a frame behind (slow decode),
// resynchronise from now instead of racing to catch up.
- (void)advanceDeadlineBy:(NSTimeInterval)duration
{
  CFTimeInterval now = CACurrentMediaTime();
  if (self.frameDeadline < now - duration) {
    self.frameDeadline = now + duration;
  } else {
    self.frameDeadline += duration;
  }
}

- (NSUInteger)nextPlayableFrameAfter:(NSUInteger)index
{
  NSUInteger count = self.animatedImage.frameCount;
  for (NSUInteger step = 1; step < count; step++) {
    NSUInteger candidate = (index + step) % count;
    if (![self.failedFrames containsObject:@(candidate)])
      return candidate;
  }
  return NSNotFound;
}

- (NSArray<ENRMPlatformTextView *> *)onWindowHosts
{
  NSMutableArray<ENRMPlatformTextView *> *onWindow = [NSMutableArray array];
  for (ENRMPlatformTextView *host in self.hosts) {
    if (host.window) {
      [onWindow addObject:host];
    }
  }
  return onWindow;
}

#pragma mark - Decoding

- (void)prefetchFramesStartingAt:(NSUInteger)start
{
  if (!self.frameCache)
    return;

  NSUInteger count = self.animatedImage.frameCount;
  for (NSUInteger i = 0; i < kPrefetchCount; i++) {
    NSUInteger index = (start + i) % count;
    NSNumber *boxedIndex = @(index);
    if ([self.frameCache objectForKey:boxedIndex] || [self.framesBeingDecoded containsObject:boxedIndex] ||
        [self.failedFrames containsObject:boxedIndex])
      continue;
    [self.framesBeingDecoded addObject:boxedIndex];
    [self decodeFrameAtIndex:index];
  }
}

- (void)decodeFrameAtIndex:(NSUInteger)index
{
  NSString *key = self.geometryKey;
  ENRMFrameGeometry geometry = self.geometry;
  __weak typeof(self) weakSelf = self;

  [self.animatedImage decodeFrameAtIndex:index
                            maxPixelSize:geometry.maxPixelSize
                              completion:^(RCTUIImage *raw) {
                                __strong typeof(weakSelf) strongSelf = weakSelf;
                                if (!strongSelf)
                                  return;
                                // Still on the decode queue: scale and clip off-main.
                                RCTUIImage *processed = raw ? [strongSelf.delegate framePlayer:strongSelf
                                                                                  processFrame:raw
                                                                                      geometry:geometry]
                                                            : nil;
                                dispatch_async(dispatch_get_main_queue(),
                                               ^{ [strongSelf storeDecodedFrame:processed atIndex:index forKey:key]; });
                              }];
}

- (void)storeDecodedFrame:(nullable RCTUIImage *)frame atIndex:(NSUInteger)index forKey:(NSString *)key
{
  NSNumber *boxedIndex = @(index);
  [self.framesBeingDecoded removeObject:boxedIndex];

  // Box changed or playback paused while decoding: the frame is stale.
  if (![key isEqualToString:self.geometryKey] || !self.playing)
    return;

  if (!frame) {
    // Skip it from now on instead of retrying the decode forever.
    [self.failedFrames addObject:boxedIndex];
    return;
  }
  [self.frameCache setObject:frame forKey:boxedIndex cost:ENRMFrameByteCost(frame)];
}

@end
