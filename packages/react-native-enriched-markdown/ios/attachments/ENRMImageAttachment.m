#import "ENRMImageAttachment.h"
#import "ENRMImageDownloader.h"
#import "ENRMImageFailurePlaceholder.h"
#import "ENRMUIKit.h"
#import "RuntimeKeys.h"
#import "StyleConfig.h"
#import <objc/runtime.h>

#define CACHE_KEY_PROCESSED(url, w, h, r, m) [NSString stringWithFormat:@"%@_w%.1f_h%.1f_r%.1f_m%@", url, w, h, r, m]

static NSString *const kInlineDrawingMode = @"contain";

static NSCache<NSString *, RCTUIImage *> *_originalImageCache;
static NSCache<NSString *, RCTUIImage *> *_processedImageCache;
static NSCache<NSString *, NSNumber *> *_failedImageKeys;

@implementation RCTPlatformView (ENRMImageLayoutObserver)

- (id<ENRMImageLayoutObserver>)enrm_imageLayoutObserver
{
  RCTPlatformView *view = self;
  while (view && ![view conformsToProtocol:@protocol(ENRMImageLayoutObserver)]) {
    view = view.superview;
  }
  return (id<ENRMImageLayoutObserver>)view;
}

@end

@interface ENRMImageAttachment ()

@property (nonatomic, copy) NSString *imageURL;
@property (nonatomic, copy) NSString *requestURL;
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
@property (nonatomic, assign) BOOL loadFailed;
@property (nonatomic, strong) ENRMImageFailurePlaceholder *failurePlaceholder;
@property (nonatomic, strong) RCTUIImage *failureImage;

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

// Measurement builds its own attachments, so the requests that failed have to be readable
// by a new instance: without this it would size an inline image as the square it never drew.
+ (NSCache<NSString *, NSNumber *> *)failedImageKeys
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _failedImageKeys = [[NSCache alloc] init];
    _failedImageKeys.countLimit = 200;
  });
  return _failedImageKeys;
}

+ (instancetype)attachmentForURL:(NSString *)imageURL config:(StyleConfig *)config isInline:(BOOL)isInline
{
  return [self attachmentForURL:imageURL source:nil altText:@"" config:config isInline:isInline];
}

+ (instancetype)attachmentForURL:(NSString *)imageURL
                          source:(ENRMImageSourceOverride *)source
                         altText:(NSString *)altText
                          config:(StyleConfig *)config
                        isInline:(BOOL)isInline
{
  // Always a fresh instance, never shared across positions: the table renderer can draw
  // the same image URL at a different width than a copy outside the table, and a shared
  // NSTextAttachment would thrash its single last-processed width into a redraw loop. The
  // image caches keep fresh instances cheap (no re-fetch or re-scale).
  return [[self alloc] initWithImageURL:imageURL source:source altText:altText config:config isInline:isInline];
}

- (instancetype)initWithImageURL:(NSString *)imageURL
                          source:(ENRMImageSourceOverride *)source
                         altText:(NSString *)altText
                          config:(StyleConfig *)config
                        isInline:(BOOL)isInline
{
  self = [super init];
  if (self) {
    _imageURL = imageURL;
    _requestURL = source ? ([source.uri copy] ?: @"") : imageURL;
    _requestHeaders = ENRMMergeImageRequestHeaders([config imageRequestHeaders], source.headers);
    _cacheKey = ENRMImageCacheKey(_requestURL, _requestHeaders);
    _isInline = isInline;

    _cachedHeight = isInline ? [config scaledInlineImageSize] : [config imageHeight];
    _cachedMaxHeight = [config imageMaxHeight];
    _cachedAspectRatio = [config imageAspectRatio];
    _cachedResizeMode = [config imageResizeMode];
    CGFloat inlineImageSize = [config inlineImageSize];
    CGFloat inlineScale = isInline && inlineImageSize > 0 ? _cachedHeight / inlineImageSize : 1.0;
    _cachedBorderRadius = [config imageBorderRadius] * inlineScale;

    // The resolved font, so the alt text grows with the user's text size like the paragraph does.
    _failurePlaceholder = [[ENRMImageFailurePlaceholder alloc] initWithAltText:altText
                                                                         color:[config paragraphColor]
                                                                      fontSize:[config paragraphFont].pointSize
                                                                  borderRadius:_cachedBorderRadius];
    _loadFailed = [[ENRMImageAttachment failedImageKeys] objectForKey:_cacheKey] != nil;

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

// TextKit proposes the line's full width and applies the paragraph's indents afterwards, so
// a box as wide as the proposal runs past the right edge of an indented list item.
- (CGFloat)availableWidthInLineFragment:(CGRect)lineFragment
                          textContainer:(NSTextContainer *)textContainer
                         characterIndex:(NSUInteger)characterIndex
{
  NSTextStorage *textStorage = textContainer.layoutManager.textStorage;
  NSParagraphStyle *paragraph = characterIndex < textStorage.length
                                    ? [textStorage attribute:NSParagraphStyleAttributeName
                                                     atIndex:characterIndex
                                              effectiveRange:NULL]
                                    : nil;
  CGFloat indent = MAX(paragraph.firstLineHeadIndent, paragraph.headIndent);
  CGFloat tailInset = paragraph.tailIndent < 0 ? -paragraph.tailIndent : 0;
  return MAX(0, lineFragment.size.width - indent - tailInset);
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFragment
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)characterIndex
{
  CGFloat height = self.cachedHeight;
  CGFloat available = [self availableWidthInLineFragment:lineFragment
                                           textContainer:textContainer
                                          characterIndex:characterIndex];
  CGFloat width = self.isInline ? height : (available > 0 ? available : height);
  if (self.isInline && self.loadFailed) {
    width = [self.failurePlaceholder chipWidthForHeight:height maxWidth:available];
  }

  if (!self.isInline) {
    height = [self resolvedBoxHeightForWidth:width];
    return CGRectMake(0, 0, width, height);
  }

  CGFloat verticalOffset;
  if (self.textFont) {
    verticalOffset = (self.textFont.capHeight - height) / 2.0;
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

  if (self.loadFailed) {
    return [self failureImageForSize:imageBounds.size] ?: self.placeholderImage;
  }

  if (self.originalImage && imageBounds.size.width > 0) {
    self.bounds = imageBounds;
    [self processAndApplyImage:self.originalImage withTargetWidth:imageBounds.size.width];
  }

  return self.loadedImage ?: self.placeholderImage;
}

- (RCTUIImage *)failureImageForSize:(CGSize)size
{
  if (size.width <= 0 || size.height <= 0)
    return nil;
  if (!CGSizeEqualToSize(self.failureImage.size, size)) {
    self.failureImage = [self.failurePlaceholder imageForSize:size isInline:self.isInline];
  }
  return self.failureImage;
}

- (void)handleLoadFailure
{
  [[ENRMImageAttachment failedImageKeys] setObject:@YES forKey:self.cacheKey];
  if (self.loadFailed)
    return;
  self.loadFailed = YES;
  [self refreshDisplayAfterInlineSizeChange:self.isInline];
}

- (void)handleLoadedImage:(RCTUIImage *)image
{
  // The downloader completes synchronously on cache hits, which can happen on the render queue
  if (!NSThread.isMainThread) {
    dispatch_async(dispatch_get_main_queue(), ^{ [self handleLoadedImage:image]; });
    return;
  }

  if (!image) {
    [self handleLoadFailure];
    return;
  }

  [[ENRMImageAttachment failedImageKeys] removeObjectForKey:self.cacheKey];
  if (self.loadFailed) {
    self.loadFailed = NO;
    self.failureImage = nil;
    [self refreshDisplayAfterInlineSizeChange:self.isInline];
  }

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

  NSString *drawingMode = self.isInline ? @"inline" : self.cachedResizeMode;
  NSString *processedKey =
      CACHE_KEY_PROCESSED(self.cacheKey, targetWidth, boxHeight, self.cachedBorderRadius, drawingMode);

  if ([processedKey isEqualToString:self.lastProcessedKey])
    return;
  self.lastProcessedKey = processedKey;

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
  BOOL legacy = [self isLegacyBlockSizing];

  CGRect drawingRect;
  if (self.isInline) {
    drawingRect = [self drawingRectForResizeMode:kInlineDrawingMode source:source box:box];
  } else if (legacy) {
    CGFloat drawingHeight = sourceHeight * (targetWidth / sourceWidth);
    drawingRect = CGRectMake(0, (targetHeight - drawingHeight) / 2.0, targetWidth, drawingHeight);
  } else {
    drawingRect = [self drawingRectForResizeMode:self.cachedResizeMode source:source box:box];
  }

  RCTUIGraphicsImageRenderer *renderer = ImageRendererForSize(box);

  return [renderer imageWithActions:^(RCTUIGraphicsImageRendererContext *context) {
    if (radius > 0) {
      CGRect clipRect = CGRectIntersection(CGRectMake(0, 0, targetWidth, targetHeight), drawingRect);
      if (self.isInline) {
        CGFloat cornerRadius = MIN(radius, MIN(clipRect.size.width, clipRect.size.height) / 2.0);
        CGPathRef path = CGPathCreateWithRoundedRect(clipRect, cornerRadius, cornerRadius, NULL);
        CGContextAddPath(context.CGContext, path);
        CGContextClip(context.CGContext);
        CGPathRelease(path);
      } else {
        UIBezierPath *path = UIBezierPathWithRoundedRect(clipRect, radius);
        [path addClip];
      }
    }
    [image drawInRect:drawingRect];
  }];
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
  // An overridden source with an empty uri keeps the placeholder on purpose.
  if (self.requestURL.length == 0)
    return;

  __weak typeof(self) weakSelf = self;
  [[ENRMImageDownloader shared] downloadURL:self.requestURL
                                    headers:self.requestHeaders
                                 completion:^(RCTUIImage *image) { [weakSelf handleLoadedImage:image]; }];
}

- (void)refreshDisplay
{
  [self refreshDisplayAfterInlineSizeChange:NO];
}

// An inline image only changes width when it turns into a failure chip or back from one.
- (void)refreshDisplayAfterInlineSizeChange:(BOOL)inlineSizeChanged
{
  // Notify self-drawing hosts (e.g. a table grid) that rasterize us via
  // -drawWithRect: and have no live text view for the invalidation below to reach.
  if (self.onImageLoaded) {
    self.onImageLoaded();
  }

  ENRMPlatformTextView *textView = [self fetchAssociatedTextView];
  if (!textView)
    return;

  NSRange range = [self findAttachmentRangeInText:textView.textStorage];
  if (range.location != NSNotFound) {
    [textView.layoutManager invalidateDisplayForCharacterRange:range];
    if (!self.isInline || inlineSizeChanged) {
      [textView.layoutManager invalidateLayoutForCharacterRange:range actualCharacterRange:NULL];
    }
    if (inlineSizeChanged) {
      [self postImageLayoutResolved:textView];
    } else if (!self.isInline) {
      [self notifyImageLayoutObserver:textView];
    }
  }
}

// With maxHeight/aspectRatio sizing the box height can settle after the image
// loads, while the component was measured (and its size cached) with the
// pre-load fallback. Notify the hosting component so it can re-measure.
// Dispatched async: refreshDisplay can run mid-layout (imageForBounds) and
// re-measuring would re-enter the layout manager.
- (void)notifyImageLayoutObserver:(ENRMPlatformTextView *)textView
{
  // Only maxHeight/aspectRatio boxes can change height after load; a fixed
  // height box (legacy or explicit resizeMode) never needs a re-measure.
  if (self.cachedMaxHeight <= 0 && self.cachedAspectRatio <= 0)
    return;

  [self postImageLayoutResolved:textView];
}

- (void)postImageLayoutResolved:(ENRMPlatformTextView *)textView
{
  id<ENRMImageLayoutObserver> observer = [textView enrm_imageLayoutObserver];
  if (!observer)
    return;

  dispatch_async(dispatch_get_main_queue(), ^{ [observer imageAttachmentDidResolveLayout]; });
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

void ENRMImageAttachmentsAdoptTextFonts(NSAttributedString *text)
{
  [text enumerateAttribute:NSAttachmentAttributeName
                   inRange:NSMakeRange(0, text.length)
                   options:0
                usingBlock:^(id value, NSRange range, __unused BOOL *stop) {
                  if (![value isKindOfClass:[ENRMImageAttachment class]] || !((ENRMImageAttachment *)value).isInline) {
                    return;
                  }
                  UIFont *font = [text attribute:NSFontAttributeName atIndex:range.location effectiveRange:NULL];
                  if (font) {
                    ((ENRMImageAttachment *)value).textFont = font;
                  }
                }];
}
