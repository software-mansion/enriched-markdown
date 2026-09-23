#pragma once
#import "ENRMUIKit.h"

@class ENRMAnimatedImage;
@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * Adopted by component views that host markdown text. Notified when a block
 * image resolves its box height after loading (maxHeight/aspectRatio sizing),
 * so the view can drop stale cached measurements and request a height update.
 */
@protocol ENRMImageLayoutObserver
- (void)imageAttachmentDidResolveLayout;
@end

@interface RCTUIView (ENRMImageLayoutObserver)
/**
 * Nearest ancestor (self included) adopting ENRMImageLayoutObserver, walking up
 * the superview chain. Returns nil when none is found.
 */
- (nullable id<ENRMImageLayoutObserver>)enrm_imageLayoutObserver;
@end

/**
 * Custom NSTextAttachment for rendering markdown images.
 * Images are loaded asynchronously and scaled dynamically based on text container width.
 * Supports inline and block images with custom height and border radius from config.
 *
 * Multi-frame block GIFs animate in place on iOS: frames are decoded lazily off
 * the main thread and swapped in on a per-frame timer that redraws only the
 * attachment's glyph range. Inline images and macOS show the first frame.
 */
@interface ENRMImageAttachment : NSTextAttachment

@property (nonatomic, readonly) NSString *imageURL;
@property (nonatomic, readonly) BOOL isInline;

/**
 * Invoked on the main thread whenever the image finishes loading/processing.
 * Used by self-drawing hosts (e.g. a table grid) that rasterize the attributed
 * string via -drawWithRect: and therefore never get a live text view for the
 * attachment's normal -refreshDisplay invalidation to reach. Such hosts set this
 * to trigger their own redraw (e.g. -setNeedsDisplay).
 */
@property (nonatomic, copy, nullable) void (^onImageLoaded)(void);

+ (instancetype)attachmentForURL:(NSString *)imageURL config:(StyleConfig *)config isInline:(BOOL)isInline;

+ (NSCache<NSString *, RCTUIImage *> *)originalImageCache;
+ (NSCache<NSString *, RCTUIImage *> *)processedImageCache;
+ (NSCache<NSString *, ENRMAnimatedImage *> *)animatedImageCache;

@end

NS_ASSUME_NONNULL_END
