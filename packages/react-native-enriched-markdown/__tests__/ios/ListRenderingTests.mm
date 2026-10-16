#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/renderer/AttributedRenderer.h"
#import "../../ios/renderer/ListItemRenderer.h"
#import "../../ios/renderer/RenderContext.h"
#import "../../ios/styles/StyleConfig.h"
#import <XCTest/XCTest.h>

static MarkdownASTNode *ENRMOrderedList(NSInteger start, NSUInteger count)
{
  MarkdownASTNode *list = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeOrderedList];
  list.attributes[@"start"] = [@(start) stringValue];
  for (NSUInteger i = 0; i < count; i++) {
    MarkdownASTNode *item = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeListItem];
    MarkdownASTNode *paragraph = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeParagraph];
    MarkdownASTNode *text = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeText];
    text.content = @"item";
    [paragraph addChild:text];
    [item addChild:paragraph];
    [list addChild:item];
  }
  return list;
}

@interface ENRMListRenderingTests : XCTestCase
@end

@implementation ENRMListRenderingTests

- (NSArray<ENRMListMarkerDescriptor *> *)markersForLists:(NSArray<MarkdownASTNode *> *)lists
                                                  config:(StyleConfig *)config
{
  AttributedRenderer *renderer = [[AttributedRenderer alloc] initWithConfig:config];
  NSAttributedString *text = [renderer renderNodes:lists context:[[RenderContext alloc] init] block:nil];
  NSMutableArray *markers = [NSMutableArray array];
  [text enumerateAttribute:ListItemMarkerStartAttribute
                   inRange:NSMakeRange(0, text.length)
                   options:0
                usingBlock:^(NSArray *value, NSRange range, BOOL *stop) {
                  if (value)
                    [markers addObjectsFromArray:value];
                }];
  return markers;
}

- (void)testShortListKeepsItsIndentAndLongListsShareTheWidestGutter
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setListStyleFontSize:16];
  [config setListStyleMarginLeft:24];
  [config setListStyleGapWidth:11];
  CGFloat baseline = [@"99." sizeWithAttributes:@{NSFontAttributeName : config.listMarkerFont}].width;
  CGFloat shortIndent = MAX(config.listStyleMarkerMinWidth, baseline) + config.effectiveListGapWidth;
  NSArray *shortMarkers = [self markersForLists:@[ ENRMOrderedList(1, 99) ] config:config];
  for (ENRMListMarkerDescriptor *marker in shortMarkers) {
    XCTAssertEqualWithAccuracy(marker.indent, shortIndent, 0.01);
  }
  for (NSNumber *start in @[ @98, @998, @12345 ]) {
    NSArray *markers = [self markersForLists:@[ ENRMOrderedList(start.integerValue, 4) ] config:config];
    CGFloat width = baseline;
    for (ENRMListMarkerDescriptor *marker in markers) {
      NSString *label = [NSString stringWithFormat:@"%ld.", (long)marker.number];
      width = MAX(width, [label sizeWithAttributes:@{NSFontAttributeName : config.listMarkerFont}].width);
    }
    for (ENRMListMarkerDescriptor *marker in markers) {
      XCTAssertEqualWithAccuracy(marker.indent, width + config.effectiveListGapWidth, 0.01);
    }
  }
}

- (void)testNestedAndFollowingListsRestoreTheirOwnGutters
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setListStyleFontSize:16];
  [config setListStyleMarginLeft:24];
  [config setListStyleGapWidth:11];
  MarkdownASTNode *outer = ENRMOrderedList(98, 4);
  [outer.children[0] addChild:ENRMOrderedList(9998, 4)];
  NSArray *markers = [self markersForLists:@[ outer, ENRMOrderedList(1, 1) ] config:config];
  CGFloat outerIndent = 0;
  CGFloat nestedIndent = 0;
  for (ENRMListMarkerDescriptor *marker in markers) {
    if (marker.depth == 1) {
      nestedIndent = marker.indent;
    } else if (marker.number != 1) {
      if (outerIndent == 0)
        outerIndent = marker.indent;
      XCTAssertEqualWithAccuracy(marker.indent, outerIndent, 0.01);
    }
  }
  XCTAssertGreaterThan(nestedIndent, outerIndent + config.listStyleMarginLeft);
  ENRMListMarkerDescriptor *last = markers.lastObject;
  XCTAssertLessThan(last.indent, outerIndent);
}

- (void)testNestedListsKeepTheSpaceReservedForWideParentMarkers
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setListStyleFontSize:16];
  [config setListStyleMarginLeft:24];
  [config setListStyleGapWidth:11];
  MarkdownASTNode *outer = ENRMOrderedList(123456789, 1);
  MarkdownASTNode *middle = ENRMOrderedList(1, 1);
  [middle.children[0] addChild:ENRMOrderedList(1, 1)];
  [outer.children[0] addChild:middle];
  NSArray *markers = [self markersForLists:@[ outer ] config:config];
  ENRMListMarkerDescriptor *parent = markers[0];
  ENRMListMarkerDescriptor *child = markers[1];
  ENRMListMarkerDescriptor *leaf = markers[2];
  XCTAssertEqual(parent.depth, 0);
  XCTAssertEqual(child.depth, 1);
  XCTAssertEqual(leaf.depth, 2);
  XCTAssertEqualWithAccuracy(child.indent, parent.indent + config.listStyleMarginLeft, 0.01);
  XCTAssertEqualWithAccuracy(leaf.indent, parent.indent + 2 * config.listStyleMarginLeft, 0.01);
}

- (void)testTaskItemsMoveWithTheirWideNumberedSiblings
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setListStyleFontSize:16];
  [config setListStyleMarginLeft:24];
  [config setListStyleGapWidth:11];
  NSMutableArray<NSArray<ENRMListMarkerDescriptor *> *> *results = [NSMutableArray array];
  for (NSNumber *start in @[ @1, @12345 ]) {
    MarkdownASTNode *outer = ENRMOrderedList(start.integerValue, 3);
    MarkdownASTNode *task = outer.children[1];
    task.attributes[@"isTask"] = @"true";
    MarkdownASTNode *child = ENRMOrderedList(1, 1);
    child.type = MarkdownNodeTypeUnorderedList;
    [task addChild:child];
    [outer.children[2] addChild:ENRMOrderedList(1, 1)];
    [results addObject:[self markersForLists:@[ outer ] config:config]];
  }
  NSArray<ENRMListMarkerDescriptor *> *shortMarkers = results[0];
  NSArray<ENRMListMarkerDescriptor *> *wideMarkers = results[1];
  XCTAssertEqual(shortMarkers.count, 5u);
  XCTAssertEqual(wideMarkers.count, 5u);
  ENRMListMarkerDescriptor *task = wideMarkers[1];
  ENRMListMarkerDescriptor *child = wideMarkers[2];
  XCTAssertTrue(task.isTask);
  XCTAssertEqual(child.depth, 1);
  XCTAssertEqual(child.listType, ListTypeUnordered);
  CGFloat shift = [wideMarkers[0] indent] - [shortMarkers[0] indent];
  XCTAssertGreaterThan(shift, 0);
  XCTAssertEqualWithAccuracy(task.indent, [shortMarkers[1] indent] + shift, 0.01);
  XCTAssertEqualWithAccuracy(child.indent, [shortMarkers[2] indent] + shift, 0.01);
  ENRMListMarkerDescriptor *numericChild = wideMarkers[4];
  ENRMListMarkerDescriptor *numericParent = wideMarkers[3];
  XCTAssertEqualWithAccuracy(numericChild.indent, numericParent.indent + config.listStyleMarginLeft, 0.01);
}

- (void)testSourceNumbersAfterTheStartDoNotOverrideRenderedNumbers
{
  ENRMMarkdownParser *parser = [[ENRMMarkdownParser alloc] init];
  MarkdownASTNode *document = [parser parseMarkdown:@"98. a\n400. b\n1. c\n2. d"];
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setListStyleFontSize:16];
  [config setListStyleMarginLeft:24];
  [config setListStyleGapWidth:11];
  NSArray *markers = [self markersForLists:document.children config:config];
  XCTAssertEqual(markers.count, 4u);
  for (NSUInteger i = 0; i < markers.count; i++) {
    ENRMListMarkerDescriptor *marker = markers[i];
    XCTAssertEqual(marker.number, 98 + (NSInteger)i);
  }
}

- (void)testMarkerMinimumWidthRemainsAFloor
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setListStyleMarkerMinWidth:200];
  NSArray *markers = [self markersForLists:@[ ENRMOrderedList(998, 4) ] config:config];
  for (ENRMListMarkerDescriptor *marker in markers) {
    XCTAssertEqualWithAccuracy(marker.indent, 200 + config.effectiveListGapWidth, 0.01);
  }
}
@end
