#include "../../../core/cpp/parser/DocumentStore.hpp"
#import "../../ios/internals/ENRMBlockSlotMeasurer.h"
#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/segments/ENRMSegmentHeightMeasurer.h"
#import "../../ios/segments/RenderedMarkdownSegment.h"
#import "../../ios/segments/SegmentRenderer.h"
#import "../../ios/styles/StyleConfig.h"
#import <XCTest/XCTest.h>

// The view-free walk reserves a block slot's height where the block would have
// been, with the margins of the block it stands in for, and records the frame
// the shadow node places the React child at.
@interface ENRMBlockSlotStackingTests : XCTestCase
@end

@implementation ENRMBlockSlotStackingTests

// The id the JS collector hands out for the first block of `markdown`.
static NSString *ENRMFirstSlotId(NSString *markdown)
{
  auto document = Markdown::DocumentStore::shared().parse(std::string(markdown.UTF8String), {}, true);
  return @(document->blocks.slots.front().id.c_str());
}

- (NSArray<ENRMRenderedSegment *> *)segmentsFor:(NSString *)markdown
                                         config:(StyleConfig *)config
                                        slotIds:(NSSet<NSString *> *)slotIds
{
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init] parseMarkdown:markdown
                                                                    flags:[ENRMMd4cFlags defaultFlags]
                                                                    isGFM:YES
                                                                linkRegex:nil
                                                      inlineCodeLinkRegex:nil
                                                       activeBlockSlotIds:slotIds
                                                           annotateImages:NO];
  return ENRMRenderSegmentsFromAST(ast, config, NO, YES, 0, NSLineBreakStrategyStandard, NO);
}

- (void)testActiveSlotReservesItsHeightAndRecordsItsFrame
{
  StyleConfig *config = [[StyleConfig alloc] init];
  NSString *markdown = @"Intro paragraph.\n\n![Hero](https://e.com/a.png)\n\nAfter.";
  NSString *slotId = ENRMFirstSlotId(markdown);

  NSArray *segments = [self segmentsFor:markdown config:config slotIds:[NSSet setWithObject:slotId]];
  NSUInteger slotSegments = 0;
  for (ENRMRenderedSegment *segment in segments) {
    if (segment.kind == ENRMSegmentKindBlockSlot) {
      slotSegments++;
      XCTAssertEqualObjects(segment.blockSlotSegment.slotId, slotId);
      XCTAssertEqual(segment.blockSlotSegment.kind, ENRMBlockSlotKindImage);
    }
  }
  XCTAssertEqual(slotSegments, 1u, @"the stamped image paragraph becomes one slot segment");

  const CGFloat width = 320;
  const CGFloat childHeight = 100;
  ENRMBlockSlotMeasurer *measurer = [[ENRMBlockSlotMeasurer alloc] initWithSlotIds:[NSSet setWithObject:slotId]
                                                                           measure:^CGFloat(NSString *id, CGFloat w) {
                                                                             XCTAssertEqual(w, width);
                                                                             return childHeight;
                                                                           }];
  CGFloat withSlot = ENRMMeasureSegmentsHeightViewFree(
      segments, config, width, NO, 2, ENRMWritingDirectionModeFirstStrong, NSWritingDirectionLeftToRight, YES,
      NSLineBreakStrategyStandard, nil, measurer, CGPointZero);

  NSValue *frameValue = measurer.frames[slotId];
  XCTAssertNotNil(frameValue, @"the walk records where the slot landed");
  CGRect frame = frameValue.CGRectValue;
  XCTAssertEqual(frame.size.width, width);
  XCTAssertEqual(frame.size.height, childHeight);
  XCTAssertGreaterThan(frame.origin.y, 0, @"the slot sits below the intro paragraph");
  XCTAssertEqualWithAccuracy(frame.origin.y,
                             [self heightOf:@"Intro paragraph." config:config width:width] + config.imageMarginTop, 0.5,
                             @"placed after the paragraph plus the image's top margin");
  XCTAssertGreaterThanOrEqual(withSlot, frame.origin.y + childHeight + config.imageMarginBottom);
}

- (void)testInactiveSlotStaysNativeAndRecordsNoFrame
{
  StyleConfig *config = [[StyleConfig alloc] init];
  NSString *markdown = @"![Hero](https://e.com/a.png)\n";
  NSArray *segments = [self segmentsFor:markdown config:config slotIds:[NSSet set]];
  for (ENRMRenderedSegment *segment in segments) {
    XCTAssertNotEqual(segment.kind, ENRMSegmentKindBlockSlot, @"nothing is stamped without an active id");
  }
  ENRMBlockSlotMeasurer *measurer =
      [[ENRMBlockSlotMeasurer alloc] initWithSlotIds:[NSSet set]
                                             measure:^CGFloat(NSString *id, CGFloat w) { return 100; }];
  ENRMMeasureSegmentsHeightViewFree(segments, config, 320, NO, 2, ENRMWritingDirectionModeFirstStrong,
                                    NSWritingDirectionLeftToRight, YES, NSLineBreakStrategyStandard, nil, measurer,
                                    CGPointZero);
  XCTAssertEqual(measurer.frames.count, 0u);
}

- (void)testLinkSlotTakesParagraphMargins
{
  StyleConfig *config = [[StyleConfig alloc] init];
  NSString *slotId = ENRMFirstSlotId(@"[Q3 report.pdf](https://e.com/q3.pdf)\n");
  NSArray *segments = [self segmentsFor:@"[Q3 report.pdf](https://e.com/q3.pdf)\n"
                                 config:config
                                slotIds:[NSSet setWithObject:slotId]];
  XCTAssertEqual(segments.count, 1u);
  XCTAssertEqual(((ENRMRenderedSegment *)segments[0]).blockSlotSegment.kind, ENRMBlockSlotKindLink);
  ENRMBlockSlotMeasurer *measurer =
      [[ENRMBlockSlotMeasurer alloc] initWithSlotIds:[NSSet setWithObject:slotId]
                                             measure:^CGFloat(NSString *id, CGFloat w) { return 50; }];
  CGFloat height = ENRMMeasureSegmentsHeightViewFree(segments, config, 320, YES, 2, ENRMWritingDirectionModeFirstStrong,
                                                     NSWritingDirectionLeftToRight, YES, NSLineBreakStrategyStandard,
                                                     nil, measurer, CGPointZero);
  XCTAssertEqualWithAccuracy(height, config.paragraphMarginTop + 50 + config.paragraphMarginBottom, 0.5);
  XCTAssertEqualWithAccuracy(measurer.frames[slotId].CGRectValue.origin.y, config.paragraphMarginTop, 0.5);
}

- (void)testCodeSlotTakesCodeBlockMargins
{
  StyleConfig *config = [[StyleConfig alloc] init];
  NSString *markdown = @"```mermaid\ngraph TD\n```\n";
  NSString *slotId = ENRMFirstSlotId(markdown);
  XCTAssertTrue([slotId hasPrefix:@"code:"]);
  NSArray *segments = [self segmentsFor:markdown config:config slotIds:[NSSet setWithObject:slotId]];
  XCTAssertEqual(segments.count, 1u);
  XCTAssertEqual(((ENRMRenderedSegment *)segments[0]).kind, ENRMSegmentKindBlockSlot,
                 @"the stamped code block is a slot, not a native code block");
  XCTAssertEqual(((ENRMRenderedSegment *)segments[0]).blockSlotSegment.kind, ENRMBlockSlotKindCode);
  ENRMBlockSlotMeasurer *measurer =
      [[ENRMBlockSlotMeasurer alloc] initWithSlotIds:[NSSet setWithObject:slotId]
                                             measure:^CGFloat(NSString *id, CGFloat w) { return 50; }];
  CGFloat height = ENRMMeasureSegmentsHeightViewFree(segments, config, 320, YES, 2, ENRMWritingDirectionModeFirstStrong,
                                                     NSWritingDirectionLeftToRight, YES, NSLineBreakStrategyStandard,
                                                     nil, measurer, CGPointZero);
  XCTAssertEqualWithAccuracy(height, config.codeBlockMarginTop + 50 + config.codeBlockMarginBottom, 0.5);
  XCTAssertEqualWithAccuracy(measurer.frames[slotId].CGRectValue.origin.y, config.codeBlockMarginTop, 0.5);
}

- (CGFloat)heightOf:(NSString *)markdown config:(StyleConfig *)config width:(CGFloat)width
{
  NSArray *segments = [self segmentsFor:markdown config:config slotIds:[NSSet set]];
  return ENRMMeasureSegmentsHeightViewFree(segments, config, width, NO, 2, ENRMWritingDirectionModeFirstStrong,
                                           NSWritingDirectionLeftToRight, YES, NSLineBreakStrategyStandard, nil, nil,
                                           CGPointZero);
}

@end
