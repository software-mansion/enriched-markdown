#pragma once
#import "ENRMUIKit.h"
#import <ImageIO/ImageIO.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A multi-frame GIF decoded lazily through ImageIO: only the encoded bytes and
 * frame delays are held, frames are decoded (and downsampled) on demand.
 *
 * Instances are shared between attachments. CGImageSource is not thread-safe,
 * so every decode goes through the instance's own serial queue.
 */
@interface ENRMAnimatedImage : NSObject

/// Returns nil unless `data` is a GIF with more than one frame.
+ (nullable instancetype)animatedImageWithData:(NSData *)data;

/// YES when `data` starts with a GIF signature (GIF87a / GIF89a).
+ (BOOL)isGIFData:(NSData *)data;

@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) NSUInteger frameCount;
/// Full-size first frame, used as the poster image and for intrinsic sizing.
@property (nonatomic, readonly) RCTUIImage *firstFrame;
/// Sum of all frame delays, in seconds.
@property (nonatomic, readonly) NSTimeInterval totalDuration;
/// Frame most recently shown by any attachment playing this GIF. A fresh
/// attachment (new render, or a second copy on screen) resumes from here so
/// re-renders don't restart playback and copies stay roughly in sync. Main
/// thread only.
@property (nonatomic, assign) NSUInteger lastDisplayedFrameIndex;

/// Delay (seconds) the frame at `index` stays on screen. Delays at or below
/// 10ms are treated as 100ms, as browsers do.
- (NSTimeInterval)durationAtIndex:(NSUInteger)index;

/// Decodes frame `index` on the decode queue, downsampled so its larger side is
/// at most `maxPixelSize` pixels (0 = full size). `completion` runs on that same
/// queue with the frame, or nil on failure.
- (void)decodeFrameAtIndex:(NSUInteger)index
              maxPixelSize:(CGFloat)maxPixelSize
                completion:(void (^)(RCTUIImage *_Nullable frame))completion;

@end

NS_ASSUME_NONNULL_END
