#import "../../ios/input/ENRMMarkdownSerializer.h"
#import <XCTest/XCTest.h>

static ENRMFormattingRange *ENRMSerializerTestRange(ENRMInputStyleType type, NSUInteger start, NSUInteger end)
{
  return [ENRMFormattingRange rangeWithType:type range:NSMakeRange(start, end - start) url:@"https://example.com"];
}

@interface InputMarkdownSerializerTests : XCTestCase
@end

@implementation InputMarkdownSerializerTests

- (void)testDropsStylesStackedInsideAWordInsteadOfWritingLiteralDelimiters
{
  NSString *text = @"bold textitalic textunderlinestrikethrough";
  NSArray *ranges = @[
    ENRMSerializerTestRange(ENRMInputStyleTypeStrong, 0, 42),
    ENRMSerializerTestRange(ENRMInputStyleTypeEmphasis, 9, 42),
    ENRMSerializerTestRange(ENRMInputStyleTypeUnderline, 20, 42),
    ENRMSerializerTestRange(ENRMInputStyleTypeStrikethrough, 29, 42),
  ];

  XCTAssertEqualObjects([ENRMMarkdownSerializer serializePlainText:text ranges:ranges],
                        @"**bold text*italic textunderlinestrikethrough***");
}

- (void)testKeepsStackedStylesThatStartAfterASpace
{
  NSString *text = @"bold text italic text underline strike";
  NSArray *ranges = @[
    ENRMSerializerTestRange(ENRMInputStyleTypeStrong, 0, 39),
    ENRMSerializerTestRange(ENRMInputStyleTypeEmphasis, 10, 39),
    ENRMSerializerTestRange(ENRMInputStyleTypeUnderline, 22, 39),
    ENRMSerializerTestRange(ENRMInputStyleTypeStrikethrough, 32, 39),
  ];

  XCTAssertEqualObjects([ENRMMarkdownSerializer serializePlainText:text ranges:ranges],
                        @"**bold text *italic text _underline ~~strike~~_***");
}

- (void)testKeepsBoldOverHalfAWordButDropsUnderline
{
  NSArray *bold = @[ ENRMSerializerTestRange(ENRMInputStyleTypeStrong, 0, 4) ];
  NSArray *underline = @[ ENRMSerializerTestRange(ENRMInputStyleTypeUnderline, 0, 4) ];

  XCTAssertEqualObjects([ENRMMarkdownSerializer serializePlainText:@"halfword" ranges:bold], @"**half**word");
  XCTAssertEqualObjects([ENRMMarkdownSerializer serializePlainText:@"halfword" ranges:underline], @"halfword");
}

- (void)testDropsBoldThatCannotCloseAfterPunctuationBeforeALetter
{
  NSArray *ranges = @[ ENRMSerializerTestRange(ENRMInputStyleTypeStrong, 0, 5) ];

  XCTAssertEqualObjects([ENRMMarkdownSerializer serializePlainText:@"Note:text" ranges:ranges], @"Note:text");
}

- (void)testTreatsAnEmojiAsPunctuation
{
  NSArray *ranges = @[ ENRMSerializerTestRange(ENRMInputStyleTypeUnderline, 2, 4) ];

  XCTAssertEqualObjects([ENRMMarkdownSerializer serializePlainText:@"😀ab" ranges:ranges], @"😀_ab_");
}

@end
