#import "../../ios/EnrichedMarkdown.h"
#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/segments/ENRMCodeBlockContainerView.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMVisibleArea.h"
#import <XCTest/XCTest.h>

// A code block draws its code in tiles near the screen (ENRMTileCanvas), not in one bitmap as wide as
// its longest line and as tall as all of it (#1212); its box is drawn by its layer.

static const CGFloat kENRMCodeTilesTestWidth = 390;
static const CGFloat kENRMCodeTilesTestWindowHeight = 844;
// ENRMTileCanvas's tile size and the pane's horizontal margin.
static const CGFloat kENRMCodeTilesTestTile = 256;
static const CGFloat kENRMCodeTilesTestHorizontalMargin = 128;
// drawViewHierarchyInRect: renders nothing taller than this, in pixels (kENRMMaxCapturePixels).
static const CGFloat kENRMCodeTilesTestMaxCapturePixels = 8192;

@interface EnrichedMarkdown (ENRMCodeBlockTilesTesting)
- (CGSize)computeSegmentLayoutForWidth:(CGFloat)width applyFrames:(BOOL)applyFrames;
@end

// `lines` lines of code, the last one followed by `tail`; each line in a quote when `quoted`.
static NSString *ENRMCodeTilesCode(NSUInteger lines, NSUInteger lineLength, NSString *tail, BOOL quoted)
{
  NSMutableArray<NSString *> *code = [NSMutableArray arrayWithObject:@"```"];
  NSString *filler = [@"" stringByPaddingToLength:lineLength withString:@"x" startingAtIndex:0];
  for (NSUInteger i = 0; i < lines; i++) {
    [code addObject:[NSString stringWithFormat:@"const line%lu = \"%@\";", (unsigned long)i, filler]];
  }
  code[code.count - 1] = [code.lastObject stringByAppendingString:tail];
  [code addObject:@"```"];
  NSString *prefix = quoted ? @"> " : @"";
  NSString *block =
      [prefix stringByAppendingString:[code componentsJoinedByString:[@"\n" stringByAppendingString:prefix]]];
  return [NSString stringWithFormat:@"Intro\n\n%@\n\nOutro", block];
}

static NSString *ENRMCodeTilesMarkdown(NSUInteger lines, NSUInteger lineLength)
{
  return ENRMCodeTilesCode(lines, lineLength, @"", NO);
}

// The code block node of `markdown`, as the reconciler hands a block it updates in place (streaming).
static MarkdownASTNode *ENRMCodeTilesCodeBlockNode(NSString *markdown)
{
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init] parseMarkdown:markdown
                                                                    flags:[ENRMMd4cFlags defaultFlags]
                                                                    isGFM:YES];
  for (MarkdownASTNode *node in ast.children) {
    if (node.type == MarkdownNodeTypeCodeBlock) {
      return node;
    }
  }
  return nil;
}

static UIView *ENRMCodeTilesFindView(UIView *view, NSString *className)
{
  if ([NSStringFromClass([view class]) isEqualToString:className]) {
    return view;
  }
  for (UIView *subview in view.subviews) {
    UIView *found = ENRMCodeTilesFindView(subview, className);
    if (found != nil) {
      return found;
    }
  }
  return nil;
}

static NSArray<UIView *> *ENRMCodeTilesTiles(UIView *canvas)
{
  NSMutableArray<UIView *> *tiles = [NSMutableArray array];
  for (UIView *subview in canvas.subviews) {
    if ([NSStringFromClass([subview class]) isEqualToString:@"ENRMCanvasTileView"]) {
      [tiles addObject:subview];
    }
  }
  return tiles;
}

// The part of the code the tiles cover, in the canvas's space; CGRectNull when none.
static CGRect ENRMCodeTilesCovered(UIView *canvas)
{
  CGRect covered = CGRectNull;
  for (UIView *tile in ENRMCodeTilesTiles(canvas)) {
    covered = CGRectUnion(covered, tile.frame);
  }
  return covered;
}

static void ENRMCodeTilesDisplay(UIView *canvas)
{
  for (UIView *tile in ENRMCodeTilesTiles(canvas)) {
    [tile.layer displayIfNeeded];
  }
}

// Whether a 1x image of `rect` (`view`'s space), drawn by `draw` in `view`'s space, shows glyphs:
// anti-aliased text has many shades, a fill or a border few.
static BOOL ENRMCodeTilesShowsGlyphs(UIView *view, CGRect rect, void (^draw)(CGContextRef context))
{
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
  format.scale = 1;
  UIImage *image = [[[UIGraphicsImageRenderer alloc] initWithSize:rect.size format:format]
      imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [[UIColor whiteColor] setFill];
        UIRectFill(CGRectMake(0, 0, rect.size.width, rect.size.height));
        CGContextTranslateCTM(context.CGContext, -rect.origin.x, -rect.origin.y);
        draw(context.CGContext);
      }];
  CGImageRef cgImage = image.CGImage;
  size_t width = CGImageGetWidth(cgImage);
  size_t height = CGImageGetHeight(cgImage);
  NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  CGContextRef bitmap = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, space,
                                              (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
  CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), cgImage);
  CGContextRelease(bitmap);
  CGColorSpaceRelease(space);
  const uint32_t *values = (const uint32_t *)pixels.bytes;
  NSMutableSet<NSNumber *> *shades = [NSMutableSet set];
  for (size_t i = 0; i < width * height && shades.count <= 8; i++) {
    [shades addObject:@(values[i])];
  }
  return shades.count > 8;
}

static UIWindow *ENRMCodeTilesKeyWindow(void)
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

@interface ENRMCodeBlockTilesTests : XCTestCase
@end

@implementation ENRMCodeBlockTilesTests {
  UIWindow *_window;
  UIScrollView *_scrollView;
  EnrichedMarkdown *_document;
  ENRMCodeBlockContainerView *_codeBlock;
  UIView *_content;
  UIView *_canvas;
}

- (void)setUp
{
  _window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, kENRMCodeTilesTestWidth, kENRMCodeTilesTestWindowHeight)];
  _window.hidden = NO;
  _scrollView = [[UIScrollView alloc] initWithFrame:_window.bounds];
  [_window addSubview:_scrollView];
  _document = [[EnrichedMarkdown alloc] initWithFrame:CGRectMake(0, 0, kENRMCodeTilesTestWidth, 0)];
  _document.config = [[StyleConfig alloc] init];
  [_scrollView addSubview:_document];
}

- (void)tearDown
{
  [_scrollView removeFromSuperview];
  _window.hidden = YES;
  _window = nil;
}

- (void)render:(NSString *)markdown
{
  [_document renderMarkdownSynchronously:markdown];
  [self layOutAtWidth:_scrollView.bounds.size.width];
}

- (void)layOutAtWidth:(CGFloat)width
{
  CGSize size = [_document computeSegmentLayoutForWidth:width applyFrames:YES];
  _document.frame = CGRectMake(0, 0, width, size.height);
  _scrollView.contentSize = CGSizeMake(width, size.height);
  [_document layoutIfNeeded];
  _codeBlock = (ENRMCodeBlockContainerView *)ENRMCodeTilesFindView(_document, @"ENRMCodeBlockContainerView");
  _content = ENRMCodeTilesFindView(_codeBlock, @"ENRMCodeBlockContentView");
  _canvas = ENRMCodeTilesFindView(_content, @"ENRMTileCanvas");
  [_codeBlock layoutIfNeeded];
}

// The pane's scroll view, which scrolls the code horizontally.
- (UIScrollView *)pane
{
  return (UIScrollView *)_content.superview;
}

- (CGFloat)maxCoveredHeight
{
  return kENRMCodeTilesTestWindowHeight + ENRMVisibleAreaMargin * 2 + kENRMCodeTilesTestTile * 2;
}

- (void)assertTheTilesCoverWhatShows
{
  CGRect covered = ENRMCodeTilesCovered(_canvas);
  CGRect shown = [_content convertRect:_scrollView.bounds fromView:_scrollView];
  shown = CGRectIntersection(shown, [_content convertRect:[self pane].bounds fromView:[self pane]]);
  XCTAssertTrue(CGRectContainsRect(covered, CGRectIntersection(shown, _content.bounds)), @"%@ does not cover %@",
                NSStringFromCGRect(covered), NSStringFromCGRect(shown));
}

static BOOL ENRMCodeTilesSameColor(UIColor *a, UIColor *b)
{
  CGFloat ar, ag, ab, aa, br, bg, bb, ba;
  if (![a getRed:&ar green:&ag blue:&ab alpha:&aa] || ![b getRed:&br green:&bg blue:&bb alpha:&ba]) {
    return NO;
  }
  return fabs(ar - br) < 0.01 && fabs(ag - bg) < 0.01 && fabs(ab - bb) < 0.01 && fabs(aa - ba) < 0.01;
}

// The document reuses a block when new markdown comes with a markdownStyle change, which updates
// the config it shares in place: the box follows the new style, as drawRect: drew it.
- (void)testAReusedBlockTakesTheNewStyle
{
  [self render:ENRMCodeTilesCode(10, 4, @"", NO)];
  StyleConfig *config = [_codeBlock valueForKey:@"_config"];
  [config setCodeBlockBackgroundColor:UIColor.redColor];
  [config setCodeBlockBorderColor:UIColor.blueColor];
  [config setCodeBlockBorderWidth:3];
  [config setCodeBlockColor:UIColor.greenColor];
  [_codeBlock applyCodeBlockNode:ENRMCodeTilesCodeBlockNode(ENRMCodeTilesCode(10, 4, @" // more", NO))];
  [_codeBlock layoutIfNeeded];

  UIView *fill = [_codeBlock valueForKey:@"_fillView"];
  UIView *divider = [_codeBlock valueForKey:@"_dividerView"];
  XCTAssertTrue(ENRMCodeTilesSameColor(fill.backgroundColor, UIColor.redColor), @"%@", fill.backgroundColor);
  XCTAssertEqual(_codeBlock.layer.borderWidth, 3);
  XCTAssertTrue(ENRMCodeTilesSameColor([UIColor colorWithCGColor:_codeBlock.layer.borderColor], UIColor.blueColor));
  XCTAssertTrue(CGRectEqualToRect(fill.frame, CGRectInset(_codeBlock.bounds, 1.5, 1.5)), @"%@",
                NSStringFromCGRect(fill.frame));
  CGFloat red, green, blue, alpha;
  [divider.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha];
  XCTAssertTrue(green > 0.9 && red < 0.1, @"%@", divider.backgroundColor);
}

- (void)testATallBlockDrawsOnlyNearTheScreenInTiles
{
  [self render:ENRMCodeTilesMarkdown(800, 26)];
  XCTAssertNotNil(_canvas);
  XCTAssertGreaterThan(_content.bounds.size.height, kENRMCodeTilesTestWindowHeight * 10);
  [self assertTheTilesCoverWhatShows];
  XCTAssertLessThanOrEqual(ENRMCodeTilesCovered(_canvas).size.height, [self maxCoveredHeight]);
  // Neither the block nor its pane holds a bitmap of its size. As Core Animation's commit draws what
  // UIKit marked: a view without drawRect: is never marked.
  for (UIView *view in @[ _codeBlock, _content, _canvas ]) {
    [view setNeedsDisplay];
    [view.layer displayIfNeeded];
    XCTAssertNil(view.layer.contents, @"%@", view);
  }
  for (UIView *tile in ENRMCodeTilesTiles(_canvas)) {
    XCTAssertLessThanOrEqual(tile.bounds.size.width, kENRMCodeTilesTestTile);
    XCTAssertLessThanOrEqual(tile.bounds.size.height, kENRMCodeTilesTestTile);
  }
}

- (void)testScrollingTheDocumentMovesTheTiles
{
  [self render:ENRMCodeTilesMarkdown(800, 26)];
  _scrollView.contentOffset = CGPointMake(0, round(CGRectGetMidY(_codeBlock.frame)));
  [self assertTheTilesCoverWhatShows];
  XCTAssertGreaterThan(CGRectGetMinY(ENRMCodeTilesCovered(_canvas)), 0);
  XCTAssertLessThanOrEqual(ENRMCodeTilesCovered(_canvas).size.height, [self maxCoveredHeight]);
}

- (void)testAWideBlockDrawsOnlyWhatItsPaneShows
{
  [self render:ENRMCodeTilesMarkdown(20, 600)];
  UIScrollView *pane = [self pane];
  XCTAssertGreaterThan(_content.bounds.size.width, pane.bounds.size.width * 5);
  CGFloat widest = pane.bounds.size.width + kENRMCodeTilesTestHorizontalMargin * 2 + kENRMCodeTilesTestTile * 2;
  XCTAssertLessThanOrEqual(ENRMCodeTilesCovered(_canvas).size.width, widest);

  pane.contentOffset = CGPointMake(_content.bounds.size.width - pane.bounds.size.width, 0);
  [self assertTheTilesCoverWhatShows];
  XCTAssertEqualWithAccuracy(CGRectGetMaxX(ENRMCodeTilesCovered(_canvas)), _content.bounds.size.width, 0.5);
  XCTAssertLessThanOrEqual(ENRMCodeTilesCovered(_canvas).size.width, widest);
}

// A rotation widens the pane alone: nothing in it is laid out, and its new part still draws.
- (void)testAWiderPaneDrawsItsNewPart
{
  [self render:ENRMCodeTilesMarkdown(20, 600)];
  CGFloat wide = 900;
  _window.frame = CGRectMake(0, 0, wide, kENRMCodeTilesTestWindowHeight);
  _scrollView.frame = _window.bounds;
  [self layOutAtWidth:wide];
  // Wider than the tiles reached before: the new part needs tiles of its own.
  XCTAssertGreaterThan([self pane].bounds.size.width, kENRMCodeTilesTestWidth + kENRMCodeTilesTestTile);
  [self assertTheTilesCoverWhatShows];
}

// Streaming lengthens the last line: only its tile redraws, not the lines above.
- (void)testLengtheningTheLastLineRedrawsOnlyItsTile
{
  [self render:ENRMCodeTilesCode(60, 4, @"", NO)];
  CGRect contentBounds = _content.bounds;
  ENRMCodeTilesDisplay(_canvas);

  // What the reconciler does to a streaming block: updates it in place.
  [_codeBlock applyCodeBlockNode:ENRMCodeTilesCodeBlockNode(ENRMCodeTilesCode(60, 4, @" // more", NO))];
  [_codeBlock layoutIfNeeded];
  XCTAssertTrue(CGRectEqualToRect(_content.bounds, contentBounds), @"No tile is resized");
  NSUInteger redrawn = 0;
  for (UIView *tile in ENRMCodeTilesTiles(_canvas)) {
    BOOL holdsTheLastLine = CGRectGetMaxY(tile.frame) >= contentBounds.size.height - kENRMCodeTilesTestTile / 2;
    if (CGRectGetMinY(tile.frame) == 0) {
      XCTAssertFalse(tile.layer.needsDisplay, @"%@", NSStringFromCGRect(tile.frame));
    }
    if (holdsTheLastLine) {
      XCTAssertTrue(tile.layer.needsDisplay, @"%@", NSStringFromCGRect(tile.frame));
    }
    redrawn += tile.layer.needsDisplay ? 1 : 0;
  }
  XCTAssertLessThan(redrawn, ENRMCodeTilesTiles(_canvas).count);
}

- (void)testOtherCodeRedrawsEveryTile
{
  [self render:ENRMCodeTilesCode(60, 4, @"", NO)];
  ENRMCodeTilesDisplay(_canvas);
  NSString *other = [ENRMCodeTilesCode(60, 4, @"", NO) stringByReplacingOccurrencesOfString:@"line0 "
                                                                                 withString:@"first "];
  [_codeBlock applyCodeBlockNode:ENRMCodeTilesCodeBlockNode(other)];
  [_codeBlock layoutIfNeeded];
  for (UIView *tile in ENRMCodeTilesTiles(_canvas)) {
    XCTAssertTrue(tile.layer.needsDisplay, @"%@", NSStringFromCGRect(tile.frame));
  }
}

// A code block in a quote follows the document's area too.
- (void)testABlockInAQuoteDrawsOnlyNearTheScreen
{
  [self render:ENRMCodeTilesCode(800, 26, @"", YES)];
  XCTAssertNotNil(_canvas);
  XCTAssertNotNil(ENRMCodeTilesFindView(_document, @"ENRMBlockquoteContainerView"));
  XCTAssertTrue([_codeBlock isDescendantOfView:ENRMCodeTilesFindView(_document, @"ENRMBlockquoteContainerView")]);
  XCTAssertNotNil(((id<ENRMVisibleAreaFollower>)_content).visibleArea);
  [self assertTheTilesCoverWhatShows];
  XCTAssertLessThanOrEqual(ENRMCodeTilesCovered(_canvas).size.height, [self maxCoveredHeight]);
}

- (void)testLeavingTheWindowDropsTheTiles
{
  [self render:ENRMCodeTilesMarkdown(200, 26)];
  XCTAssertGreaterThan(ENRMCodeTilesTiles(_canvas).count, 0u);
  [_scrollView removeFromSuperview];
  XCTAssertEqual(ENRMCodeTilesTiles(_canvas).count, 0u);
  [_window addSubview:_scrollView];
  XCTAssertGreaterThan(ENRMCodeTilesTiles(_canvas).count, 0u);
}

// renderInContext: renders the layer tree as it is, which has tiles only near the screen: the canvas
// draws the code there too.
- (void)testRenderInContextDrawsCodeFarFromTheScreen
{
  [self render:ENRMCodeTilesMarkdown(800, 26)];
  CGRect far = CGRectMake(0, _content.bounds.size.height - 400, 300, 200);
  XCTAssertFalse(CGRectIntersectsRect(ENRMCodeTilesCovered(_canvas), far));
  CALayer *layer = _codeBlock.layer;
  CGRect rect = [_codeBlock convertRect:far fromView:_content];
  XCTAssertTrue(
      ENRMCodeTilesShowsGlyphs(_codeBlock, rect, ^(CGContextRef context) { [layer renderInContext:context]; }));
}

// drawViewHierarchyInRect: renders through the render server, which has tiles only near the screen:
// the canvas adds tiles for the capture (ENRMCapture), and drops them after it.
- (void)testDrawViewHierarchyDrawsCodeFarFromTheScreen
{
  UIWindow *window = ENRMCodeTilesKeyWindow();
  if (window == nil) {
    XCTSkip(@"drawViewHierarchyInRect: needs the app's window on screen");
  }
  _scrollView.frame = window.bounds;
  [window addSubview:_scrollView];
  // Taller than the screen and its margin, short enough for drawViewHierarchyInRect: to render.
  CGFloat target = MIN(kENRMCodeTilesTestMaxCapturePixels / window.screen.scale * 0.8, window.bounds.size.height * 3);
  NSUInteger lines = 100;
  for (int attempt = 0; attempt < 2; attempt++) {
    [self render:ENRMCodeTilesMarkdown(lines, 8)];
    lines = MAX(1u, (NSUInteger)(lines * target / _codeBlock.bounds.size.height));
  }
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
  CGRect far = CGRectMake(0, _content.bounds.size.height - 300, 200, 150);
  XCTAssertFalse(CGRectIntersectsRect(ENRMCodeTilesCovered(_canvas), far));
  NSUInteger tilesBefore = ENRMCodeTilesTiles(_canvas).count;

  ENRMCodeBlockContainerView *codeBlock = _codeBlock;
  CGRect rect = [codeBlock convertRect:far fromView:_content];
  XCTAssertTrue(ENRMCodeTilesShowsGlyphs(codeBlock, rect, ^(CGContextRef context) {
    [codeBlock drawViewHierarchyInRect:codeBlock.bounds afterScreenUpdates:YES];
  }));
  XCTAssertEqual(ENRMCodeTilesTiles(_canvas).count, tilesBefore);
}

@end
