#import "../../ios/EnrichedMarkdown.h"
#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import "../../ios/views/EnrichedMarkdownInternalText.h"
#import <XCTest/XCTest.h>

// A text in a scroll view draws only near the screen (ENRMTextTiles); a capture of it still gets all
// of it. The captures run in the app's window: drawViewHierarchyInRect: renders only what is on screen.

// drawViewHierarchyInRect: renders nothing taller than this, in pixels (kENRMMaxCapturePixels).
static const CGFloat kENRMCaptureMaxPixels = 8192;

static NSString *ENRMCaptureParagraphs(NSUInteger count)
{
  NSMutableArray<NSString *> *paragraphs = [NSMutableArray array];
  for (NSUInteger i = 0; i < count; i++) {
    [paragraphs addObject:[NSString stringWithFormat:@"## Section %lu\n\nParagraph %lu runs over a few lines of the "
                                                     @"view so that the document gets long.",
                                                     (unsigned long)i, (unsigned long)i]];
  }
  return [paragraphs componentsJoinedByString:@"\n\n"];
}

static UIWindow *ENRMCaptureKeyWindow(void)
{
  for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
    if ([scene isKindOfClass:[UIWindowScene class]]) {
      for (UIWindow *window in ((UIWindowScene *)scene).windows) {
        if (window.isKeyWindow) {
          return window;
        }
      }
    }
  }
  return nil;
}

static UIImage *ENRMCaptureAtScale(UIView *view, CGFloat scale, void (^draw)(CGContextRef context))
{
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
  format.scale = scale;
  return [[[UIGraphicsImageRenderer alloc] initWithSize:view.bounds.size format:format]
      imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [[UIColor whiteColor] setFill];
        UIRectFill(view.bounds);
        draw(context.CGContext);
      }];
}

static UIImage *ENRMCapture(UIView *view, void (^draw)(CGContextRef context))
{
  return ENRMCaptureAtScale(view, 1, draw);
}

// The image's RGBA bytes, top row first.
static NSData *ENRMCapturePixels(UIImage *image)
{
  CGImageRef cgImage = image.CGImage;
  size_t width = CGImageGetWidth(cgImage);
  size_t height = CGImageGetHeight(cgImage);
  NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, colorSpace,
                                               kCGImageAlphaPremultipliedLast);
  CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);
  return pixels;
}

// Whether each `band`-point band of the image, top to bottom, has text (dark pixels) in it.
static NSString *ENRMCaptureTextBands(UIImage *image, CGFloat band)
{
  NSData *data = ENRMCapturePixels(image);
  const uint8_t *pixels = (const uint8_t *)data.bytes;
  size_t width = CGImageGetWidth(image.CGImage);
  size_t height = CGImageGetHeight(image.CGImage);
  NSMutableString *bands = [NSMutableString string];
  for (size_t top = 0; top < height; top += (size_t)band) {
    size_t dark = 0;
    for (size_t y = top; y < MIN(height, top + (size_t)band); y++) {
      for (size_t x = 0; x < width; x++) {
        const uint8_t *pixel = pixels + (y * width + x) * 4;
        dark += pixel[0] < 100 && pixel[1] < 100 && pixel[2] < 100;
      }
    }
    [bands appendString:dark > 20 ? @"#" : @"."];
  }
  return bands;
}

// The share of pixel rows where one image has text and the other none. The captures antialias
// differently (one is rendered at the screen's scale and scaled down), so pixels aren't compared.
static double ENRMCaptureRowDifference(UIImage *a, UIImage *b)
{
  NSData *pixelsA = ENRMCapturePixels(a);
  NSData *pixelsB = ENRMCapturePixels(b);
  size_t width = CGImageGetWidth(a.CGImage);
  size_t height = CGImageGetHeight(a.CGImage);
  if (pixelsA.length != pixelsB.length || height == 0) {
    return 1;
  }
  BOOL (^hasText)(const uint8_t *, size_t) = ^BOOL(const uint8_t *pixels, size_t y) {
    for (size_t x = 0; x < width; x++) {
      const uint8_t *pixel = pixels + (y * width + x) * 4;
      if (pixel[0] < 128 && pixel[1] < 128 && pixel[2] < 128) {
        return YES;
      }
    }
    return NO;
  };
  size_t differing = 0;
  for (size_t y = 0; y < height; y++) {
    differing += hasText((const uint8_t *)pixelsA.bytes, y) != hasText((const uint8_t *)pixelsB.bytes, y);
  }
  return (double)differing / height;
}

// Whether `rect` (points) of the image holds text: dark pixels, not a block's light background.
static BOOL ENRMCaptureHasText(UIImage *image, CGRect rect)
{
  NSData *data = ENRMCapturePixels(image);
  const uint8_t *pixels = (const uint8_t *)data.bytes;
  size_t width = CGImageGetWidth(image.CGImage);
  size_t height = CGImageGetHeight(image.CGImage);
  CGFloat scale = image.scale;
  for (size_t y = (size_t)MAX(0, CGRectGetMinY(rect) * scale); y < MIN(height, CGRectGetMaxY(rect) * scale); y++) {
    for (size_t x = (size_t)MAX(0, CGRectGetMinX(rect) * scale); x < MIN(width, CGRectGetMaxX(rect) * scale); x++) {
      const uint8_t *pixel = pixels + (y * width + x) * 4;
      if (pixel[0] < 100 && pixel[1] < 100 && pixel[2] < 100) {
        return YES;
      }
    }
  }
  return NO;
}

// What layoutSubviews runs once Fabric gave the view its content frame.
@interface EnrichedMarkdown (ENRMCaptureTesting)
- (CGSize)computeSegmentLayoutForWidth:(CGFloat)width applyFrames:(BOOL)applyFrames;
@end

static NSUInteger ENRMCaptureTileCount(UIView *view)
{
  NSUInteger count = 0;
  for (UIView *subview in view.subviews) {
    count +=
        [NSStringFromClass([subview class]) isEqualToString:@"ENRMTextTileView"] ? 1 : ENRMCaptureTileCount(subview);
  }
  return count;
}

// Runs `onLayout` when laid out: drawViewHierarchyInRect: with screen updates lays the views out.
@interface ENRMCaptureLayoutProbe : UIView
@property (nonatomic, copy) void (^onLayout)(void);
@end

@implementation ENRMCaptureLayoutProbe
- (void)layoutSubviews
{
  [super layoutSubviews];
  if (self.onLayout) {
    self.onLayout();
  }
}
@end

@interface ENRMTextCaptureTests : XCTestCase
@end

@implementation ENRMTextCaptureTests {
  UIScrollView *_scrollView;
  UIView *_content;
  EnrichedMarkdownInternalText *_segment;
}

- (BOOL)setUpWithError:(NSError **)error
{
  UIWindow *window = ENRMCaptureKeyWindow();
  if (window == nil) {
    XCTSkip(@"drawViewHierarchyInRect: needs the app's window on screen");
  }
  _scrollView = [[UIScrollView alloc] initWithFrame:window.bounds];
  [window addSubview:_scrollView];
  _content = [[UIView alloc] init];
  _content.backgroundColor = [UIColor whiteColor];
  [_scrollView addSubview:_content];
  // Taller than the screen and its margin, short enough for drawViewHierarchyInRect: to render.
  CGFloat width = window.bounds.size.width;
  CGFloat target = MIN(kENRMCaptureMaxPixels / window.screen.scale * 0.85, window.bounds.size.height * 3);
  NSUInteger paragraphs = 36;
  for (int attempt = 0; attempt < 2; attempt++) {
    [_segment removeFromSuperview];
    _segment = [self segmentWithParagraphs:paragraphs width:width];
    paragraphs = MAX(1u, (NSUInteger)(paragraphs * target / _segment.bounds.size.height));
  }
  _content.frame = _segment.frame;
  [_content addSubview:_segment];
  _scrollView.contentSize = _content.frame.size;
  [_segment layoutIfNeeded];
  [self settle];
  XCTAssertGreaterThan(_content.bounds.size.height, window.bounds.size.height * 2);
  XCTAssertLessThan(_content.bounds.size.height * window.screen.scale, kENRMCaptureMaxPixels);
  return YES;
}

- (EnrichedMarkdownInternalText *)segmentWithParagraphs:(NSUInteger)paragraphs width:(CGFloat)width
{
  StyleConfig *config = [[StyleConfig alloc] init];
  EnrichedMarkdownInternalText *segment = [[EnrichedMarkdownInternalText alloc] initWithConfig:config];
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init] parseMarkdown:ENRMCaptureParagraphs(paragraphs)
                                                                    flags:[ENRMMd4cFlags defaultFlags]
                                                                    isGFM:YES];
  [segment applyAttributedText:ENRMRenderASTNodes(ast.children, config, NO, YES, 0, NSLineBreakStrategyStandard)
                                   .attributedText
                       context:nil];
  segment.frame = CGRectMake(0, 0, width, [segment measureHeight:width]);
  return segment;
}

- (void)settle
{
  [CATransaction flush];
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
}

// The tiles of the text while `view` is captured with drawViewHierarchyInRect:, seen from a
// probe's layout (the capture lays the views out first).
- (NSInteger)tilesDuringCaptureOf:(UIView *)view in:(UIView *)probeParent
{
  ENRMCaptureLayoutProbe *probe = [[ENRMCaptureLayoutProbe alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  [probeParent addSubview:probe];
  __block NSInteger tiles = -1;
  __weak EnrichedMarkdownInternalText *segment = _segment;
  probe.onLayout = ^{ tiles = (NSInteger)ENRMCaptureTileCount(segment); };
  [probe setNeedsLayout];
  ENRMCapture(view, ^(CGContextRef context) { [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES]; });
  [probe removeFromSuperview];
  return tiles;
}

- (void)tearDown
{
  [_scrollView removeFromSuperview];
}

// Text in every 256-point band; a last band shorter than a line may hold only the bottom margin.
- (NSString *)allText
{
  CGFloat height = _content.bounds.size.height;
  NSUInteger bands = (NSUInteger)floor(height / 256) + (fmod(height, 256) > 40 ? 1 : 0);
  return [@"" stringByPaddingToLength:bands withString:@"#" startingAtIndex:0];
}

// The bands with text, the last band left out when it is shorter than a line.
- (NSString *)textBandsOf:(UIImage *)image
{
  return [ENRMCaptureTextBands(image, 256) substringToIndex:[self allText].length];
}

- (void)testRenderInContextCapturesTheWholeText
{
  NSUInteger tiles = ENRMCaptureTileCount(_segment);
  UIImage *image = ENRMCapture(_content, ^(CGContextRef context) { [self->_content.layer renderInContext:context]; });
  XCTAssertEqualObjects([self textBandsOf:image], [self allText]);
  // Drawn into the capture: no tiles are made for it.
  XCTAssertEqual(ENRMCaptureTileCount(_segment), tiles);
}

- (void)testDrawViewHierarchyCapturesTheWholeText
{
  for (NSNumber *afterUpdates in @[ @YES, @NO ]) {
    UIImage *image = ENRMCapture(_content, ^(CGContextRef context) {
      XCTAssertTrue([self->_content drawViewHierarchyInRect:self->_content.bounds
                                         afterScreenUpdates:afterUpdates.boolValue]);
    });
    XCTAssertEqualObjects([self textBandsOf:image], [self allText], @"afterScreenUpdates %@", afterUpdates);
  }
}

- (void)testBothCapturesDrawTheTextInTheSamePlace
{
  // At the screen's scale, where drawViewHierarchyInRect: renders.
  CGFloat scale = _content.window.screen.scale;
  UIImage *rendered =
      ENRMCaptureAtScale(_content, scale, ^(CGContextRef context) { [self->_content.layer renderInContext:context]; });
  UIImage *hierarchy = ENRMCaptureAtScale(_content, scale, ^(CGContextRef context) {
    [self->_content drawViewHierarchyInRect:self->_content.bounds afterScreenUpdates:YES];
  });
  XCTAssertLessThan(ENRMCaptureRowDifference(rendered, hierarchy), 0.02);
}

- (void)testTheTilesShrinkBackAfterACapture
{
  NSUInteger tiles = ENRMCaptureTileCount(_segment);
  ENRMCapture(_content, ^(CGContextRef context) {
    [self->_content drawViewHierarchyInRect:self->_content.bounds afterScreenUpdates:NO];
  });
  XCTAssertEqual(ENRMCaptureTileCount(_segment), tiles);
}

- (void)testACaptureOfAnotherViewLeavesTheTextAlone
{
  UIView *other = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
  [_scrollView.superview addSubview:other];
  NSInteger tiles = (NSInteger)ENRMCaptureTileCount(_segment);
  XCTAssertEqual([self tilesDuringCaptureOf:other in:other], tiles);
  [other removeFromSuperview];
}

// A capture of what is on screen finds that part drawn already.
- (void)testACaptureOfTheScreenAddsNoTiles
{
  NSInteger tiles = (NSInteger)ENRMCaptureTileCount(_segment);
  XCTAssertEqual([self tilesDuringCaptureOf:_scrollView in:_scrollView], tiles);
}

// drawViewHierarchyInRect: renders nothing for a view this tall: the text draws nothing more for it.
- (void)testAViewTooTallToCaptureAddsNoTiles
{
  _content.frame =
      CGRectMake(0, 0, _content.bounds.size.width, kENRMCaptureMaxPixels / _content.window.screen.scale + 100);
  NSInteger tiles = (NSInteger)ENRMCaptureTileCount(_segment);
  XCTAssertEqual([self tilesDuringCaptureOf:_content in:_content], tiles);
}

// The probe sees the tiles a capture of the text adds.
- (void)testACaptureOfTheTextAddsTilesForAllOfIt
{
  NSInteger tiles = (NSInteger)ENRMCaptureTileCount(_segment);
  XCTAssertGreaterThan([self tilesDuringCaptureOf:_content in:_content], tiles);
  XCTAssertEqual((NSInteger)ENRMCaptureTileCount(_segment), tiles);
}

// A capture made while another one draws (a view capturing itself in layout) keeps the outer one's tiles.
- (void)testACaptureInsideACaptureKeepsTheOuterTiles
{
  NSInteger tiles = (NSInteger)ENRMCaptureTileCount(_segment);
  ENRMCaptureLayoutProbe *probe = [[ENRMCaptureLayoutProbe alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  [_content addSubview:probe];
  __block NSInteger afterInner = -1;
  __weak UIView *content = _content;
  __weak EnrichedMarkdownInternalText *segment = _segment;
  probe.onLayout = ^{
    if (afterInner >= 0) {
      return;
    }
    afterInner = 0;
    ENRMCapture(content,
                ^(CGContextRef context) { [content drawViewHierarchyInRect:content.bounds afterScreenUpdates:NO]; });
    afterInner = (NSInteger)ENRMCaptureTileCount(segment);
  };
  [probe setNeedsLayout];
  UIImage *image = ENRMCapture(_content, ^(CGContextRef context) {
    [self->_content drawViewHierarchyInRect:self->_content.bounds afterScreenUpdates:YES];
  });
  XCTAssertGreaterThan(afterInner, tiles);
  XCTAssertEqualObjects([self textBandsOf:image], [self allText]);
  XCTAssertEqual((NSInteger)ENRMCaptureTileCount(_segment), tiles);
}

// A capture of part of the text, into a context moved to it.
- (void)testRenderInContextIntoAMovedContextDrawsThatPart
{
  CGFloat top = _content.bounds.size.height - 600;
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
  format.scale = 1;
  UIImage *image = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(_content.bounds.size.width, 512)
                                                           format:format]
      imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [[UIColor whiteColor] setFill];
        UIRectFill(CGRectMake(0, 0, self->_content.bounds.size.width, 512));
        CGContextTranslateCTM(context.CGContext, 0, -top);
        [self->_content.layer renderInContext:context.CGContext];
      }];
  XCTAssertEqualObjects(ENRMCaptureTextBands(image, 256), @"##");
}

// A snapshot view keeps what the render server captured: shown in the window and
// read back from the screen part by part, it has the whole text.
- (void)testASnapshotViewHasTheWholeText
{
  UIWindow *window = _content.window;
  NSArray<UIView * (^)(void)> *snapshots = @[
    ^{ return [self->_content snapshotViewAfterScreenUpdates:YES]; },
    ^{ return [self->_content snapshotViewAfterScreenUpdates:NO]; },
    ^{
      return [self->_content resizableSnapshotViewFromRect:self->_content.bounds
                                        afterScreenUpdates:YES
                                             withCapInsets:UIEdgeInsetsMake(8, 8, 8, 8)];
    },
    ^{
      return [self->_content resizableSnapshotViewFromRect:self->_content.bounds
                                        afterScreenUpdates:NO
                                             withCapInsets:UIEdgeInsetsZero];
    },
  ];
  for (NSUInteger kind = 0; kind < snapshots.count; kind++) {
    UIView *snapshot = snapshots[kind]();
    UIScrollView *holder = [[UIScrollView alloc] initWithFrame:window.bounds];
    holder.backgroundColor = [UIColor whiteColor];
    [window addSubview:holder];
    [holder addSubview:snapshot];
    snapshot.frame = _content.bounds;
    holder.contentSize = _content.bounds.size;
    NSMutableString *bands = [NSMutableString string];
    for (NSUInteger band = 0; band < [self allText].length; band++) {
      CGFloat top = band * 256;
      holder.contentOffset = CGPointMake(0, MIN(top, holder.contentSize.height - holder.bounds.size.height));
      [self settle];
      UIImage *screen = ENRMCapture(
          window, ^(CGContextRef context) { [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES]; });
      CGFloat shownTop = top - holder.contentOffset.y;
      UIImage *part = ENRMCapture(holder, ^(CGContextRef context) { [screen drawAtPoint:CGPointMake(0, -shownTop)]; });
      [bands appendString:[ENRMCaptureTextBands(part, 256) substringToIndex:1]];
    }
    [holder removeFromSuperview];
    XCTAssertEqualObjects(bands, [self allText], @"snapshot %lu", (unsigned long)kind);
  }
}

// A document laid out at `width` in the scroll view: `paragraphs` paragraphs, a code block, and a
// paragraph after it.
- (EnrichedMarkdown *)documentWithParagraphs:(NSUInteger)paragraphs width:(CGFloat)width
{
  EnrichedMarkdown *document = [[EnrichedMarkdown alloc] initWithFrame:CGRectMake(0, 0, width, 0)];
  document.config = [[StyleConfig alloc] init];
  NSMutableArray<NSString *> *parts = [NSMutableArray array];
  for (NSUInteger i = 0; i < paragraphs; i++) {
    [parts addObject:[NSString stringWithFormat:@"Paragraph %lu of the answer.", (unsigned long)i]];
  }
  [parts addObject:@"```\nlet answer = 42\n```"];
  [parts addObject:@"The paragraph after the code block."];
  [_scrollView addSubview:document];
  [document renderMarkdownSynchronously:[parts componentsJoinedByString:@"\n\n"]];
  CGSize size = [document computeSegmentLayoutForWidth:width applyFrames:YES];
  document.frame = CGRectMake(0, 0, width, size.height);
  _scrollView.contentSize = size;
  [document layoutIfNeeded];
  return document;
}

// A document's code block past the margin drops its bitmap, and the text after it draws nothing:
// a capture draws both.
- (void)testACaptureOfADocumentDrawsItsDroppedBlocksAndText
{
  UIWindow *window = _scrollView.window;
  CGFloat width = window.bounds.size.width;
  CGFloat target = MIN(kENRMCaptureMaxPixels / window.screen.scale * 0.85, window.bounds.size.height * 3);
  [_content removeFromSuperview];
  NSUInteger paragraphs = 120;
  EnrichedMarkdown *document = nil;
  for (int attempt = 0; attempt < 2; attempt++) {
    [document removeFromSuperview];
    document = [self documentWithParagraphs:paragraphs width:width];
    paragraphs = MAX(1u, (NSUInteger)(paragraphs * target / document.bounds.size.height));
  }
  [self settle];
  UIView *block = nil;
  UIView *after = nil;
  for (UIView *subview in document.subviews) {
    if ([NSStringFromClass([subview class]) isEqualToString:@"ENRMCodeBlockContainerView"]) {
      block = subview;
    } else if (block != nil && [subview isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      after = subview;
    }
  }
  XCTAssertNotNil(block);
  XCTAssertNotNil(after);
  XCTAssertGreaterThan(CGRectGetMinY(block.frame), window.bounds.size.height + 700);
  XCTAssertLessThan(document.bounds.size.height * window.screen.scale, kENRMCaptureMaxPixels);
  XCTAssertNil(block.layer.contents);
  XCTAssertEqual(ENRMCaptureTileCount(after), 0u);

  UIImage *rendered = ENRMCapture(document, ^(CGContextRef context) { [document.layer renderInContext:context]; });
  XCTAssertTrue(ENRMCaptureHasText(rendered, block.frame));
  XCTAssertTrue(ENRMCaptureHasText(rendered, after.frame));
  for (NSNumber *afterUpdates in @[ @YES, @NO ]) {
    UIImage *image = ENRMCapture(document, ^(CGContextRef context) {
      [document drawViewHierarchyInRect:document.bounds afterScreenUpdates:afterUpdates.boolValue];
    });
    XCTAssertTrue(ENRMCaptureHasText(image, block.frame), @"afterScreenUpdates %@", afterUpdates);
    XCTAssertTrue(ENRMCaptureHasText(image, after.frame), @"afterScreenUpdates %@", afterUpdates);
  }
  [self settle];
  XCTAssertNil(block.layer.contents);
  XCTAssertEqual(ENRMCaptureTileCount(after), 0u);
  [document removeFromSuperview];
}

@end
