#import "../../ios/input/ENRMFormattingRange.h"
#import "../../ios/input/ENRMFormattingStore.h"
#import <XCTest/XCTest.h>

// md4c ignores a "_" between two word characters, so underline can't start or end inside a word:
// turning it on there takes the whole word.
@interface ENRMWholeWordUnderlineTests : XCTestCase
@end

@implementation ENRMWholeWordUnderlineTests

- (NSRange)wordRangeIn:(NSString *)text range:(NSRange)range
{
  return [self wordRangeIn:text range:range store:[ENRMFormattingStore new]];
}

- (NSRange)wordRangeIn:(NSString *)text range:(NSRange)range store:(ENRMFormattingStore *)store
{
  return [store wholeWordRangeForStyle:ENRMInputStyleTypeUnderline inText:text range:range];
}

- (void)testCaretInsideAWordTakesTheWord
{
  XCTAssertTrue(NSEqualRanges([self wordRangeIn:@"an underline here" range:NSMakeRange(6, 0)], NSMakeRange(3, 9)));
}

- (void)testCaretAtAWordEdgeTakesTheWord
{
  XCTAssertTrue(NSEqualRanges([self wordRangeIn:@"foo bar" range:NSMakeRange(3, 0)], NSMakeRange(0, 3)));
  XCTAssertTrue(NSEqualRanges([self wordRangeIn:@"foo bar" range:NSMakeRange(4, 0)], NSMakeRange(4, 3)));
}

- (void)testCaretWithNoWordAroundStaysACaret
{
  XCTAssertTrue(NSEqualRanges([self wordRangeIn:@"foo  bar" range:NSMakeRange(4, 0)], NSMakeRange(4, 0)));
  XCTAssertTrue(NSEqualRanges([self wordRangeIn:@"" range:NSMakeRange(0, 0)], NSMakeRange(0, 0)));
}

- (void)testSelectionInsideAWordGrowsToTheWord
{
  XCTAssertTrue(NSEqualRanges([self wordRangeIn:@"an underline here" range:NSMakeRange(5, 3)], NSMakeRange(3, 9)));
}

- (void)testSelectionAcrossWordsGrowsBothEdges
{
  XCTAssertTrue(NSEqualRanges([self wordRangeIn:@"foo bar baz" range:NSMakeRange(1, 5)], NSMakeRange(0, 7)));
}

- (void)testSelectionStartingAtASpaceDoesNotGrow
{
  XCTAssertTrue(NSEqualRanges([self wordRangeIn:@"foo bar" range:NSMakeRange(3, 4)], NSMakeRange(3, 4)));
}

- (void)testPunctuationAndEmojiEndTheWord
{
  XCTAssertTrue(NSEqualRanges([self wordRangeIn:@"foo(bar)" range:NSMakeRange(5, 1)], NSMakeRange(4, 3)));
  // "😀" is a symbol to md4c, so the word is "bar" alone.
  XCTAssertTrue(NSEqualRanges([self wordRangeIn:@"😀bar" range:NSMakeRange(3, 1)], NSMakeRange(2, 3)));
}

- (void)testLinkEdgeStopsTheGrowth
{
  ENRMFormattingStore *store = [ENRMFormattingStore new];
  [store addRange:[ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink
                                               range:NSMakeRange(0, 3)
                                                 url:@"https://example.com"]];
  XCTAssertTrue(NSEqualRanges([self wordRangeIn:@"foobar" range:NSMakeRange(4, 1) store:store], NSMakeRange(3, 3)));
}

- (void)testGrowToWholeWordsTakesLettersGluedToAnUnderline
{
  ENRMFormattingStore *store = [ENRMFormattingStore new];
  [store addRange:[ENRMFormattingRange rangeWithType:ENRMInputStyleTypeUnderline range:NSMakeRange(2, 6)]];
  [store growToWholeWordsInText:@"mnbergef rest"];
  XCTAssertEqual(store.allRanges.count, 1u);
  XCTAssertTrue(NSEqualRanges(store.allRanges.firstObject.range, NSMakeRange(0, 8)));
}

- (void)testGrowToWholeWordsLeavesWholeWordsAndOtherStylesAlone
{
  ENRMFormattingStore *store = [ENRMFormattingStore new];
  [store addRange:[ENRMFormattingRange rangeWithType:ENRMInputStyleTypeUnderline range:NSMakeRange(4, 3)]];
  [store addRange:[ENRMFormattingRange rangeWithType:ENRMInputStyleTypeStrong range:NSMakeRange(1, 1)]];
  [store growToWholeWordsInText:@"foo bar"];
  XCTAssertEqual(store.allRanges.count, 2u);
  for (ENRMFormattingRange *range in store.allRanges) {
    NSRange expected = range.type == ENRMInputStyleTypeUnderline ? NSMakeRange(4, 3) : NSMakeRange(1, 1);
    XCTAssertTrue(NSEqualRanges(range.range, expected));
  }
}

- (void)testOtherStylesAreUnchanged
{
  NSRange range = NSMakeRange(5, 3);
  XCTAssertTrue(NSEqualRanges([[ENRMFormattingStore new] wholeWordRangeForStyle:ENRMInputStyleTypeStrong
                                                                         inText:@"an underline here"
                                                                          range:range],
                              range));
}

@end
