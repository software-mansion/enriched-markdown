#import "CodeBackground.h"
#import "ENRMMarkdownParser.h"
#import "ENRMTextLinkAttributes.h"
#import "ENRMTextLinkRecognizer.h"
#import "MarkdownASTSerializer.h"
#import "MarkdownExtractor.h"
#import <XCTest/XCTest.h>

// Add to an iOS host XCTest target linked against ReactNativeEnrichedMarkdown.
// These tests exercise NSRegularExpression and the production md4c parser.
@interface ENRMTextLinkRecognizerTests : XCTestCase
@end

@implementation ENRMTextLinkRecognizerTests

- (ENRMLinkRegexConfig *)regex:(NSString *)pattern
{
  return [[ENRMLinkRegexConfig alloc] initWithPattern:pattern caseInsensitive:NO dotAll:NO isDisabled:NO isDefault:NO];
}

- (MarkdownASTNode *)parse:(NSString *)source text:(NSString *)text code:(NSString *)code
{
  return [[[ENRMMarkdownParser alloc] init] parseMarkdown:source
                                                    flags:[ENRMMd4cFlags defaultFlags]
                                                    isGFM:YES
                                                linkRegex:text ? [self regex:text] : nil
                                      inlineCodeLinkRegex:code ? [self regex:code] : nil];
}

- (NSArray<MarkdownASTNode *> *)links:(MarkdownASTNode *)node
{
  NSMutableArray *links = [NSMutableArray array];
  if (node.type == MarkdownNodeTypeLink)
    [links addObject:node];
  for (MarkdownASTNode *child in node.children)
    [links addObjectsFromArray:[self links:child]];
  return links;
}

- (void)testMultipleMatchesPreserveUnicodeText
{
  MarkdownASTNode *ast = [self parse:@"😀 ref:one, ref:two café" text:@"ref:[a-z]+" code:nil];
  NSArray *links = [self links:ast];
  XCTAssertEqual(links.count, 2u);
  XCTAssertEqualObjects([links[0] attributes][@"url"], @"ref:one");
  XCTAssertEqualObjects([links[1] attributes][@"url"], @"ref:two");
  XCTAssertEqualObjects(plainTextFromASTNode(ast), @"😀 ref:one, ref:two café");
}

- (void)testExistingLinksAutolinksAndCodeBlocksAreOpaque
{
  NSString *source = @"[ref:one](https://existing.example) <https://ref:two>\n\n```\nref:three\n```\n\n    ref:four\n";
  MarkdownASTNode *ast = [self parse:source text:@"ref:[a-z]+" code:@"ref:[a-z]+"];
  NSArray *links = [self links:ast];
  XCTAssertEqual(links.count, 2u);
  XCTAssertEqualObjects([links[0] attributes][@"url"], @"https://existing.example");
  XCTAssertEqualObjects([links[1] attributes][@"url"], @"https://ref:two");
}

- (void)testWholeInlineCodeKeepsCodeNodeAndRejectsPartialMatch
{
  MarkdownASTNode *ast = [self parse:@"`ref:one` `prefix ref:two` ref:three" text:nil code:@"ref:[a-z]+"];
  NSArray *links = [self links:ast];
  XCTAssertEqual(links.count, 1u);
  MarkdownASTNode *link = links.firstObject;
  XCTAssertEqualObjects(link.attributes[@"url"], @"ref:one");
  XCTAssertEqual(link.children.firstObject.type, MarkdownNodeTypeCode);
  XCTAssertEqualObjects(plainTextFromASTNode(ast), @"ref:one prefix ref:two ref:three");
  NSString *serialized = markdownFromASTNode(ast);
  XCTAssertFalse([serialized containsString:@"]("]);
  XCTAssertTrue([serialized containsString:@"`ref:one`"]);
}

- (void)testWholeInlineCodeBacktracksAcrossAlternatives
{
  MarkdownASTNode *ast = [self parse:@"`ab`" text:nil code:@"a|ab"];
  XCTAssertEqual([self links:ast].count, 1u);
}

- (void)testPlainRegexDoesNotRecognizeInlineCodeAndEmptyMatchesAreIgnored
{
  MarkdownASTNode *ast = [self parse:@"`ref:one` plain" text:@"ref:[a-z]+|(?=plain)" code:nil];
  XCTAssertEqual([self links:ast].count, 0u);
  XCTAssertEqualObjects(plainTextFromASTNode(ast), @"ref:one plain");
}

- (void)testInvalidPatternDisablesOnlyItsRecognizer
{
  MarkdownASTNode *ast = [self parse:@"ref:one `ref:two`" text:@"[" code:@"ref:[a-z]+"];
  NSArray *links = [self links:ast];
  XCTAssertEqual(links.count, 1u);
  XCTAssertEqualObjects([links[0] attributes][@"url"], @"ref:two");
}

- (void)testPartialCopyTreatsRecognizedTextAsSourceText
{
  UIFont *font = [UIFont systemFontOfSize:14];
  NSAttributedString *text =
      [[NSAttributedString alloc] initWithString:@"ref:one"
                                      attributes:@{
                                        NSFontAttributeName : font,
                                        NSLinkAttributeName : @"ref:one",
                                        NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle),
                                        ENRMRecognizedLinkAttributeName : @YES,
                                        ENRMRecognizedLinkOriginalUnderlineAttributeName : @0,
                                      }];
  XCTAssertEqualObjects(extractMarkdownFromAttributedString(text, NSMakeRange(0, text.length)), @"ref:one");
  XCTAssertEqualObjects(extractMarkdownFromAttributedString(text, NSMakeRange(0, 3)), @"ref");
}

- (void)testPartialCopyKeepsRecognizedCodeBackticksAndSourceUnderline
{
  UIFont *font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
  NSMutableAttributedString *text =
      [[NSMutableAttributedString alloc] initWithString:@"ref:one"
                                             attributes:@{
                                               NSFontAttributeName : font,
                                               NSLinkAttributeName : @"ref:one",
                                               CodeAttributeName : @YES,
                                               ENRMRecognizedLinkAttributeName : @YES,
                                               ENRMRecognizedLinkOriginalUnderlineAttributeName : @0,
                                             }];
  XCTAssertEqualObjects(extractMarkdownFromAttributedString(text, NSMakeRange(0, text.length)), @"`ref:one`");
  [text addAttribute:ENRMRecognizedLinkOriginalUnderlineAttributeName
               value:@(NSUnderlineStyleSingle)
               range:NSMakeRange(0, text.length)];
  XCTAssertEqualObjects(extractMarkdownFromAttributedString(text, NSMakeRange(0, text.length)), @"<u>`ref:one`</u>");
}

@end
