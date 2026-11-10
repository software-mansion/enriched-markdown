#import "../../ios/input/ENRMBlockRange.h"
#import "../../ios/input/ENRMBlockStore.h"
#import "../../ios/input/ENRMFormattingRange.h"
#import "../../ios/input/ENRMInputParser.h"
#import "../../ios/input/ENRMMarkdownSerializer.h"
#import <XCTest/XCTest.h>

// The input's markdown import and export live in the shared C++ core
// (packages/core/cpp/input), which has its own host tests. These checks cover
// the Objective-C wrappers: string and range conversion, UTF-16 offsets, and
// that the shared fixture files give the same answers through them.

static NSString *ENRMInputFixturePath(NSString *name)
{
  // __FILE__ is .../packages/react-native-enriched-markdown/__tests__/ios/<this file>.
  NSString *packageRoot = [[[@(__FILE__) stringByDeletingLastPathComponent] stringByDeletingLastPathComponent]
      stringByDeletingLastPathComponent];
  NSString *cppRoot = [[packageRoot stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"core/cpp"];
  return [cppRoot stringByAppendingPathComponent:[@"tests/fixtures/input" stringByAppendingPathComponent:name]];
}

@interface ENRMInputMarkdownCoreTests : XCTestCase
@end

@implementation ENRMInputMarkdownCoreTests

#pragma mark - Helpers

- (NSArray *)fixtureCases:(NSString *)name
{
  NSData *data = [NSData dataWithContentsOfFile:ENRMInputFixturePath(name)];
  XCTAssertNotNil(data, @"fixture file %@ not found", name);
  NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
  NSArray *cases = json[@"cases"];
  XCTAssertGreaterThan(cases.count, 0u, @"fixture file %@ has no cases", name);
  return cases ?: @[];
}

- (ENRMParseResult *)parse:(NSString *)markdown
{
  return [[[ENRMInputParser alloc] init] parseToPlainTextAndRanges:markdown];
}

- (NSString *)serialize:(ENRMParseResult *)parsed
{
  return [ENRMMarkdownSerializer serializePlainText:parsed.plainText
                                             ranges:parsed.formattingRanges
                                        blockRanges:parsed.blockRanges];
}

- (NSString *)roundTrip:(NSString *)markdown
{
  return [self serialize:[self parse:markdown]];
}

/// The round trip the input view does: the parsed blocks go through the real
/// block store (ordinals, depth clamping, line bounds) before they are exported.
- (NSString *)roundTripThroughBlockStore:(NSString *)markdown
{
  ENRMParseResult *parsed = [self parse:markdown];
  ENRMBlockStore *store = [[ENRMBlockStore alloc] init];
  [store setRanges:parsed.blockRanges];
  [store normalizeToLineBoundsInText:parsed.plainText];
  return [ENRMMarkdownSerializer serializePlainText:parsed.plainText
                                             ranges:parsed.formattingRanges
                                        blockRanges:store.allRanges];
}

#pragma mark - Shared fixtures

- (void)testCanonicalFixturesRoundTripByteForByte
{
  for (NSString *markdown in [self fixtureCases:@"canonical.json"]) {
    XCTAssertEqualObjects([self roundTrip:markdown], markdown, @"markdown: %@", markdown);
  }
}

- (void)testCanonicalFixturesRoundTripThroughTheBlockStore
{
  for (NSString *markdown in [self fixtureCases:@"canonical.json"]) {
    XCTAssertEqualObjects([self roundTripThroughBlockStore:markdown], markdown, @"markdown: %@", markdown);
  }
}

- (void)testNormalizationAndUnsupportedFixturesSettleInOnePass
{
  for (NSString *file in @[ @"normalization.json", @"unsupported.json" ]) {
    for (NSArray<NSString *> *pair in [self fixtureCases:file]) {
      XCTAssertEqualObjects([self roundTrip:pair[0]], pair[1], @"%@, markdown: %@", file, pair[0]);
      XCTAssertEqualObjects([self roundTrip:pair[1]], pair[1], @"%@, settled: %@", file, pair[1]);
    }
  }
}

- (void)testPlainTextFixturesComeBackAsTheSameTextWithNoRanges
{
  for (NSString *text in [self fixtureCases:@"plain-text.json"]) {
    ENRMParseResult *parsed = [self parse:[ENRMMarkdownSerializer serializePlainText:text ranges:@[] blockRanges:@[]]];
    XCTAssertEqualObjects(parsed.plainText, text);
    XCTAssertEqual(parsed.formattingRanges.count, 0u, @"text: %@", text);
    XCTAssertEqual(parsed.blockRanges.count, 0u, @"text: %@", text);
  }
}

#pragma mark - Issue 1127

- (void)testUnclosedBracketKeepsTheFollowingParagraph
{
  ENRMParseResult *parsed = [self parse:@"## Title [wip\nbody"];
  XCTAssertEqualObjects(parsed.plainText, @"Title [wip\nbody");
  XCTAssertEqual(parsed.blockRanges.count, 1u);
  XCTAssertEqual(parsed.blockRanges.firstObject.type, ENRMInputBlockTypeHeading2);
  XCTAssertEqualObjects([self serialize:parsed], @"## Title \\[wip\nbody");
}

- (void)testTypedMarkupIsEscapedOnExport
{
  XCTAssertEqualObjects([ENRMMarkdownSerializer serializePlainText:@"2 *x* 6" ranges:@[] blockRanges:@[]],
                        @"2 \\*x\\* 6");

  NSArray<ENRMBlockRange *> *bullet = @[ [ENRMBlockRange rangeWithType:ENRMInputBlockTypeUnorderedListItem
                                                                 range:NSMakeRange(0, 3)] ];
  XCTAssertEqualObjects([ENRMMarkdownSerializer serializePlainText:@"> x" ranges:@[] blockRanges:bullet], @"- \\> x");

  NSArray<ENRMBlockRange *> *heading = @[ [ENRMBlockRange rangeWithType:ENRMInputBlockTypeHeading2
                                                                  range:NSMakeRange(0, 6)
                                                                  level:2] ];
  XCTAssertEqualObjects([ENRMMarkdownSerializer serializePlainText:@"Use #" ranges:@[] blockRanges:heading],
                        @"## Use \\#");
}

- (void)testSpacesAfterAMarkerSurvive
{
  ENRMParseResult *parsed = [self parse:@"1.  x"];
  XCTAssertEqualObjects(parsed.plainText, @" x");
  XCTAssertEqualObjects([self serialize:parsed], @"1.  x");
}

#pragma mark - UTF-16 offsets

- (void)testOffsetsAfterAnEmojiAreUTF16
{
  // U+1F600 is a surrogate pair: two UTF-16 units, so "bold" starts at 5 and "x" at 12.
  ENRMParseResult *parsed = [self parse:@"😀 a **bold** [x](https://e.com)"];
  XCTAssertEqualObjects(parsed.plainText, @"😀 a bold x");
  XCTAssertEqual(parsed.formattingRanges.count, 2u);
  ENRMFormattingRange *bold = parsed.formattingRanges[0];
  XCTAssertEqual(bold.type, ENRMInputStyleTypeStrong);
  XCTAssertTrue(NSEqualRanges(bold.range, NSMakeRange(5, 4)));
  XCTAssertEqualObjects([parsed.plainText substringWithRange:bold.range], @"bold");
  ENRMFormattingRange *link = parsed.formattingRanges[1];
  XCTAssertEqual(link.type, ENRMInputStyleTypeLink);
  XCTAssertTrue(NSEqualRanges(link.range, NSMakeRange(10, 1)));
  XCTAssertEqualObjects(link.url, @"https://e.com");
  XCTAssertEqualObjects([self serialize:parsed], @"😀 a **bold** [x](https://e.com)");
}

- (void)testOffsetsAroundCJKTextAndAHeadingAreUTF16
{
  ENRMParseResult *parsed = [self parse:@"# 日本語\n日本 *語* 🇵🇱"];
  XCTAssertEqualObjects(parsed.plainText, @"日本語\n日本 語 🇵🇱");
  XCTAssertEqual(parsed.blockRanges.count, 1u);
  XCTAssertTrue(NSEqualRanges(parsed.blockRanges[0].range, NSMakeRange(0, 3)));
  XCTAssertEqual(parsed.formattingRanges.count, 1u);
  XCTAssertTrue(NSEqualRanges(parsed.formattingRanges[0].range, NSMakeRange(7, 1)));
  XCTAssertEqualObjects([self serialize:parsed], @"# 日本語\n日本 *語* 🇵🇱");
}

- (void)testSerializingRangesAfterAnEmojiUsesUTF16Offsets
{
  ENRMFormattingRange *italic = [ENRMFormattingRange rangeWithType:ENRMInputStyleTypeEmphasis range:NSMakeRange(3, 2)];
  XCTAssertEqualObjects([ENRMMarkdownSerializer serializePlainText:@"😀 ab c" ranges:@[ italic ]], @"😀 *ab* c");
}

#pragma mark - Blocks

- (void)testListMetadataComesBackSettled
{
  ENRMParseResult *parsed = [self parse:@"1. a\n   - b\n2. c"];
  XCTAssertEqual(parsed.blockRanges.count, 3u);
  XCTAssertEqual(parsed.blockRanges[0].type, ENRMInputBlockTypeOrderedListItem);
  XCTAssertEqual(parsed.blockRanges[0].ordinal, 1);
  XCTAssertEqual(parsed.blockRanges[1].type, ENRMInputBlockTypeUnorderedListItem);
  XCTAssertEqual(parsed.blockRanges[1].level, 1);
  XCTAssertEqual(parsed.blockRanges[2].ordinal, 2);
}

- (void)testEmptyListItemsAwayFromTheCaretSurviveImportAndTheBlockStore
{
  ENRMParseResult *parsed = [self parse:@"- a\n- \n- c"];
  XCTAssertEqualObjects(parsed.plainText, @"a\n\nc");
  XCTAssertEqual(parsed.blockRanges.count, 3u);
  XCTAssertTrue(NSEqualRanges(parsed.blockRanges[1].range, NSMakeRange(2, 0)));
  XCTAssertEqualObjects([self roundTripThroughBlockStore:@"- a\n- \n- c"], @"- a\n- \n- c");
  XCTAssertEqualObjects([self roundTripThroughBlockStore:@"1. a\n2. \n3. c"], @"1. a\n2. \n3. c");
  XCTAssertEqualObjects([self roundTripThroughBlockStore:@"- a\n  - b\n- \n- d"], @"- a\n  - b\n- \n- d");
}

- (void)testNestedOrderedListIndentFollowsTheParentMarkerWidth
{
  NSString *markdown = @"9. a\n10. b\n    - c";
  ENRMParseResult *parsed = [self parse:markdown];
  XCTAssertEqualObjects([self serialize:parsed], @"1. a\n2. b\n   - c");
}

- (void)testSlicedBlocksKeepTheirOrdinals
{
  // A copy of the second and third item of a numbered list.
  ENRMBlockRange *second = [ENRMBlockRange rangeWithType:ENRMInputBlockTypeOrderedListItem range:NSMakeRange(0, 1)];
  second.ordinal = 2;
  ENRMBlockRange *third = [ENRMBlockRange rangeWithType:ENRMInputBlockTypeOrderedListItem range:NSMakeRange(2, 1)];
  third.ordinal = 3;
  NSArray<ENRMBlockRange *> *blocks = @[ second, third ];
  XCTAssertEqualObjects([ENRMMarkdownSerializer serializePlainText:@"b\nc" ranges:@[] blockRanges:blocks],
                        @"2. b\n3. c");
}

@end
