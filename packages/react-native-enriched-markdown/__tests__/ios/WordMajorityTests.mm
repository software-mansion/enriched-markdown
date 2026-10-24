#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/renderer/AttributedRenderer.h"
#import "../../ios/renderer/RenderContext.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMWordMajority.h"
#import <XCTest/XCTest.h>

static MarkdownASTNode *ENRMNode(MarkdownNodeType type, NSString *content, NSArray<MarkdownASTNode *> *children)
{
  MarkdownASTNode *node = [[MarkdownASTNode alloc] initWithType:type];
  node.content = content;
  for (MarkdownASTNode *child in children)
    [node addChild:child];
  return node;
}

@interface ENRMWordMajorityTests : XCTestCase
@end

@implementation ENRMWordMajorityTests

- (void)testMostWordsDecideAndTiesGoToTheFirstWord
{
  XCTAssertEqualObjects(ENRMWordMajorityDirection(@"StrictMode: يعيد العرض مرتين"), @"rtl");
  XCTAssertEqualObjects(ENRMWordMajorityDirection(@"Device hub: מאפשר לנהל מכשירים מכל מקום."), @"rtl");
  XCTAssertEqualObjects(ENRMWordMajorityDirection(@"The translation is \"שלום עולם\"."), @"ltr");
  XCTAssertEqualObjects(ENRMWordMajorityDirection(@"Hello مرحبا"), @"ltr");
  XCTAssertEqualObjects(ENRMWordMajorityDirection(@"مرحبا Hello"), @"rtl");
  XCTAssertNil(ENRMWordMajorityDirection(@"123 456."));
}

- (void)testEnglishLedArabicParagraphRendersRtlWithoutTouchingTheSharedTree
{
  MarkdownASTNode *code = ENRMNode(MarkdownNodeTypeCode, nil, @[ ENRMNode(MarkdownNodeTypeText, @"fetch()", @[]) ]);
  MarkdownASTNode *paragraph = ENRMNode(MarkdownNodeTypeParagraph, nil, @[
    ENRMNode(MarkdownNodeTypeText, @"React: يستدعي الدالة ", @[]), code, ENRMNode(MarkdownNodeTypeText, @" مرتين", @[])
  ]);
  MarkdownASTNode *document = ENRMNode(MarkdownNodeTypeDocument, nil, @[ paragraph ]);
  StyleConfig *config = [[StyleConfig alloc] init];

  MarkdownASTNode *annotated = ENRMWordMajorityAST(document, config);
  // The parser shares converted trees, so the input must stay untouched.
  XCTAssertNil(paragraph.attributes[ENRMProseDirectionKey]);
  XCTAssertEqualObjects(annotated.children[0].attributes[ENRMProseDirectionKey], @"rtl");

  AttributedRenderer *renderer = [[AttributedRenderer alloc] initWithConfig:config];
  NSAttributedString *text = [renderer renderNodes:annotated.children context:[[RenderContext alloc] init] block:nil];
  NSParagraphStyle *style = [text attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];
  XCTAssertEqual(style.baseWritingDirection, NSWritingDirectionRightToLeft);
  NSRange codeRange = [text.string rangeOfString:@"fetch()"];
  XCTAssertNotNil([text attribute:NSWritingDirectionAttributeName atIndex:codeRange.location effectiveRange:NULL]);
  // No characters are inserted, so copied text is unchanged.
  XCTAssertTrue([text.string hasPrefix:@"React: يستدعي الدالة fetch() مرتين"]);
}

@end
