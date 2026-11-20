#include "../../../core/cpp/parser/DocumentStore.hpp"
#import "../../ios/internals/ENRMBlockSlotMeasurer.h"
#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/segments/ENRMBlockquoteContainerView.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ParagraphStyleUtils.h"
#import <XCTest/XCTest.h>

@interface ENRMBlockquoteDirectionTests : XCTestCase
@property (nonatomic, strong) StyleConfig *config;
@end

@implementation ENRMBlockquoteDirectionTests

static MarkdownASTNode *ENRMQuoteDirectionNode(NSString *markdown, NSSet<NSString *> *slotIds)
{
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init] parseMarkdown:markdown
                                                                    flags:[ENRMMd4cFlags defaultFlags]
                                                                    isGFM:YES
                                                                linkRegex:nil
                                                      inlineCodeLinkRegex:nil
                                                       activeBlockSlotIds:slotIds
                                                           annotateImages:NO];
  for (MarkdownASTNode *child in ast.children) {
    if (child.type == MarkdownNodeTypeBlockquote || child.type == MarkdownNodeTypeAdmonition) {
      return child;
    }
  }
  return nil;
}

static NSString *ENRMQuoteDirectionSide(ENRMBlockquoteContainerView *quote)
{
  UIEdgeInsets insets = quote.contentInsets;
  if (insets.left == insets.right) {
    return @"none";
  }
  return insets.left > insets.right ? @"left" : @"right";
}

static ENRMBlockquoteContainerView *ENRMQuoteDirectionNested(ENRMBlockquoteContainerView *quote)
{
  for (RCTUIView *view in quote.segmentViews) {
    if ([view isKindOfClass:[ENRMBlockquoteContainerView class]]) {
      return (ENRMBlockquoteContainerView *)view;
    }
  }
  return nil;
}

- (void)setUp
{
  self.config = [[StyleConfig alloc] init];
  [self.config setBlockquoteBorderWidth:4];
  [self.config setBlockquoteGapWidth:8];
  [self.config setBlockquotePadding:12];
}

- (ENRMBlockquoteContainerView *)quote:(NSString *)markdown
                                  mode:(ENRMWritingDirectionMode)mode
                       layoutDirection:(NSWritingDirection)layoutDirection
{
  ENRMBlockquoteContainerView *quote = [[ENRMBlockquoteContainerView alloc] initWithConfig:self.config];
  ENRMSetWritingDirection(quote, mode, layoutDirection);
  quote.frame = CGRectMake(0, 0, 320, 1000);
  [self apply:markdown to:quote];
  return quote;
}

- (ENRMBlockquoteContainerView *)quote:(NSString *)markdown
{
  return [self quote:markdown mode:ENRMWritingDirectionModeFirstStrong layoutDirection:NSWritingDirectionLeftToRight];
}

- (void)apply:(NSString *)markdown to:(ENRMBlockquoteContainerView *)quote
{
  MarkdownASTNode *node = ENRMQuoteDirectionNode(markdown, nil);
  XCTAssertNotNil(node);
  [quote applyBlockquoteNode:node taskIndexOffset:0];
  [quote layoutIfNeeded];
}

- (void)testTheFirstStrongCharacterPutsTheBarOnItsSide
{
  XCTAssertEqualObjects(ENRMQuoteDirectionSide([self quote:@"> [!TIP]\n> A tip\n"]), @"left");
  XCTAssertEqualObjects(ENRMQuoteDirectionSide([self quote:@"> [!TIP]\n> نصيحة تساعدك\n"]), @"right");
  XCTAssertEqualObjects(ENRMQuoteDirectionSide([self quote:@"> [!TIP]\n> 2024\n>\n> نصيحة\n"]), @"right",
                        @"digits have no direction");
}

- (void)testNestedQuotesCountAndCodeBlocksDoNot
{
  XCTAssertEqualObjects(ENRMQuoteDirectionSide([self quote:@"> [!TIP]\n> > نصيحة\n"]), @"right");
  XCTAssertEqualObjects(ENRMQuoteDirectionSide([self quote:@"> [!TIP]\n> ```\n> npm i\n> ```\n> نصيحة\n"]), @"right");
}

- (void)testANestedQuoteTakesTheSideOfTheQuoteAroundIt
{
  ENRMBlockquoteContainerView *quote = [self quote:@"> [!TIP]\n> نصيحة\n>\n> > English\n"];
  XCTAssertEqualObjects(ENRMQuoteDirectionSide(quote), @"right");
  ENRMBlockquoteContainerView *nested = ENRMQuoteDirectionNested(quote);
  XCTAssertEqualObjects(ENRMQuoteDirectionSide(nested), @"right");

  [self apply:@"> [!TIP]\n> A tip\n>\n> > نصيحة\n" to:quote];
  XCTAssertEqual(ENRMQuoteDirectionNested(quote), nested);
  XCTAssertEqualObjects(ENRMQuoteDirectionSide(quote), @"left");
  XCTAssertEqualObjects(ENRMQuoteDirectionSide(ENRMQuoteDirectionNested(quote)), @"left");
}

- (void)testTheWritingDirectionModeDecidesBeforeTheText
{
  XCTAssertEqualObjects(ENRMQuoteDirectionSide([self quote:@"> نصيحة\n"
                                                      mode:ENRMWritingDirectionModeLTR
                                           layoutDirection:NSWritingDirectionRightToLeft]),
                        @"left");
  XCTAssertEqualObjects(ENRMQuoteDirectionSide([self quote:@"> A tip\n"
                                                      mode:ENRMWritingDirectionModeRTL
                                           layoutDirection:NSWritingDirectionLeftToRight]),
                        @"right");
  XCTAssertEqualObjects(ENRMQuoteDirectionSide([self quote:@"> 12345\n"
                                                      mode:ENRMWritingDirectionModeFirstStrong
                                           layoutDirection:NSWritingDirectionRightToLeft]),
                        @"right", @"without a strong character the layout decides");
}

- (void)testTheViewFreeMeasurementPicksTheSideOfTheView
{
  NSString *markdown = @"> نص عربي\n>\n> ![Hero](https://e.com/a.png)\n";
  auto document = Markdown::DocumentStore::shared().parse(std::string(markdown.UTF8String), {}, true);
  NSString *slotId = @(document->blocks.slots.front().id.c_str());
  NSSet<NSString *> *slotIds = [NSSet setWithObject:slotId];

  ENRMBlockSlotMeasurer *measurer =
      [[ENRMBlockSlotMeasurer alloc] initWithSlotIds:slotIds measure:^CGFloat(NSString *id, CGFloat w) { return 50; }];
  [ENRMBlockquoteContainerView measureHeightForBlockquoteNode:ENRMQuoteDirectionNode(markdown, slotIds)
                                                       config:self.config
                                                     maxWidth:320
                                             pointScaleFactor:2
                                             allowFontScaling:YES
                                            lineBreakStrategy:NSLineBreakStrategyStandard
                                         writingDirectionMode:ENRMWritingDirectionModeFirstStrong
                                      resolvedLayoutDirection:NSWritingDirectionLeftToRight
                                               outerDirection:NSWritingDirectionNatural
                                                   wrapCursor:nil
                                                 slotMeasurer:measurer
                                                       origin:CGPointZero];
  NSValue *frame = measurer.frames[slotId];
  XCTAssertNotNil(frame);

  ENRMBlockquoteContainerView *quote = [self quote:markdown];
  XCTAssertEqualWithAccuracy(frame.CGRectValue.origin.x, quote.contentInsets.left, 0.5);
  XCTAssertEqualWithAccuracy(CGRectGetMaxX(frame.CGRectValue), 320 - quote.contentInsets.right, 0.5);
}

@end
