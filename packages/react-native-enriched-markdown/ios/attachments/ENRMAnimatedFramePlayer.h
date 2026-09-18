#pragma once
#import "ENRMUIKit.h"

@class ENRMAnimatedImage;
@class ENRMAnimatedFramePlayer;

NS_ASSUME_NONNULL_BEGIN

/// The box a GIF's frames are decoded and scaled for.
typedef struct {
  CGFloat targetWidth;
  CGFloat boxHeight;
  /// Largest side, in pixels, a decoded frame needs; ImageIO downsamples to it.
  CGFloat maxPixelSize;
} ENRMFrameGeometry;

@protocol ENRMAnimatedFramePlayerDelegate <NSObject>

/// Called on the GIF's decode queue: scale and clip a raw frame for `geometry`.
- (nullable RCTUIImage *)framePlayer:(ENRMAnimatedFramePlayer *)player
                        processFrame:(RCTUIImage *)raw
                            geometry:(ENRMFrameGeometry)geometry;

/// Called on the main thread with the next frame to display.
- (void)framePlayer:(ENRMAnimatedFramePlayer *)player showFrame:(RCTUIImage *)frame;

/// Redraw the attachment in `host`. Return NO when `host` no longer contains
/// it, so the player forgets that host.
- (BOOL)framePlayer:(ENRMAnimatedFramePlayer *)player redrawInHost:(ENRMPlatformTextView *)host;

@end

/**
 * Drives playback of one ENRMAnimatedImage for one text attachment.
 *
 * Lifecycle:
 *  1. -resetForKey:geometry: whenever the attachment's box changes; drops any
 *     frames decoded for the old box. The poster (frame 0) is shown until
 *     playback resumes from the shared playhead.
 *  2. -addHost: and -startIfNeeded from the attachment's draw callback; the
 *     loop only runs while at least one host is on window.
 *  3. The loop pauses itself when every host is off window or nothing more
 *     decodes, releasing its frame cache; the next draw restarts it.
 *
 * Frames are decoded a couple ahead on the GIF's own queue, processed by the
 * delegate, and swapped in on a deadline-based timer so playback does not
 * drift. The playhead lives on the shared ENRMAnimatedImage, so a re-render
 * (new attachment) or a second copy on screen continues from the same frame.
 *
 * Main-thread only. Playback is disabled on macOS, where NSLayoutManager never
 * asks the attachment for an image per draw, and under Reduce Motion.
 */
@interface ENRMAnimatedFramePlayer : NSObject

- (instancetype)initWithAnimatedImage:(ENRMAnimatedImage *)animatedImage
                             delegate:(id<ENRMAnimatedFramePlayerDelegate>)delegate;

@property (nonatomic, readonly) ENRMAnimatedImage *animatedImage;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
/// Index of the frame currently shown; 0 right after a reset.
@property (nonatomic, readonly) NSUInteger currentFrameIndex;

- (void)resetForKey:(NSString *)key geometry:(ENRMFrameGeometry)geometry;
- (void)addHost:(ENRMPlatformTextView *)host;
- (void)startIfNeeded;
- (void)pause;

@end

NS_ASSUME_NONNULL_END
