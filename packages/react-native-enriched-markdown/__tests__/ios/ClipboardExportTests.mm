#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import "../../ios/utils/HTMLGenerator.h"
#import "../../ios/utils/LastElementUtils.h"
#import "../../ios/utils/MarkdownASTSerializer.h"
#import <XCTest/XCTest.h>

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

@end
