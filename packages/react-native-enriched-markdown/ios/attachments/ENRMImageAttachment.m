#import "ENRMImageAttachment.h"
#import "ENRMAnimatedFramePlayer.h"
#import "ENRMAnimatedImage.h"
#import "ENRMImageDownloader.h"
#import "ENRMUIKit.h"
#import "RuntimeKeys.h"
#import "StyleConfig.h"
#import <objc/runtime.h>

#define CACHE_KEY_PROCESSED(url, w, h, r, m) [NSString stringWithFormat:@"%@_w%.1f_h%.1f_r%.1f_m%@", url, w, h, r, m]

static inline NSUInteger ENRMImageByteCost(RCTUIImage *image)
{
  CGImageRef cgImage = image.CGImage;
  if (!cgImage)
    return 0;
  return CGImageGetBytesPerRow(cgImage) * CGImageGetHeight(cgImage);
}

static NSCache<NSString *, RCTUIImage *> *_originalImageCache;
static NSCache<NSString *, RCTUIImage *> *_processedImageCache;
static NSCache<NSString *, ENRMAnimatedImage *> *_animatedImageCache;

@implementation RCTUIView (ENRMImageLayoutObserver)

- (id<ENRMImageLayoutObserver>)enrm_imageLayoutObserver
{
  RCTUIView *view = self;
  while (view && ![view conformsToProtocol:@protocol(ENRMImageLayoutObserver)]) {
    view = view.superview;
  }
  return (id<ENRMImageLayoutObserver>)view;
}

@end

static inline CGFloat ENRMDisplayScale(void)
{
#if !TARGET_OS_OSX
  return [UIScreen mainScreen].scale;
#else
  return [NSScreen mainScreen].backingScaleFactor ?: 1.0;
#endif
}

@interface ENRMImageAttachment () <ENRMAnimatedFramePlayerDelegate>

@property (nonatomic, copy) NSString *imageURL;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *requestHeaders;
@property (nonatomic, copy) NSString *cacheKey;
@property (nonatomic, assign) BOOL isInline;
@property (nonatomic, assign) CGFloat cachedHeight;
@property (nonatomic, assign) CGFloat cachedMaxHeight;
@property (nonatomic, assign) CGFloat cachedAspectRatio;
@property (nonatomic, copy) NSString *cachedResizeMode;
@property (nonatomic, assign) CGFloat cachedBorderRadius;
@property (nonatomic, weak) NSTextContainer *textContainer;
@property (nonatomic, weak) ENRMPlatformTextView *textView;
@property (nonatomic, strong) RCTUIImage *originalImage;
@property (nonatomic, strong) RCTUIImage *loadedImage;
@property (nonatomic, strong) RCTUIImage *placeholderImage;
@property (nonatomic, copy) NSString *lastProcessedKey;

// Set only for multi-frame block GIFs; the player owns all playback state.
@property (nonatomic, strong, nullable) ENRMAnimatedImage *animatedImage;
@property (nonatomic, strong, nullable) ENRMAnimatedFramePlayer *framePlayer;

@end

@implementation ENRMImageAttachment

+ (NSCache<NSString *, RCTUIImage *> *)originalImageCache
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _originalImageCache = [[NSCache alloc] init];
    _originalImageCache.countLimit = 50;
    _originalImageCache.totalCostLimit = 1024 * 1024 * 20; // 20 MB
  });
  return _originalImageCache;
}

+ (NSCache<NSString *, RCTUIImage *> *)processedImageCache
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _processedImageCache = [[NSCache alloc] init];
    _processedImageCache.countLimit = 100;
    _processedImageCache.totalCostLimit = 1024 * 1024 * 30; // 30 MB
  });
  return _processedImageCache;
}

+ (NSCache<NSString *, ENRMAnimatedImage *> *)animatedImageCache
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _animatedImageCache = [[NSCache alloc] init];
    _animatedImageCache.countLimit = 20;
    _animatedImageCache.totalCostLimit = 1024 * 1024 * 20; // 20 MB, costed as GIF bytes + poster frame
  });
  return _animatedImageCache;
}

+ (instancetype)attachmentForURL:(NSString *)imageURL config:(StyleConfig *)config isInline:(BOOL)isInline
{
  // Always a fresh instance, never shared across positions: the table renderer can draw
  // the same image URL at a different width than a copy outside the table, and a shared
  // NSTextAttachment would thrash its single last-processed width into a redraw loop. The
  // image caches keep fresh instances cheap (no re-fetch or re-scale), and an animated
  // GIF keeps its playhead on the shared ENRMAnimatedImage so playback continues.
  return [[self alloc] initWithImageURL:imageURL config:config isInline:isInline];
}

- (instancetype)initWithImageURL:(NSString *)imageURL config:(StyleConfig *)config isInline:(BOOL)isInline
{
  self = [super init];
  if (self) {
    _imageURL = imageURL;
    _requestHeaders = [[config imageRequestHeaders] copy];
    _cacheKey = ENRMImageCacheKey(imageURL, _requestHeaders);
    _isInline = isInline;

    _cachedHeight = isInline ? [config inlineImageSize] : [config imageHeight];
    _cachedMaxHeight = [config imageMaxHeight];
    _cachedAspectRatio = [config imageAspectRatio];
    _cachedResizeMode = [config imageResizeMode];
    _cachedBorderRadius = [config imageBorderRadius];

    [self setupPlaceholder];
    [self startDownloadingImage];
  }
  return self;
}

- (CGFloat)resolvedBoxHeightForWidth:(CGFloat)width
{
  if (self.cachedAspectRatio > 0 && width > 0) {
    return width / self.cachedAspectRatio;
  }

  if (self.cachedMaxHeight > 0) {
    RCTUIImage *source = self.originalImage;
    if (source && width > 0 && source.size.width > 0 && source.size.height > 0) {
      CGFloat fitted = width * source.size.height / source.size.width;
      return MIN(self.cachedMaxHeight, fitted);
    }
    // Intrinsic size not known yet — fall back to the full max height; the box
    // shrinks once the image loads and layout is invalidated.
    return self.cachedMaxHeight;
  }

  return self.cachedHeight;
}

// True when resizeMode is unset ('') - legacy always implies a fixed height box.

- (BOOL)isLegacyBlockSizing
{
  return !self.isInline && self.cachedResizeMode.length == 0;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFragment
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)characterIndex
{
  CGFloat height = self.cachedHeight;
  CGFloat width = self.isInline ? height : (lineFragment.size.width > 0 ? lineFragment.size.width : height);

  if (!self.isInline) {
    height = [self resolvedBoxHeightForWidth:width];
    return CGRectMake(0, 0, width, height);
  }

  UIFont *appliedFont = nil;
  NSLayoutManager *layoutManager = textContainer.layoutManager;
  NSTextStorage *textStorage = layoutManager.textStorage;

  if (textStorage && characterIndex < textStorage.length) {
    appliedFont = [textStorage attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
  }

  CGFloat verticalOffset;
  if (appliedFont) {
    verticalOffset = (appliedFont.capHeight - height) / 2.0;
  } else {
    verticalOffset = (lineFragment.size.height - height) / 2.0;
  }

  return CGRectMake(0, verticalOffset, width, height);
}

- (RCTUIImage *)imageForBounds:(CGRect)imageBounds
                 textContainer:(NSTextContainer *)textContainer
                characterIndex:(NSUInteger)characterIndex
{
  self.textContainer = textContainer;

  if (self.originalImage && imageBounds.size.width > 0) {
    self.bounds = imageBounds;
    [self processAndApplyImage:self.originalImage withTargetWidth:imageBounds.size.width];
  }

  if (self.framePlayer) {
    // Only the real draw path reaches here (view-free measurement stops at
    // layout): remember the host and restart a loop paused while off-window.
    ENRMPlatformTextView *host = objc_getAssociatedObject(textContainer, kTextViewKey);
    if (host) {
      [self.framePlayer addHost:host];
    }
    [self.framePlayer startIfNeeded];
  }

  return self.loadedImage ?: self.placeholderImage;
}

- (void)handleLoadedImage:(RCTUIImage *)image animated:(nullable ENRMAnimatedImage *)animated
{
  if (!image)
    return;

  // The downloader completes synchronously on cache hits, which can happen on the render queue
  if (!NSThread.isMainThread) {
    dispatch_async(dispatch_get_main_queue(), ^{ [self handleLoadedImage:image animated:animated]; });
    return;
  }

  // Inline images stay still (matches Android).
  self.animatedImage = self.isInline ? nil : animated;
  self.framePlayer = self.animatedImage
                         ? [[ENRMAnimatedFramePlayer alloc] initWithAnimatedImage:self.animatedImage delegate:self]
                         : nil;
  self.originalImage = image;
  // UIKit reads the plain image property for save/drag/copy — it must hold the original
  self.image = image;
  CGFloat targetWidth = self.isInline ? self.cachedHeight : self.bounds.size.width;

  // Defer processing if we don't have valid bounds yet (common for non-inline block images)
  if (!self.isInline && targetWidth <= 0) {
    return;
  }

  [self processAndApplyImage:image withTargetWidth:targetWidth];
}

- (void)processAndApplyImage:(RCTUIImage *)image withTargetWidth:(CGFloat)targetWidth
{
  if (targetWidth <= 0)
    return;

  CGFloat boxHeight = self.isInline ? self.cachedHeight : [self resolvedBoxHeightForWidth:targetWidth];

  NSString *processedKey =
      CACHE_KEY_PROCESSED(self.cacheKey, targetWidth, boxHeight, self.cachedBorderRadius, self.cachedResizeMode);

  if ([processedKey isEqualToString:self.lastProcessedKey])
    return;
  self.lastProcessedKey = processedKey;
  [self.framePlayer resetForKey:processedKey geometry:[self frameGeometryForWidth:targetWidth boxHeight:boxHeight]];

  RCTUIImage *cachedProcessed = [[ENRMImageAttachment processedImageCache] objectForKey:processedKey];

  if (cachedProcessed) {
    self.loadedImage = cachedProcessed;
    [self refreshDisplay];
    return;
  }

  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf)
      return;

    RCTUIImage *processedImage = [strongSelf createScaledImage:image
                                                       toWidth:targetWidth
                                                        height:boxHeight
                                                  borderRadius:strongSelf.cachedBorderRadius];

    if (processedImage) {
      [[ENRMImageAttachment processedImageCache] setObject:processedImage
                                                    forKey:processedKey
                                                      cost:ENRMImageByteCost(processedImage)];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      // Don't clobber a newer size, or a running animation, with a stale poster.
      if (![processedKey isEqualToString:strongSelf.lastProcessedKey])
        return;
      if (strongSelf.framePlayer.playing && strongSelf.framePlayer.currentFrameIndex != 0)
        return;
      strongSelf.loadedImage = processedImage;
      if (strongSelf.isInline) {
        strongSelf.bounds = CGRectMake(0, 0, strongSelf.cachedHeight, strongSelf.cachedHeight);
      }
      [strongSelf refreshDisplay];
    });
  });
}

- (RCTUIImage *)createScaledImage:(RCTUIImage *)image
                          toWidth:(CGFloat)targetWidth
                           height:(CGFloat)targetHeight
                     borderRadius:(CGFloat)radius
{
  CGFloat sourceWidth = image.size.width;
  CGFloat sourceHeight = image.size.height;
  if (sourceWidth <= 0 || sourceHeight <= 0)
    return nil;

  CGSize source = CGSizeMake(sourceWidth, sourceHeight);
  CGSize box = CGSizeMake(targetWidth, targetHeight);
  CGRect drawingRect = [self drawingRectForSource:source box:box];

  RCTUIGraphicsImageRenderer *renderer = ImageRendererForSize(box);

  return [renderer imageWithActions:^(RCTUIGraphicsImageRendererContext *context) {
    if (radius > 0) {
      CGRect clipRect = CGRectIntersection(CGRectMake(0, 0, targetWidth, targetHeight), drawingRect);
      UIBezierPath *path = UIBezierPathWithRoundedRect(clipRect, radius);
      [path addClip];
    }
    [image drawInRect:drawingRect];
  }];
}

// Where a source of the given size lands inside the box. Depends only on the
// aspect ratio of `source`, except 'center' and 'none' which draw at 1:1.
- (CGRect)drawingRectForSource:(CGSize)source box:(CGSize)box
{
  if (self.isInline || [self isLegacyBlockSizing]) {
    CGFloat drawingWidth, drawingHeight;
    if (!self.isInline) {
      CGFloat aspectRatioScale = box.width / source.width;
      drawingWidth = box.width;
      drawingHeight = source.height * aspectRatioScale;
    } else {
      drawingWidth = box.width;
      drawingHeight = box.height;
    }
    return CGRectMake((box.width - drawingWidth) / 2.0, (box.height - drawingHeight) / 2.0, drawingWidth,
                      drawingHeight);
  }
  return [self drawingRectForResizeMode:self.cachedResizeMode source:source box:box];
}

- (CGRect)drawingRectForResizeMode:(NSString *)mode source:(CGSize)source box:(CGSize)box
{
  if ([mode isEqualToString:@"stretch"]) {
    return CGRectMake(0, 0, box.width, box.height);
  }

  CGFloat widthScale = box.width / source.width;
  CGFloat heightScale = box.height / source.height;

  CGFloat scale;
  if ([mode isEqualToString:@"contain"]) {
    scale = MIN(widthScale, heightScale);
  } else if ([mode isEqualToString:@"center"]) {
    scale = MIN(1.0, MIN(widthScale, heightScale));
  } else if ([mode isEqualToString:@"none"]) {
    scale = 1.0;
  } else { // cover (default)
    scale = MAX(widthScale, heightScale);
  }

  CGFloat drawingWidth = source.width * scale;
  CGFloat drawingHeight = source.height * scale;
  return CGRectMake((box.width - drawingWidth) / 2.0, (box.height - drawingHeight) / 2.0, drawingWidth, drawingHeight);
}

- (void)startDownloadingImage
{
  if (self.imageURL.length == 0)
    return;

  __weak typeof(self) weakSelf = self;
  [[ENRMImageDownloader shared] downloadURL:self.imageURL
                                    headers:self.requestHeaders
                                 completion:^(RCTUIImage *image, ENRMAnimatedImage *animated) {
                                   [weakSelf handleLoadedImage:image animated:animated];
                                 }];
}

- (void)refreshDisplay
{
  // Notify self-drawing hosts (e.g. a table grid) that rasterize us via
  // -drawWithRect: and have no live text view for the invalidation below to reach.
  if (self.onImageLoaded) {
    self.onImageLoaded();
  }

  UITextView *textView = [self fetchAssociatedTextView];
  if (!textView)
    return;

  NSRange range = [self findAttachmentRangeInText:textView.textStorage];
  if (range.location != NSNotFound) {
    [textView.layoutManager invalidateDisplayForCharacterRange:range];
    if (!self.isInline) {
      [textView.layoutManager invalidateLayoutForCharacterRange:range actualCharacterRange:NULL];
      [self notifyImageLayoutObserver:textView];
    }
  }
}

// With maxHeight/aspectRatio sizing the box height can settle after the image
// loads, while the component was measured (and its size cached) with the
// pre-load fallback. Notify the hosting component so it can re-measure.
// Dispatched async: refreshDisplay can run mid-layout (imageForBounds) and
// re-measuring would re-enter the layout manager.
- (void)notifyImageLayoutObserver:(UITextView *)textView
{
  // Only maxHeight/aspectRatio boxes can change height after load; a fixed
  // height box (legacy or explicit resizeMode) never needs a re-measure.
  if (self.cachedMaxHeight <= 0 && self.cachedAspectRatio <= 0)
    return;

  id<ENRMImageLayoutObserver> observer = [textView enrm_imageLayoutObserver];
  if (!observer)
    return;

  dispatch_async(dispatch_get_main_queue(), ^{ [observer imageAttachmentDidResolveLayout]; });
}

#pragma mark - GIF animation

// Frames are decoded just large enough for the rect they are drawn into; for
// 'center' and 'none' that rect is the intrinsic size, so they stay 1:1.
- (ENRMFrameGeometry)frameGeometryForWidth:(CGFloat)targetWidth boxHeight:(CGFloat)boxHeight
{
  CGRect drawingRect = [self drawingRectForSource:self.originalImage.size box:CGSizeMake(targetWidth, boxHeight)];
  ENRMFrameGeometry geometry;
  geometry.targetWidth = targetWidth;
  geometry.boxHeight = boxHeight;
  geometry.maxPixelSize = MAX(drawingRect.size.width, drawingRect.size.height) * ENRMDisplayScale();
  return geometry;
}

- (RCTUIImage *)framePlayer:(ENRMAnimatedFramePlayer *)player
               processFrame:(RCTUIImage *)raw
                   geometry:(ENRMFrameGeometry)geometry
{
  return [self createScaledImage:raw
                         toWidth:geometry.targetWidth
                          height:geometry.boxHeight
                    borderRadius:self.cachedBorderRadius];
}

- (void)framePlayer:(ENRMAnimatedFramePlayer *)player showFrame:(RCTUIImage *)frame
{
  self.loadedImage = frame;
}

// Display-only invalidation: a frame swap never changes the box size.
- (BOOL)framePlayer:(ENRMAnimatedFramePlayer *)player redrawInHost:(ENRMPlatformTextView *)host
{
  NSRange range = [self findAttachmentRangeInText:host.textStorage];
  if (range.location == NSNotFound)
    return NO;
  [host.layoutManager invalidateDisplayForCharacterRange:range];
  return YES;
}

- (ENRMPlatformTextView *)fetchAssociatedTextView
{
  if (self.textView)
    return self.textView;
  if (!self.textContainer)
    return nil;
  self.textView = objc_getAssociatedObject(self.textContainer, kTextViewKey);
  return self.textView;
}

- (void)setupPlaceholder
{
  CGFloat size = self.cachedHeight;
  self.bounds = CGRectMake(0, 0, size, size);
  RCTUIGraphicsImageRenderer *renderer = [[RCTUIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(1, 1)];
  self.placeholderImage = [renderer imageWithActions:^(RCTUIGraphicsImageRendererContext *ctx){}];
}

- (NSRange)findAttachmentRangeInText:(NSAttributedString *)attributedString
{
  __block NSRange foundRange = NSMakeRange(NSNotFound, 0);
  [attributedString enumerateAttribute:NSAttachmentAttributeName
                               inRange:NSMakeRange(0, attributedString.length)
                               options:0
                            usingBlock:^(id value, NSRange range, BOOL *stop) {
                              if (value == self) {
                                foundRange = range;
                                *stop = YES;
                              }
                            }];
  return foundRange;
}

@end
