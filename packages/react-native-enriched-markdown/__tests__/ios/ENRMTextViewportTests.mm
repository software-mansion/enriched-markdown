#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMSpoilerOverlayView.h"
#import "../../ios/utils/ENRMSpoilerTapUtils.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import "../../ios/views/ENRMMarkdownTextView.h"
#import "../../ios/views/EnrichedMarkdownInternalText.h"
#import <XCTest/XCTest.h>

static const CGFloat kWidth = 390;
static const CGFloat kWindowHeight = 844;

static NSMutableAttributedString *ENRMRenderMarkdown(NSString *markdown, StyleConfig *config)
{
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init] parseMarkdown:markdown
                                                                    flags:[ENRMMd4cFlags defaultFlags]
                                                                    isGFM:YES];
  return ENRMRenderASTNodes(ast.children, config, NO, YES, 0, NSLineBreakStrategyStandard).attributedText;
}

static void ENRMCollectTiles(UIView *view, NSMutableArray<UIView *> *tiles)
{
  for (UIView *subview in view.subviews) {
    // By name: the test bundle compiles its own copy of the library's classes.
    if ([NSStringFromClass([subview class]) isEqualToString:@"ENRMTextTileView"]) {
      [tiles addObject:subview];
    } else {
      ENRMCollectTiles(subview, tiles);
    }
  }
}

/// The tiles a text view draws its text with (ENRMMarkdownTextView), top to bottom.
static NSArray<UIView *> *ENRMTiles(UITextView *textView)
{
  NSMutableArray<UIView *> *tiles = [NSMutableArray array];
  ENRMCollectTiles(textView, tiles);
  [tiles sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
    return [a convertPoint:CGPointZero toView:textView].y < [b convertPoint:CGPointZero toView:textView].y
               ? NSOrderedAscending
               : NSOrderedDescending;
  }];
  return tiles;
}

static UIView *ENRMSubviewOfClass(UIView *view, NSString *className)
{
  for (UIView *subview in view.subviews) {
    if ([subview isKindOfClass:NSClassFromString(className)]) {
      return subview;
    }
  }
  return nil;
}

/// The part of the text the tiles draw (the text view's space); CGRectNull when none does.
static CGRect ENRMDrawnRect(UITextView *textView)
{
  CGRect drawn = CGRectNull;
  for (UIView *tile in ENRMTiles(textView)) {
    drawn = CGRectUnion(drawn, [tile convertRect:tile.bounds toView:textView]);
  }
  return drawn;
}

static NSString *ENRMParagraphs(NSUInteger count)
{
  NSMutableArray<NSString *> *paragraphs = [NSMutableArray array];
  for (NSUInteger i = 0; i < count; i++) {
    [paragraphs addObject:[NSString stringWithFormat:@"## Section %lu\n\nParagraph %lu runs over a few lines of the "
                                                     @"view so that the document gets long, as a long answer does.",
                                                     (unsigned long)i, (unsigned long)i]];
  }
  return [paragraphs componentsJoinedByString:@"\n\n"];
}

@interface ENRMTextViewportTests : XCTestCase
@end

@implementation ENRMTextViewportTests {
  StyleConfig *_config;
  UIWindow *_window;
  UIScrollView *_scrollView;
}

- (void)setUp
{
  _config = [[StyleConfig alloc] init];
  _window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, kWidth, kWindowHeight)];
  _window.hidden = NO;
  _scrollView = [[UIScrollView alloc] initWithFrame:_window.bounds];
  [_window addSubview:_scrollView];
}

- (void)tearDown
{
  _window.hidden = YES;
  _window = nil;
}

/// A text segment with `markdown`, sized to its text; in the scroll view when `onScreen`.
- (EnrichedMarkdownInternalText *)segmentWithMarkdown:(NSString *)markdown onScreen:(BOOL)onScreen
{
  EnrichedMarkdownInternalText *segment = [[EnrichedMarkdownInternalText alloc] initWithConfig:_config];
  [segment applyAttributedText:ENRMRenderMarkdown(markdown, _config) context:nil];
  CGFloat height = [segment measureHeight:kWidth];
  segment.frame = CGRectMake(0, 0, kWidth, height);
  if (onScreen) {
    _scrollView.contentSize = CGSizeMake(kWidth, height);
    [_scrollView addSubview:segment];
  }
  [segment layoutIfNeeded];
  return segment;
}

- (void)testALongTextDrawsOnlyThePartOnScreen
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  CGFloat height = segment.bounds.size.height;
  XCTAssertGreaterThan(height, kWindowHeight * 4);

  // The text view keeps its whole frame, for UIKit's selection, menus and hit testing.
  UITextView *textView = segment.textView;
  XCTAssertTrue(CGRectEqualToRect(textView.frame, segment.bounds));
  CGRect drawn = ENRMDrawnRect(textView);
  XCTAssertEqual(CGRectGetMinY(drawn), 0);
  XCTAssertGreaterThanOrEqual(CGRectGetMaxY(drawn), kWindowHeight);
  XCTAssertLessThan(CGRectGetMaxY(drawn), kWindowHeight * 2.5);
  // UIKit's own canvas, a bitmap of the whole frame, has nothing to draw; the container view around
  // it keeps the whole frame, for UIKit's touch mapping and menu placement.
  UIView *container = ENRMSubviewOfClass(textView, @"_UITextContainerView");
  XCTAssertEqual(container.frame.size.height, height);
  XCTAssertEqual(ENRMSubviewOfClass(container, @"_UITextViewCanvasView").frame.size.height, 0);
}

- (void)testScrollingMovesTheDrawnPart
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  CGFloat offset = round(segment.bounds.size.height / 2);
  _scrollView.contentOffset = CGPointMake(0, offset);

  CGRect drawn = ENRMDrawnRect(segment.textView);
  XCTAssertLessThanOrEqual(CGRectGetMinY(drawn), offset);
  XCTAssertGreaterThanOrEqual(CGRectGetMaxY(drawn), offset + kWindowHeight);
  XCTAssertLessThan(drawn.size.height, kWindowHeight * 3.5);
  XCTAssertTrue(CGRectEqualToRect(segment.textView.frame, segment.bounds));
}

// A scroll view growing with no scroll (a keyboard going away) shows more of the text.
- (void)testAScrollViewGrowingDrawsMore
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  XCTAssertLessThan(CGRectGetMaxY(ENRMDrawnRect(segment.textView)), kWindowHeight * 2.5);
  _scrollView.frame = CGRectMake(0, 0, kWidth, kWindowHeight * 3);
  XCTAssertGreaterThanOrEqual(CGRectGetMaxY(ENRMDrawnRect(segment.textView)), kWindowHeight * 3);
}

// While a text is in a window its visible area holds the scroll views above it, which hold the text:
// leaving the window lets them go.
- (void)testLeavingTheWindowReleasesTheScrollViews
{
  __weak UIScrollView *weakScrollView;
  @autoreleasepool {
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:_window.bounds];
    [_window addSubview:scrollView];
    EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(20) onScreen:NO];
    [scrollView addSubview:segment];
    [segment layoutIfNeeded];
    XCTAssertGreaterThan(ENRMTiles(segment.textView).count, 0u);
    weakScrollView = scrollView;
    [scrollView removeFromSuperview];
  }
  XCTAssertNil(weakScrollView);
}

// Animated's native driver moves a view by its transform, with no scroll and no layout.
- (void)testAnAncestorsTransformMovesTheDrawnPart
{
  UIView *moving = [[UIView alloc] initWithFrame:_scrollView.bounds];
  [_scrollView addSubview:moving];
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:NO];
  _scrollView.contentSize = segment.bounds.size;
  [moving addSubview:segment];
  [segment layoutIfNeeded];
  CGFloat offset = round(segment.bounds.size.height / 2);
  moving.layer.transform = CATransform3DMakeTranslation(0, -offset, 0);

  CGRect drawn = ENRMDrawnRect(segment.textView);
  XCTAssertLessThanOrEqual(CGRectGetMinY(drawn), offset);
  XCTAssertGreaterThanOrEqual(CGRectGetMaxY(drawn), offset + kWindowHeight);
  XCTAssertLessThan(drawn.size.height, kWindowHeight * 3.5);
}

// A line clamp or truncation mode change lays the text out again with no edit (the layout manager
// invalidates its display).
- (void)testALineClampChangeRedrawsTheTiles
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  NSArray<UIView *> *tiles = ENRMTiles(segment.textView);
  XCTAssertGreaterThan(tiles.count, 0u);
  for (UIView *tile in tiles) {
    [tile.layer displayIfNeeded];
  }
  segment.textView.textContainer.maximumNumberOfLines = 2;
  segment.textView.textContainer.lineBreakMode = NSLineBreakByTruncatingMiddle;
  [segment.textView layoutIfNeeded];
  for (UIView *tile in tiles) {
    XCTAssertTrue(tile.layer.needsDisplay);
  }
}

// Dark mode: the tiles draw again, as UIKit's canvas would.
- (void)testAnAppearanceChangeRedrawsTheTiles
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  NSArray<UIView *> *tiles = ENRMTiles(segment.textView);
  XCTAssertGreaterThan(tiles.count, 0u);
  for (UIView *tile in tiles) {
    [tile.layer displayIfNeeded];
    XCTAssertFalse(tile.layer.needsDisplay);
  }
  _window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
  [_window layoutIfNeeded];
  for (UIView *tile in tiles) {
    XCTAssertTrue(tile.layer.needsDisplay);
  }
}

// A streaming effect redraws the tiles holding the text's end, not the ones above.
- (void)testAStreamingEffectRedrawsTheTileHoldingTheEnd
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  _scrollView.contentOffset = CGPointMake(0, segment.bounds.size.height - kWindowHeight);
  [segment layoutIfNeeded];
  NSArray<UIView *> *tiles = [ENRMTiles(segment.textView) sortedArrayUsingComparator:^(UIView *a, UIView *b) {
    return [@([a convertRect:a.bounds toView:nil].origin.y) compare:@([b convertRect:b.bounds toView:nil].origin.y)];
  }];
  XCTAssertGreaterThan(tiles.count, 1u);
  for (UIView *tile in tiles) {
    [tile.layer displayIfNeeded];
  }
  ENRMMarkdownTextView *textView = (ENRMMarkdownTextView *)segment.textView;
  NSUInteger length = textView.textStorage.length;
  [textView.streamingEffects configureType:ENRMStreamingEffectGradient
                                  duration:0.2
                                    length:20
                                startColor:nil
                                  endColor:nil];
  [textView.streamingEffects noteArrivalIn:textView.textStorage.string
                                      from:length - 40
                                        to:length
                                        at:CACurrentMediaTime()];
  [textView streamingEffectsChanged];
  [textView layoutIfNeeded];
  XCTAssertTrue(tiles.lastObject.layer.needsDisplay);
  XCTAssertFalse(tiles.firstObject.layer.needsDisplay);
}

- (void)testMeasurementAndAccessibilityCoverTheWholeText
{
  NSString *markdown = ENRMParagraphs(200);
  EnrichedMarkdownInternalText *sliced = [self segmentWithMarkdown:markdown onScreen:YES];
  EnrichedMarkdownInternalText *whole = [self segmentWithMarkdown:markdown onScreen:NO];
  XCTAssertLessThan(ENRMDrawnRect(sliced.textView).size.height, sliced.bounds.size.height);

  XCTAssertTrue(CGSizeEqualToSize([sliced measureSize:kWidth], [whole measureSize:kWidth]));

  NSArray *slicedElements = sliced.accessibilityElements;
  NSArray *wholeElements = whole.accessibilityElements;
  XCTAssertEqual(slicedElements.count, wholeElements.count);
  XCTAssertGreaterThan(slicedElements.count, 200u);
  for (NSUInteger i = 0; i < slicedElements.count; i++) {
    CGRect slicedFrame = [slicedElements[i] accessibilityFrameInContainerSpace];
    CGRect wholeFrame = [wholeElements[i] accessibilityFrameInContainerSpace];
    XCTAssertTrue(CGRectEqualToRect(slicedFrame, wholeFrame), @"element %lu: %@ vs %@", (unsigned long)i,
                  NSStringFromCGRect(slicedFrame), NSStringFromCGRect(wholeFrame));
  }
}

// Measuring at the width shown keeps the container, and with it the layout.
- (void)testMeasuringKeepsTheTextViewsLayout
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  CGSize containerSize = segment.textView.textContainer.size;
  [segment measureSize:kWidth];
  XCTAssertTrue(CGSizeEqualToSize(segment.textView.textContainer.size, containerSize));
}

- (void)testATextInsideTheDrawnAreaIsDrawnWhole
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(4) onScreen:YES];
  XCTAssertLessThan(segment.bounds.size.height, kWindowHeight);
  XCTAssertTrue(CGRectEqualToRect(ENRMDrawnRect(segment.textView), segment.bounds));
}

// Off screen, a text draws nothing; back on screen, the part shown.
- (void)testALongTextScrolledAwayDrawsNothing
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  CGFloat height = segment.bounds.size.height;
  _scrollView.contentSize = CGSizeMake(kWidth, height + kWindowHeight * 3);
  _scrollView.contentOffset = CGPointMake(0, height + kWindowHeight * 2);
  XCTAssertEqual(ENRMTiles(segment.textView).count, 0u);

  _scrollView.contentOffset = CGPointMake(0, height - kWindowHeight);
  XCTAssertEqual(CGRectGetMaxY(ENRMDrawnRect(segment.textView)), height);
}

- (void)testAShortTextOffScreenDrawsNothing
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(4) onScreen:YES];
  _scrollView.contentSize = CGSizeMake(kWidth, kWindowHeight * 4);
  _scrollView.contentOffset = CGPointMake(0, kWindowHeight * 3);
  XCTAssertEqual(ENRMTiles(segment.textView).count, 0u);

  _scrollView.contentOffset = CGPointZero;
  XCTAssertTrue(CGRectEqualToRect(ENRMDrawnRect(segment.textView), segment.bounds));
}

// An edit at the end redraws the tiles from its line down, not the ones above it.
- (void)testAnEditRedrawsTheTilesFromItsLine
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  CGFloat height = segment.bounds.size.height;
  _scrollView.contentOffset = CGPointMake(0, height - kWindowHeight);
  NSArray<UIView *> *tiles = ENRMTiles(segment.textView);
  XCTAssertGreaterThan(tiles.count, 2u);
  for (UIView *tile in tiles) {
    [tile.layer displayIfNeeded];
  }

  NSTextStorage *storage = segment.textView.textStorage;
  [segment applyAttributedTextPatch:[[NSAttributedString alloc] initWithString:@" more"] from:storage.length];
  [segment.textView layoutIfNeeded];
  XCTAssertFalse(tiles.firstObject.layer.needsDisplay);
  XCTAssertTrue(tiles.lastObject.layer.needsDisplay);
}

// The streaming fade recolors the tail inside an editing session: no glyph may be generated then.
- (void)testAnAttributeEditRedrawsItsTile
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  CGFloat height = segment.bounds.size.height;
  _scrollView.contentOffset = CGPointMake(0, height - kWindowHeight);
  NSArray<UIView *> *tiles = ENRMTiles(segment.textView);
  for (UIView *tile in tiles) {
    [tile.layer displayIfNeeded];
  }

  NSTextStorage *storage = segment.textView.textStorage;
  [storage beginEditing];
  [storage addAttribute:NSForegroundColorAttributeName
                  value:[UIColor redColor]
                  range:NSMakeRange(storage.length - 10, 10)];
  [segment.textView.layoutManager invalidateDisplayForCharacterRange:NSMakeRange(storage.length - 10, 10)];
  [storage endEditing];
  [segment.textView layoutIfNeeded];
  XCTAssertFalse(tiles.firstObject.layer.needsDisplay);
  XCTAssertTrue(tiles.lastObject.layer.needsDisplay);
}

// An image that settles asks the layout manager to redraw its characters outside any edit, after
// its tile was drawn.
- (void)testADisplayInvalidationRedrawsItsTile
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  CGFloat height = segment.bounds.size.height;
  _scrollView.contentOffset = CGPointMake(0, height - kWindowHeight);
  NSArray<UIView *> *tiles = ENRMTiles(segment.textView);
  for (UIView *tile in tiles) {
    [tile.layer displayIfNeeded];
  }

  NSUInteger length = segment.textView.textStorage.length;
  [segment.textView.layoutManager invalidateDisplayForCharacterRange:NSMakeRange(length - 10, 10)];
  [segment.textView layoutIfNeeded];
  XCTAssertFalse(tiles.firstObject.layer.needsDisplay);
  XCTAssertTrue(tiles.lastObject.layer.needsDisplay);
}

// A streamed text grows at the end: the lines above keep their layout (a text container resize
// would drop it all).
- (void)testGrowingKeepsTheLayout
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  CGFloat height = segment.bounds.size.height;
  _scrollView.contentOffset = CGPointMake(0, height - kWindowHeight);
  UITextView *textView = segment.textView;
  NSLayoutManager *layoutManager = textView.layoutManager;
  [layoutManager ensureLayoutForTextContainer:textView.textContainer];
  NSUInteger length = textView.textStorage.length;

  CGFloat grown = height + 1200;
  segment.frame = CGRectMake(0, 0, kWidth, grown);
  [segment layoutIfNeeded];
  XCTAssertEqual(textView.textContainer.size.height, CGFLOAT_MAX);
  XCTAssertEqual(layoutManager.firstUnlaidCharacterIndex, length);
}

// UIKit sizes a text view's container to its frame on every frame change, which would drop the
// layout of a growing text each time.
- (void)testAFrameChangeLeavesTheContainerAlone
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  UITextView *textView = segment.textView;
  CGSize containerSize = textView.textContainer.size;
  textView.frame = CGRectInset(textView.frame, 0, 100);
  XCTAssertTrue(CGSizeEqualToSize(textView.textContainer.size, containerSize));
}

- (void)testSpoilerOverlaysStayAcrossScrolling
{
  EnrichedMarkdownInternalText *segment = [[EnrichedMarkdownInternalText alloc] initWithConfig:_config];
  NSMutableAttributedString *text = ENRMRenderMarkdown(ENRMParagraphs(200), _config);
  NSRange paragraph = [text.string rangeOfString:@"Paragraph 100 runs"];
  [text addAttribute:SpoilerAttributeName value:@YES range:paragraph];
  [segment applyAttributedText:text context:nil];
  CGFloat height = [segment measureHeight:kWidth];
  segment.frame = CGRectMake(0, 0, kWidth, height);
  _scrollView.contentSize = CGSizeMake(kWidth, height);
  [_scrollView addSubview:segment];
  [segment layoutIfNeeded];

  NSArray<UIView *> * (^overlays)(void) = ^{
    NSMutableArray<UIView *> *found = [NSMutableArray array];
    for (UIView *subview in segment.textView.subviews) {
      if ([subview isKindOfClass:[ENRMSpoilerOverlayView class]]) {
        [found addObject:subview];
      }
    }
    return found;
  };
  UITextView *textView = segment.textView;
  CGFloat paragraphY =
      [textView.layoutManager boundingRectForGlyphRange:[textView.layoutManager glyphRangeForCharacterRange:paragraph
                                                                                       actualCharacterRange:NULL]
                                        inTextContainer:textView.textContainer]
          .origin.y;
  _scrollView.contentOffset = CGPointMake(0, paragraphY - 300);
  NSArray<UIView *> *before = overlays();
  XCTAssertGreaterThan(before.count, 0u);
  CGRect drawnBefore = ENRMDrawnRect(textView);

  _scrollView.contentOffset = CGPointMake(0, paragraphY - 300 + 512);
  XCTAssertFalse(CGRectEqualToRect(ENRMDrawnRect(textView), drawnBefore));
  XCTAssertEqualObjects(overlays(), before);
}

// UIKit places the selection, its handles and the caret from the text view's own geometry: on the
// drawn text.
- (void)testSelectionGeometryIsOnTheDrawnText
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  _scrollView.contentOffset = CGPointMake(0, round(segment.bounds.size.height / 2));
  UITextView *textView = segment.textView;
  XCTAssertGreaterThan(CGRectGetMinY(ENRMDrawnRect(textView)), 0);

  NSRange word = [textView.text rangeOfString:@"Paragraph 120 runs"];
  NSRange glyphs = [textView.layoutManager glyphRangeForCharacterRange:word actualCharacterRange:NULL];
  CGRect inText = [textView.layoutManager boundingRectForGlyphRange:glyphs inTextContainer:textView.textContainer];
  UITextPosition *start = [textView positionFromPosition:textView.beginningOfDocument offset:word.location];
  UITextPosition *end = [textView positionFromPosition:start offset:word.length];
  CGRect selection = [textView firstRectForRange:[textView textRangeFromPosition:start toPosition:end]];
  CGRect inSegment = [textView convertRect:selection toView:segment];
  XCTAssertEqualWithAccuracy(CGRectGetMinY(inSegment), CGRectGetMinY(inText), 2);
  XCTAssertEqualWithAccuracy(CGRectGetMinX(inSegment), CGRectGetMinX(inText), 2);
}

// UIKit resizes its canvas on frame and text changes; it stays empty.
- (void)testTheCanvasStaysEmptyAcrossChanges
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  UITextView *textView = segment.textView;
  UIView *canvas = ENRMSubviewOfClass(ENRMSubviewOfClass(textView, @"_UITextContainerView"), @"_UITextViewCanvasView");
  XCTAssertNotNil(canvas);
  segment.frame = CGRectMake(0, 0, kWidth, segment.bounds.size.height + 300);
  [segment layoutIfNeeded];
  XCTAssertEqual(canvas.frame.size.height, 0);
  [segment applyAttributedTextPatch:[[NSAttributedString alloc] initWithString:@" more"]
                               from:textView.textStorage.length];
  [segment layoutIfNeeded];
  XCTAssertEqual(canvas.frame.size.height, 0);
  [segment applyAttributedText:ENRMRenderMarkdown(ENRMParagraphs(150), _config) context:nil];
  [segment layoutIfNeeded];
  XCTAssertEqual(canvas.frame.size.height, 0);
}

// Dragging a selection handle maps the finger through the text container view: on the text.
- (void)testATouchInTheMiddleHitsTheTextUnderIt
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  CGFloat offset = round(segment.bounds.size.height / 2);
  _scrollView.contentOffset = CGPointMake(0, offset);
  UITextView *textView = segment.textView;
  CGPoint point = CGPointMake(40, offset + kWindowHeight / 2);
  UITextPosition *position = [textView closestPositionToPoint:point];
  NSInteger index = [textView offsetFromPosition:textView.beginningOfDocument toPosition:position];
  NSUInteger expected = [textView.layoutManager characterIndexForPoint:point
                                                       inTextContainer:textView.textContainer
                              fractionOfDistanceBetweenInsertionPoints:NULL];
  XCTAssertEqualWithAccuracy((double)index, (double)expected, 1);
  UIView *container = ENRMSubviewOfClass(textView, @"_UITextContainerView");
  CGPoint inContainer = [textView convertPoint:point toView:container];
  XCTAssertTrue(CGRectContainsPoint(container.bounds, inContainer));
}

// Out of the window a text draws nothing, and drops what it drew; back in, the part on screen.
- (void)testATextOutOfTheWindowDrawsNothing
{
  EnrichedMarkdownInternalText *segment = [self segmentWithMarkdown:ENRMParagraphs(200) onScreen:YES];
  XCTAssertGreaterThan(ENRMTiles(segment.textView).count, 0u);
  [segment removeFromSuperview];
  XCTAssertEqual(ENRMTiles(segment.textView).count, 0u);

  [_scrollView addSubview:segment];
  [segment layoutIfNeeded];
  CGRect drawn = ENRMDrawnRect(segment.textView);
  XCTAssertEqual(CGRectGetMinY(drawn), 0);
  XCTAssertLessThan(CGRectGetMaxY(drawn), kWindowHeight * 2.5);
}

@end
