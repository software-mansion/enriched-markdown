#import "ENRMAnimatedImage.h"
#include <TargetConditionals.h>

// Browsers treat delays of 10ms or less as "unspecified" and play them at 100ms.
static const NSTimeInterval kMinimumFrameDelay = 0.010;
static const NSTimeInterval kDefaultFrameDelay = 0.1;

static RCTUIImage *ENRMImageFromCGImage(CGImageRef cgImage)
{
#if !TARGET_OS_OSX
  return [UIImage imageWithCGImage:cgImage];
#else
  CGSize size = CGSizeMake(CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
  return (RCTUIImage *)[[NSImage alloc] initWithCGImage:cgImage size:size];
#endif
}

@implementation ENRMAnimatedImage {
  CGImageSourceRef _source;
  NSArray<NSNumber *> *_durations;
  dispatch_queue_t _decodeQueue;
}

+ (BOOL)isGIFData:(NSData *)data
{
  if (data.length < 6)
    return NO;
  const unsigned char *bytes = data.bytes;
  return bytes[0] == 'G' && bytes[1] == 'I' && bytes[2] == 'F' && bytes[3] == '8' &&
         (bytes[4] == '7' || bytes[4] == '9') && bytes[5] == 'a';
}

+ (instancetype)animatedImageWithData:(NSData *)data
{
  if (![self isGIFData:data])
    return nil;

  CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
  if (!source)
    return nil;

  size_t count = CGImageSourceGetCount(source);
  if (count < 2) {
    CFRelease(source);
    return nil;
  }

  ENRMAnimatedImage *image = [[self alloc] initWithSource:source data:data frameCount:count];
  if (!image) {
    CFRelease(source);
  }
  return image;
}

- (instancetype)initWithSource:(CGImageSourceRef)source data:(NSData *)data frameCount:(size_t)count
{
  self = [super init];
  if (!self)
    return nil;

  // Decode the poster eagerly: it is drawn from other queues while
  // _decodeQueue may be reading the same source.
  NSDictionary *eager = @{(__bridge NSString *)kCGImageSourceShouldCacheImmediately : @YES};
  CGImageRef first = CGImageSourceCreateImageAtIndex(source, 0, (__bridge CFDictionaryRef)eager);
  if (!first)
    return nil;

  _source = source;
  _data = data;
  _frameCount = count;
  _decodeQueue = dispatch_queue_create("com.swmansion.enriched.markdown.gif-frames", DISPATCH_QUEUE_SERIAL);
  _firstFrame = ENRMImageFromCGImage(first);
  CGImageRelease(first);

  NSMutableArray<NSNumber *> *durations = [NSMutableArray arrayWithCapacity:count];
  NSTimeInterval total = 0;
  for (size_t i = 0; i < count; i++) {
    NSTimeInterval delay = [self readDelayAtIndex:i];
    total += delay;
    [durations addObject:@(delay)];
  }
  _durations = durations;
  _totalDuration = total;
  return self;
}

- (void)dealloc
{
  if (_source) {
    CFRelease(_source);
  }
}

- (NSTimeInterval)readDelayAtIndex:(size_t)index
{
  NSTimeInterval delay = kDefaultFrameDelay;
  CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(_source, index, NULL);
  if (properties) {
    NSDictionary *gif = ((__bridge NSDictionary *)properties)[(__bridge NSString *)kCGImagePropertyGIFDictionary];
    NSNumber *unclamped = gif[(__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime];
    NSNumber *clamped = gif[(__bridge NSString *)kCGImagePropertyGIFDelayTime];
    NSNumber *value = unclamped.doubleValue > 0 ? unclamped : clamped;
    if (value) {
      delay = value.doubleValue;
    }
    CFRelease(properties);
  }
  if (delay <= kMinimumFrameDelay) {
    delay = kDefaultFrameDelay;
  }
  return delay;
}

- (NSTimeInterval)durationAtIndex:(NSUInteger)index
{
  if (index >= _durations.count)
    return kDefaultFrameDelay;
  return _durations[index].doubleValue;
}

- (void)decodeFrameAtIndex:(NSUInteger)index
              maxPixelSize:(CGFloat)maxPixelSize
                completion:(void (^)(RCTUIImage *_Nullable))completion
{
  dispatch_async(_decodeQueue, ^{ completion([self frameAtIndex:index maxPixelSize:maxPixelSize]); });
}

// Must run on _decodeQueue: CGImageSource is not safe to use from two threads.
- (RCTUIImage *)frameAtIndex:(NSUInteger)index maxPixelSize:(CGFloat)maxPixelSize
{
  if (index >= _frameCount)
    return nil;

  NSMutableDictionary *options = [NSMutableDictionary dictionary];
  options[(__bridge NSString *)kCGImageSourceShouldCacheImmediately] = @YES;
  CGImageRef frame = NULL;
  if (maxPixelSize > 0) {
    options[(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways] = @YES;
    options[(__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform] = @YES;
    options[(__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize] = @(ceil(maxPixelSize));
    frame = CGImageSourceCreateThumbnailAtIndex(_source, index, (__bridge CFDictionaryRef)options);
  }
  if (!frame) {
    frame = CGImageSourceCreateImageAtIndex(_source, index, (__bridge CFDictionaryRef)options);
  }
  if (!frame)
    return nil;

  RCTUIImage *image = ENRMImageFromCGImage(frame);
  CGImageRelease(frame);
  return image;
}

@end
