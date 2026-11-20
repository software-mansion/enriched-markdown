#import "../../ios/utils/ENRMHighlightCoordinator.h"
#import "../../ios/utils/ENRMTextViewSetup.h"
#import "../../ios/utils/TextViewLayoutManager.h"
#import <XCTest/XCTest.h>

@interface ENRMHighlightTestBlock : UIView <ENRMRenderedTextProviding>
@end

@implementation ENRMHighlightTestBlock

- (NSString *)renderedText
{
  return @"let x = 1";
}

- (NSString *)renderedTextKind
{
  return @"code";
}

@end

static UITextView *ENRMHighlightTextView(NSString *text, CGRect frame)
{
  UITextView *textView = [[UITextView alloc] initWithFrame:frame];
  textView.textContainerInset = UIEdgeInsetsZero;
  textView.textContainer.lineFragmentPadding = 0;
  ENRMAttachLayoutManager(textView, nil);
  textView.attributedText =
      [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:16]}];
  return textView;
}

static ENRMTextHighlight *ENRMHighlight(NSUInteger start, NSUInteger end)
{
  return [[ENRMTextHighlight alloc] initWithRange:NSMakeRange(start, end - start)
                                            color:UIColor.yellowColor
                                     borderRadius:0
                                          padding:0];
}

@interface ENRMHighlightCoordinatorTests : XCTestCase
@end

@implementation ENRMHighlightCoordinatorTests

- (void)testJoinsBlocksIntoOneRenderedText
{
  UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
  ENRMHighlightCoordinator *coordinator = [[ENRMHighlightCoordinator alloc] initWithHost:host];
  UITextView *first = ENRMHighlightTextView(@"Hello world", CGRectMake(0, 0, 300, 40));
  ENRMHighlightTestBlock *code = [[ENRMHighlightTestBlock alloc] initWithFrame:CGRectMake(0, 40, 300, 40)];
  UIView *other = [[UIView alloc] init];

  NSArray<UIView *> *views = @[ first, other, code ];
  XCTAssertTrue([coordinator setBlockViews:views]);

  XCTAssertEqualObjects(coordinator.renderedText, @"Hello world\nlet x = 1");
  NSArray<ENRMRenderedTextBlock *> *blocks = coordinator.renderedBlocks;
  XCTAssertEqual(blocks.count, (NSUInteger)2);
  ENRMRenderedTextBlock *codeBlock = blocks.lastObject;
  XCTAssertEqual(codeBlock.start, (NSInteger)12);
  XCTAssertEqual(codeBlock.end, (NSInteger)21);
  XCTAssertEqualObjects(codeBlock.kind, @"code");
  NSArray<UIView *> *sameViews = @[ first, code ];
  XCTAssertFalse([coordinator setBlockViews:sameViews]);
}

- (void)testSplitsHighlightsIntoEachTextView
{
  UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
  ENRMHighlightCoordinator *coordinator = [[ENRMHighlightCoordinator alloc] initWithHost:host];
  UITextView *first = ENRMHighlightTextView(@"Hello world", CGRectMake(0, 0, 300, 40));
  UITextView *second = ENRMHighlightTextView(@"Second line", CGRectMake(0, 40, 300, 40));
  [coordinator setBlockViews:@[ first, second ]];

  coordinator.highlights = @[ ENRMHighlight(6, 18) ];

  TextViewLayoutManager *firstManager = (TextViewLayoutManager *)first.layoutManager;
  TextViewLayoutManager *secondManager = (TextViewLayoutManager *)second.layoutManager;
  NSArray<ENRMTextHighlight *> *firstHighlights = firstManager.textHighlights;
  NSArray<ENRMTextHighlight *> *secondHighlights = secondManager.textHighlights;
  XCTAssertEqual(firstHighlights.count, (NSUInteger)1);
  XCTAssertTrue(NSEqualRanges(firstHighlights.firstObject.range, NSMakeRange(6, 5)));
  XCTAssertEqual(secondHighlights.count, (NSUInteger)1);
  XCTAssertTrue(NSEqualRanges(secondHighlights.firstObject.range, NSMakeRange(0, 6)));

  coordinator.highlights = @[];
  XCTAssertEqual(firstManager.textHighlights.count, (NSUInteger)0);
  XCTAssertEqual(secondManager.textHighlights.count, (NSUInteger)0);
}

- (void)testReportsEachHighlightOnceUntilItMoves
{
  UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
  UITextView *textView = ENRMHighlightTextView(@"Hello world", CGRectMake(0, 20, 300, 40));
  [host addSubview:textView];
  ENRMHighlightCoordinator *coordinator = [[ENRMHighlightCoordinator alloc] initWithHost:host];
  [coordinator setBlockViews:@[ textView ]];
  NSMutableArray<NSArray<ENRMHighlightRect *> *> *reports = [NSMutableArray array];
  coordinator.onLayout = ^(NSArray<ENRMHighlightRect *> *rects) { [reports addObject:rects]; };

  coordinator.highlights = @[ ENRMHighlight(0, 5), ENRMHighlight(6, 11) ];
  [coordinator reportLayout];

  XCTAssertEqual(reports.count, (NSUInteger)1);
  NSArray<ENRMHighlightRect *> *firstReport = reports.firstObject;
  XCTAssertEqual(firstReport.count, (NSUInteger)2);
  CGRect hello = firstReport.firstObject.rect;
  CGRect world = firstReport.lastObject.rect;
  XCTAssertEqualWithAccuracy(hello.origin.y, 20, 1);
  XCTAssertGreaterThan(world.origin.x, CGRectGetMaxX(hello));

  textView.frame = CGRectOffset(textView.frame, 0, 30);
  [coordinator reportLayout];
  XCTAssertEqual(reports.count, (NSUInteger)2);
  CGFloat movedY = reports.lastObject.firstObject.rect.origin.y;
  XCTAssertEqualWithAccuracy(movedY, 50, 1);
}

@end
