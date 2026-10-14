#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/HTMLGenerator.h"
#import "../../ios/utils/LastElementUtils.h"
#import "../../ios/utils/MarkdownASTSerializer.h"
#import <XCTest/XCTest.h>

@interface ENRMClipboardHTMLTests : XCTestCase
@end

@implementation ENRMClipboardHTMLTests

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
}

@end
