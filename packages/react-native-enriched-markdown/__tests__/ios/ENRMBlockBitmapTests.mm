#import "../../ios/EnrichedMarkdown.h"
#import "../../ios/styles/StyleConfig.h"
#import <XCTest/XCTest.h>

static const CGFloat kENRMBlockTestWidth = 390;
static const CGFloat kENRMBlockTestWindowHeight = 844;

// What layoutSubviews runs once Fabric gave the view its content frame.
@interface EnrichedMarkdown (ENRMBlockBitmapTesting)
- (CGSize)computeSegmentLayoutForWidth:(CGFloat)width applyFrames:(BOOL)applyFrames;
@end

static NSString *ENRMBlockTestMarkdown(void)
{
  NSString *block = @"```\nlet answer = 42\n```\n\n| a | b |\n|---|---|\n| 1 | 2 |";
  NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithObject:block];
  for (NSUInteger i = 0; i < 200; i++) {
    [parts addObject:[NSString stringWithFormat:@"Paragraph %lu runs over a few lines of the view so that the "
                                                @"document gets long, as a long answer does.",
                                                (unsigned long)i]];
  }
  [parts addObject:block];
  return [parts componentsJoinedByString:@"\n\n"];
}

// By name: the views that draw their own bitmap (ENRMDroppableContent).
static void ENRMCollectBitmapViews(UIView *view, NSMutableArray<UIView *> *views)
{
  static NSSet<NSString *> *names;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    names =
        [NSSet setWithArray:@[ @"ENRMCodeBlockContainerView", @"ENRMCodeBlockContentView", @"ENRMTableIOSGridView" ]];
  });
  if ([names containsObject:NSStringFromClass([view class])]) {
    [views addObject:view];
  }
  for (UIView *subview in view.subviews) {
    ENRMCollectBitmapViews(subview, views);
  }
}

static NSArray<UIView *> *ENRMBitmapViews(NSArray<UIView *> *segments)
{
  NSMutableArray<UIView *> *views = [NSMutableArray array];
  for (UIView *segment in segments) {
    ENRMCollectBitmapViews(segment, views);
  }
  return views;
}

// What Core Animation's commit does to a view that needs display.
static void ENRMDrawBitmaps(NSArray<UIView *> *views)
{
  for (UIView *view in views) {
    [view.layer setNeedsDisplay];
    [view.layer displayIfNeeded];
  }
}

@interface ENRMBlockBitmapTests : XCTestCase
@end

@implementation ENRMBlockBitmapTests {
  UIWindow *_window;
  UIScrollView *_scrollView;
  EnrichedMarkdown *_document;
  // The code block and the table above the text, and the ones below it.
  NSArray<UIView *> *_topBlocks;
  NSArray<UIView *> *_bottomBlocks;
}

- (void)setUp
{
  _window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, kENRMBlockTestWidth, kENRMBlockTestWindowHeight)];
  _window.hidden = NO;
  _scrollView = [[UIScrollView alloc] initWithFrame:_window.bounds];
  [_window addSubview:_scrollView];
  [self showDocument:[self documentInScrollView:_scrollView]];
}

- (void)showDocument:(EnrichedMarkdown *)document
{
  [_document removeFromSuperview];
  _document = document;
  NSMutableArray<UIView *> *blocks = [NSMutableArray array];
  for (UIView *subview in document.subviews) {
    NSString *name = NSStringFromClass([subview class]);
    if ([name isEqualToString:@"ENRMCodeBlockContainerView"] || [name isEqualToString:@"TableContainerView"]) {
      [blocks addObject:subview];
    }
  }
  XCTAssertEqual(blocks.count, 4u);
  _topBlocks = [blocks subarrayWithRange:NSMakeRange(0, 2)];
  _bottomBlocks = [blocks subarrayWithRange:NSMakeRange(2, 2)];
}

- (void)tearDown
{
  _window.hidden = YES;
  _window = nil;
}

- (EnrichedMarkdown *)documentInScrollView:(UIScrollView *)scrollView
{
  EnrichedMarkdown *document = [[EnrichedMarkdown alloc] initWithFrame:CGRectMake(0, 0, kENRMBlockTestWidth, 0)];
  document.config = [[StyleConfig alloc] init];
  [scrollView addSubview:document];
  [document renderMarkdownSynchronously:ENRMBlockTestMarkdown()];
  CGSize size = [document computeSegmentLayoutForWidth:kENRMBlockTestWidth applyFrames:YES];
  document.frame = CGRectMake(0, 0, kENRMBlockTestWidth, size.height);
  scrollView.contentSize = CGSizeMake(kENRMBlockTestWidth, size.height);
  [document layoutIfNeeded];
  return document;
}

- (void)scrollToTheEnd
{
  _scrollView.contentOffset = CGPointMake(0, _document.bounds.size.height - kENRMBlockTestWindowHeight);
}

- (void)testABlockScrolledPastTheMarginDropsItsBitmap
{
  XCTAssertGreaterThan(_document.bounds.size.height, kENRMBlockTestWindowHeight * 4);
  NSArray<UIView *> *views = ENRMBitmapViews(_topBlocks);
  XCTAssertEqual(views.count, 3u);
  ENRMDrawBitmaps(views);
  for (UIView *view in views) {
    XCTAssertNotNil(view.layer.contents, @"%@", view);
  }

  [self scrollToTheEnd];
  for (UIView *view in views) {
    XCTAssertNil(view.layer.contents, @"%@", view);
  }
}

- (void)testABlockScrolledBackNearDrawsAgain
{
  NSArray<UIView *> *views = ENRMBitmapViews(_topBlocks);
  ENRMDrawBitmaps(views);
  [self scrollToTheEnd];

  _scrollView.contentOffset = CGPointZero;
  for (UIView *view in views) {
    XCTAssertTrue(view.layer.needsDisplay, @"%@", view);
    [view.layer displayIfNeeded];
    XCTAssertNotNil(view.layer.contents, @"%@", view);
  }
}

// A block just below the screen, within the margin, keeps its bitmap for when it scrolls in.
- (void)testABlockWithinTheMarginKeepsItsBitmap
{
  NSArray<UIView *> *views = ENRMBitmapViews(_bottomBlocks);
  [self scrollToTheEnd];
  ENRMDrawBitmaps(views);
  CGFloat blocksTop = CGRectGetMinY(_bottomBlocks.firstObject.frame);
  _scrollView.contentOffset = CGPointMake(0, blocksTop - kENRMBlockTestWindowHeight - 100);
  for (UIView *view in views) {
    XCTAssertNotNil(view.layer.contents, @"%@", view);
  }
}

// A new block draws when the run loop turn commits, after the document dropped what it had not drawn
// yet: it drops that too.
- (void)testABlockCreatedOffScreenStaysEmptyAfterARunLoopTurn
{
  // Made here, so that no run loop turn ran since.
  [self showDocument:[self documentInScrollView:_scrollView]];
  NSArray<UIView *> *views = ENRMBitmapViews(_bottomBlocks);
  XCTAssertEqual(views.count, 3u);
  // Drawn by hand: a test's run loop turn commits without drawing, so this checks that the drop
  // runs in that turn, not that it follows Core Animation's commit.
  ENRMDrawBitmaps(views);
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
  for (UIView *view in views) {
    XCTAssertNil(view.layer.contents, @"%@", view);
  }

  [self scrollToTheEnd];
  for (UIView *view in views) {
    XCTAssertTrue(view.layer.needsDisplay, @"%@", view);
  }
}

// While the document is in a window its visible area holds the scroll views above it, which hold the
// document: leaving the window lets them go.
- (void)testLeavingTheWindowReleasesTheScrollViews
{
  __weak UIScrollView *weakScrollView;
  @autoreleasepool {
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:_window.bounds];
    [_window addSubview:scrollView];
    [self documentInScrollView:scrollView];
    weakScrollView = scrollView;
    [scrollView removeFromSuperview];
  }
  XCTAssertNil(weakScrollView);
}

@end
