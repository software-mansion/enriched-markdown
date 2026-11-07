#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/segments/TableContainerView.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMAccessibilityLabels.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import "../../ios/utils/HTMLGenerator.h"
#import "../../ios/utils/LastElementUtils.h"
#import "../../ios/utils/MarkdownASTSerializer.h"
#import "../../ios/utils/PasteboardUtils.h"
#import <XCTest/XCTest.h>

@interface TableContainerView (ClipboardExportTests)
- (void)copyTableToPasteboard;
- (void)copyMarkdownToPasteboard;
@end

@interface ENRMClipboardExportTests : XCTestCase
@end

@implementation ENRMClipboardExportTests

- (void)testTableLineBreaksAreExportedAsHTMLBreaks
{
  for (NSString *separator in @[ @"\n", @"\r", @"\r\n", @"\u2028", @"\u2029" ]) {
    NSAttributedString *text =
        [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"first%@second", separator]];
    NSString *html = generateTableHTML(@[ @[ @{@"attributedText" : text} ] ], [[StyleConfig alloc] init]);
    XCTAssertTrue([html containsString:@"first<br>second"], @"%@", html);
    XCTAssertFalse([html containsString:@"<br><br>"], @"%@", html);
  }
}

- (void)testEscapedCharactersAndLineBreaksShareOneRun
{
  NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"a & b\nc <d>"];
  NSString *html = generateTableHTML(@[ @[ @{@"attributedText" : text} ] ], [[StyleConfig alloc] init]);
  XCTAssertTrue([html containsString:@"a &amp; b<br>c &lt;d&gt;"], @"%@", html);
}

- (NSString *)htmlForMarkdown:(NSString *)markdown
{
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init] parseMarkdown:markdown
                                                                    flags:[ENRMMd4cFlags defaultFlags]
                                                                    isGFM:YES];
  StyleConfig *config = [[StyleConfig alloc] init];
  ENRMRenderResult *result = ENRMRenderASTNodes(ast.children, config, NO, YES, 0, NSLineBreakStrategyStandard);
  return generateHTML(result.attributedText, config);
}

- (void)testHardBreaksStayInsideTheirBlock
{
  NSString *paragraph = [self htmlForMarkdown:@"line one  \nline two\n\npara two"];
  XCTAssertTrue([paragraph containsString:@"line one<br>line two</p>"], @"%@", paragraph);
  XCTAssertFalse([paragraph containsString:@"<br></p>"], @"%@", paragraph);

  NSString *list = [self htmlForMarkdown:@"- item one  \n  item two\n- item three"];
  XCTAssertTrue([list containsString:@"item one<br>item two</li>"], @"%@", list);
  XCTAssertEqual([list componentsSeparatedByString:@"<li"].count, 3u, @"%@", list);
}

- (void)testCodeBlockNewlinesRemainLiteral
{
  NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"first\nsecond"
                                                             attributes:@{CodeBlockAttributeName : @YES}];
  NSString *html = generateHTML(text, [[StyleConfig alloc] init]);
  XCTAssertFalse([html containsString:@"<br>"], @"%@", html);
  XCTAssertTrue([html containsString:@"first\nsecond"], @"%@", html);
}

- (void)testSerializedTableFormulaKeepsInlineDelimiters
{
  MarkdownASTNode *formula = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeLatexMathInline];
  MarkdownASTNode *text = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeText];
  text.content = @"x_1";
  [formula addChild:text];
  MarkdownASTNode *cell = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeTableCell];
  [cell addChild:formula];
  XCTAssertEqualObjects(markdownFromASTNodeChildren(cell), @"$x_1$");

  MarkdownASTNode *strong = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeStrong];
  [strong addChild:formula];
  MarkdownASTNode *nestedCell = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeTableCell];
  [nestedCell addChild:strong];
  XCTAssertEqualObjects(markdownFromASTNodeChildren(nestedCell), @"**$x_1$**");
}

// The parser does not yet turn HTML <br> into break nodes in table cells.
// Construct them here, then use the table view's production Copy actions.
- (MarkdownASTNode *)clipboardNode:(MarkdownNodeType)type children:(NSArray<MarkdownASTNode *> *)children
{
  MarkdownASTNode *node = [[MarkdownASTNode alloc] initWithType:type];
  for (MarkdownASTNode *child in children)
    [node addChild:child];
  return node;
}

- (MarkdownASTNode *)clipboardText:(NSString *)text
{
  MarkdownASTNode *node = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeText];
  node.content = text;
  return node;
}

- (MarkdownASTNode *)clipboardTableWithHeader:(MarkdownASTNode *)header body:(MarkdownASTNode *)body
{
  return [self
      clipboardNode:MarkdownNodeTypeTable
           children:@[
             [self clipboardNode:MarkdownNodeTypeTableHead
                        children:@[ [self clipboardNode:MarkdownNodeTypeTableRow
                                               children:@[
                                                 header, [self clipboardNode:MarkdownNodeTypeTableHeaderCell
                                                                    children:@[]]
                                               ]] ]],
             [self clipboardNode:MarkdownNodeTypeTableBody
                        children:@[
                          [self clipboardNode:MarkdownNodeTypeTableRow
                                     children:@[ body, [self clipboardNode:MarkdownNodeTypeTableCell children:@[]] ]]
                        ]]
           ]];
}

- (TableContainerView *)clipboardView:(MarkdownASTNode *)table
{
  TableContainerView *view = [[TableContainerView alloc] initWithConfig:[[StyleConfig alloc] init]];
  view.accessibilityLabels = [[ENRMAccessibilityLabels alloc] init];
  view.accessibilityLabels.tableRow = @"Row {n}, {content}";
  [view applyTableNode:table];
  return view;
}

- (void)testTableCopyPreservesHardAndSoftBreaksInPlainTextAndAccessibility
{
  for (NSNumber *breakType in @[ @(MarkdownNodeTypeLineBreak), @(MarkdownNodeTypeSoftBreak) ]) {
    MarkdownASTNode *cell =
        [self clipboardNode:MarkdownNodeTypeTableCell
                   children:@[
                     [self clipboardNode:(MarkdownNodeType)breakType.integerValue children:@[]],
                     [self clipboardText:@"first"],
                     [self clipboardNode:MarkdownNodeTypeStrong
                                children:@[
                                  [self clipboardNode:(MarkdownNodeType)breakType.integerValue children:@[]],
                                  [self clipboardText:@"bold"]
                                ]],
                     [self clipboardNode:(MarkdownNodeType)breakType.integerValue children:@[]]
                   ]];
    MarkdownASTNode *header = [self clipboardNode:MarkdownNodeTypeTableHeaderCell
                                         children:@[ [self clipboardText:@"Cell"] ]];
    TableContainerView *view = [self clipboardView:[self clipboardTableWithHeader:header body:cell]];
    [view copyTableToPasteboard];
    XCTAssertEqualObjects([UIPasteboard generalPasteboard].items.firstObject[kUTIPlainText],
                          @"Cell\t\n\nfirst\nbold\n\t\n");
    XCTAssertNotNil([UIPasteboard generalPasteboard].items.firstObject[kUTIHTML]);
    UIAccessibilityElement *row = view.accessibilityElements.lastObject;
    XCTAssertTrue([row.accessibilityLabel containsString:@"\nfirst\nbold\n"], @"%@", row.accessibilityLabel);
  }
}

- (void)testTableCopyAsMarkdownKeepsBreaksWithinTheirHeaderAndBodyRows
{
  MarkdownASTNode *header = [self
      clipboardNode:MarkdownNodeTypeTableHeaderCell
           children:@[
             [self clipboardText:@"first"], [self clipboardNode:MarkdownNodeTypeLineBreak children:@[]],
             [self clipboardNode:MarkdownNodeTypeEmphasis
                        children:@[
                          [self clipboardText:@"second"], [self clipboardNode:MarkdownNodeTypeSoftBreak children:@[]],
                          [self clipboardText:@"third"]
                        ]]
           ]];
  MarkdownASTNode *body = [self clipboardNode:MarkdownNodeTypeTableCell
                                     children:@[
                                       [self clipboardText:@"first"],
                                       [self clipboardNode:MarkdownNodeTypeStrong
                                                  children:@[
                                                    [self clipboardNode:MarkdownNodeTypeSoftBreak children:@[]],
                                                    [self clipboardText:@"second"]
                                                  ]],
                                       [self clipboardNode:MarkdownNodeTypeLineBreak children:@[]]
                                     ]];
  MarkdownASTNode *table = [self clipboardTableWithHeader:header body:body];
  TableContainerView *view = [self clipboardView:table];
  NSString *expected = @"| first<br>*second<br>third* |  |\n| --- | --- |\n| first**<br>second**<br> |  |\n";
  [view copyTableToPasteboard];
  XCTAssertEqualObjects([UIPasteboard generalPasteboard].items.firstObject[kUTIMarkdown], expected);
  [view copyMarkdownToPasteboard];
  XCTAssertEqualObjects([UIPasteboard generalPasteboard].string, expected);
  XCTAssertEqual([[UIPasteboard generalPasteboard].string componentsSeparatedByString:@"\n"].count, 4u);
  MarkdownASTNode *quote = [self clipboardNode:MarkdownNodeTypeBlockquote children:@[ table ]];
  XCTAssertEqualObjects(markdownFromBlockquoteNode(quote),
                        @"> | first<br>*second<br>third* |  |\n> | --- | --- |\n> | first**<br>second**<br> |  |\n");
}

- (void)testTableCellBreakSerializationPreservesInlineSyntax
{
  MarkdownASTNode *link =
      [self clipboardNode:MarkdownNodeTypeLink
                 children:@[
                   [self clipboardNode:MarkdownNodeTypeStrong children:@[ [self clipboardText:@"link"] ]],
                   [self clipboardNode:MarkdownNodeTypeSoftBreak children:@[]], [self clipboardText:@"label"]
                 ]];
  [link setAttribute:@"url" value:@"https://example.test"];
  MarkdownASTNode *cell =
      [self clipboardNode:MarkdownNodeTypeTableCell
                 children:@[
                   [self clipboardNode:MarkdownNodeTypeLatexMathInline children:@[ [self clipboardText:@"x_1"] ]],
                   [self clipboardNode:MarkdownNodeTypeLineBreak children:@[]], link, [self clipboardText:@" \\| "],
                   [self clipboardNode:MarkdownNodeTypeCode children:@[ [self clipboardText:@"literal\\n<br>"] ]]
                 ]];
  MarkdownASTNode *header = [self clipboardNode:MarkdownNodeTypeTableHeaderCell
                                       children:@[ [self clipboardText:@"Cell"] ]];
  TableContainerView *view = [self clipboardView:[self clipboardTableWithHeader:header body:cell]];
  [view copyMarkdownToPasteboard];
  XCTAssertEqualObjects(
      [UIPasteboard generalPasteboard].string,
      @"| Cell |  |\n| --- | --- |\n| $x_1$<br>[**link**<br>label](https://example.test) \\| `literal\\n<br>` |  |\n");
}

- (void)testTableCellLiteralContentIsNotRewritten
{
  // Only break nodes change. Literal newlines, including code content, are not rewritten as HTML.
  MarkdownASTNode *literal =
      [self clipboardNode:MarkdownNodeTypeTableCell
                 children:@[
                   [self clipboardText:@"a\nb"], [self clipboardNode:MarkdownNodeTypeCode
                                                            children:@[ [self clipboardText:@"c\nd"] ]]
                 ]];
  XCTAssertEqualObjects(markdownFromASTNodeChildren(literal), @"a\nb`c\nd`");
}

- (void)testParagraphAndCodeBlockBreakSerializationIsUnchanged
{
  MarkdownASTNode *paragraph =
      [self clipboardNode:MarkdownNodeTypeParagraph
                 children:@[
                   [self clipboardText:@"first"], [self clipboardNode:MarkdownNodeTypeLineBreak children:@[]],
                   [self clipboardNode:MarkdownNodeTypeStrong children:@[ [self clipboardText:@"second"] ]],
                   [self clipboardNode:MarkdownNodeTypeSoftBreak children:@[]],
                   [self clipboardNode:MarkdownNodeTypeCode children:@[ [self clipboardText:@"third\nfourth"] ]]
                 ]];
  XCTAssertEqualObjects(markdownFromASTNodeChildren(paragraph), @"first\\\n**second**\n`third\nfourth`");
  MarkdownASTNode *code = [self clipboardNode:MarkdownNodeTypeCodeBlock
                                     children:@[ [self clipboardText:@"first\nsecond"] ]];
  MarkdownASTNode *quote = [self clipboardNode:MarkdownNodeTypeBlockquote children:@[ code ]];
  XCTAssertEqualObjects(markdownFromBlockquoteNode(quote), @"> ```\n> first\n> second\n> ```\n");
}

@end
