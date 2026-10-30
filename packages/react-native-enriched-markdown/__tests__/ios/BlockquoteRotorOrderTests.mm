#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/segments/ENRMBlockquoteContainerView.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMAccessibilityLabels.h"
#import "../../ios/utils/MarkdownAccessibilityElementBuilder.h"
#import <XCTest/XCTest.h>

// After an in-place re-render, a quote's subviews are in attach order rather
// than document order. The rotors must still follow the document.
@interface ENRMBlockquoteRotorOrderTests : XCTestCase
@end

@implementation ENRMBlockquoteRotorOrderTests

static MarkdownASTNode *ENRMRotorOrderQuoteNode(NSString *markdown)
{
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init] parseMarkdown:markdown
                                                                    flags:[ENRMMd4cFlags defaultFlags]
                                                                    isGFM:YES
                                                                linkRegex:nil
                                                      inlineCodeLinkRegex:nil
                                                       activeBlockSlotIds:nil
                                                           annotateImages:NO];
  for (MarkdownASTNode *child in ast.children) {
    if (child.type == MarkdownNodeTypeBlockquote) {
      return child;
    }
  }
  return nil;
}

static NSArray<NSString *> *ENRMRotorOrderHeadingLabels(NSArray *elements)
{
  NSMutableArray<NSString *> *labels = [NSMutableArray array];
  for (id element in [MarkdownAccessibilityElementBuilder collectLeafElementsFromElements:elements]) {
    if (([element accessibilityTraits] & UIAccessibilityTraitHeader) != 0) {
      [labels addObject:[element accessibilityLabel] ?: @""];
    }
  }
  return labels;
}

- (void)testHeadingRotorFollowsDocumentOrderAfterQuoteRerender
{
  StyleConfig *config = [[StyleConfig alloc] init];
  ENRMBlockquoteContainerView *quote = [[ENRMBlockquoteContainerView alloc] initWithConfig:config];
  quote.accessibilityLabels = [ENRMAccessibilityLabels new];
  quote.frame = CGRectMake(0, 0, 320, 1000);

  MarkdownASTNode *before = ENRMRotorOrderQuoteNode(@"> # Alpha\n>\n> text\n");
  XCTAssertNotNil(before);
  [quote applyBlockquoteNode:before];
  [quote layoutIfNeeded];
  XCTAssertEqualObjects(ENRMRotorOrderHeadingLabels(@[ quote ]), (@[ @"Alpha" ]));

  MarkdownASTNode *after = ENRMRotorOrderQuoteNode(@"> # Beta\n>\n> ```\n> code\n> ```\n>\n> # Alpha\n>\n> text\n");
  XCTAssertNotNil(after);
  [quote applyBlockquoteNode:after];
  [quote layoutIfNeeded];

  // The reused "Alpha" view was attached before the new "Beta" one.
  XCTAssertEqualObjects(ENRMRotorOrderHeadingLabels(quote.subviews), (@[ @"Alpha", @"Beta" ]));
  XCTAssertEqualObjects(ENRMRotorOrderHeadingLabels(@[ quote ]), (@[ @"Beta", @"Alpha" ]),
                        @"the Headings rotor should follow document order");
}

@end
