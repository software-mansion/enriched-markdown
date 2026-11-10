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

- (void)testCaretAtTheEndOfAnUnderlinedWordIsUnderlined
{
  ENRMFormattingStore *store = [ENRMFormattingStore new];
  [store addRange:[ENRMFormattingRange rangeWithType:ENRMInputStyleTypeUnderline range:NSMakeRange(0, 5)]];
  XCTAssertTrue([store isStyleActive:ENRMInputStyleTypeUnderline atCaret:5 inText:@"hello! bar"]);
  XCTAssertTrue([store isStyleActive:ENRMInputStyleTypeUnderline atCaret:0 inText:@"hello! bar"]);
  // Past punctuation or a space, letters typed don't join the word.
  XCTAssertFalse([store isStyleActive:ENRMInputStyleTypeUnderline atCaret:6 inText:@"hello! bar"]);
  XCTAssertFalse([store isStyleActive:ENRMInputStyleTypeUnderline atCaret:7 inText:@"hello! bar"]);
}

- (void)testCaretAtTheEndOfABoldWordIsNotBold
{
  ENRMFormattingStore *store = [ENRMFormattingStore new];
  [store addRange:[ENRMFormattingRange rangeWithType:ENRMInputStyleTypeStrong range:NSMakeRange(0, 5)]];
  XCTAssertFalse([store isStyleActive:ENRMInputStyleTypeStrong atCaret:5 inText:@"hello"]);
}

- (void)testCaretAtALinkEdgeAfterAnUnderlineIsNotUnderlined
{
  ENRMFormattingStore *store = [ENRMFormattingStore new];
  [store addRange:[ENRMFormattingRange rangeWithType:ENRMInputStyleTypeUnderline range:NSMakeRange(0, 3)]];
  [store addRange:[ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink
                                               range:NSMakeRange(0, 3)
                                                 url:@"https://example.com"]];
  XCTAssertFalse([store isStyleActive:ENRMInputStyleTypeUnderline atCaret:3 inText:@"foo"]);
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

// EnrichedMarkdownTextInput.h pulls in Fabric headers this target can't compile, so the input is
// reached by name, through the methods the tests call.
@protocol ENRMWholeWordUnderlineTestInput <UITextViewDelegate>
@property (nonatomic, readonly) UIView *contentView;
- (void)toggleInlineStyle:(ENRMInputStyleType)styleType;
- (void)setValue:(NSString *)markdown;
- (NSString *)currentMarkdown;
- (BOOL)isEffectiveStyleActive:(ENRMInputStyleType)type atPosition:(NSUInteger)position;
@end

// Drives the input through the text view delegate calls UIKit makes for a keystroke or a caret move.
@interface ENRMWholeWordUnderlineInputTests : XCTestCase
@end

@implementation ENRMWholeWordUnderlineInputTests {
  id<ENRMWholeWordUnderlineTestInput> _input;
  UITextView *_textView;
}

- (void)setUp
{
  _input = [[NSClassFromString(@"EnrichedMarkdownTextInput") alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
  _textView = (UITextView *)_input.contentView;
}

- (void)replaceRange:(NSRange)range withText:(NSString *)text
{
  if (![_input textView:_textView shouldChangeTextInRange:range replacementText:text]) {
    return;
  }
  [_textView.textStorage replaceCharactersInRange:range withString:text];
  _textView.selectedRange = NSMakeRange(range.location + text.length, 0);
  [_input textViewDidChangeSelection:_textView];
  [_input textViewDidChange:_textView];
}

- (void)type:(NSString *)text
{
  for (NSUInteger i = 0; i < text.length; i++) {
    [self replaceRange:_textView.selectedRange withText:[text substringWithRange:NSMakeRange(i, 1)]];
  }
}

- (void)deleteBackward
{
  NSRange selection = _textView.selectedRange;
  [self replaceRange:selection.length > 0 ? selection : NSMakeRange(selection.location - 1, 1) withText:@""];
}

- (void)select:(NSRange)range
{
  // A caret move right after an edit belongs to it (ENRMEditSession's grace period); a user's move
  // comes later.
  [NSThread sleepForTimeInterval:0.15];
  _textView.selectedRange = range;
  [_input textViewDidChangeSelection:_textView];
}

- (void)toggleUnderline
{
  [_input toggleInlineStyle:ENRMInputStyleTypeUnderline];
}

- (BOOL)isUnderlineActive
{
  return [_input isEffectiveStyleActive:ENRMInputStyleTypeUnderline atPosition:_textView.selectedRange.location];
}

- (void)testCaretAtAWordsEndTakesTheWordAndShowsUnderline
{
  [self type:@"text"];
  [self toggleUnderline];
  XCTAssertTrue([self isUnderlineActive]);
  [self type:@"underline"];

  XCTAssertEqualObjects([_input currentMarkdown], @"_textunderline_");
  XCTAssertTrue([self isUnderlineActive]);
}

- (void)testCaretMovedToTheEndOfAnUnderlinedWordShowsUnderline
{
  [self type:@"hello"];
  [self select:NSMakeRange(3, 0)];
  [self toggleUnderline];
  [self select:NSMakeRange(5, 0)];

  XCTAssertTrue([self isUnderlineActive]);
  [self type:@"xy"];
  XCTAssertEqualObjects([_input currentMarkdown], @"_helloxy_");
  XCTAssertTrue([self isUnderlineActive]);
}

- (void)testDeletionThatLeavesTheCaretAtTheEndOfAnUnderlinedWordShowsUnderline
{
  [self type:@"hello "];
  [self select:NSMakeRange(0, 5)];
  [self toggleUnderline];
  [self select:NSMakeRange(6, 0)];
  XCTAssertFalse([self isUnderlineActive]);
  [self deleteBackward];

  XCTAssertTrue([self isUnderlineActive]);
  [self type:@"x"];
  XCTAssertEqualObjects([_input currentMarkdown], @"_hellox_");
}

- (void)testOneToggleAtTheEndOfAnUnderlinedWordKeepsItAndStopsWhatFollows
{
  [self type:@"on web"];
  [self select:NSMakeRange(0, 6)];
  [self toggleUnderline];
  [self select:NSMakeRange(6, 0)];
  [self toggleUnderline];

  XCTAssertEqualObjects([_input currentMarkdown], @"_on web_");
  XCTAssertFalse([self isUnderlineActive]);
  [self type:@" x"];
  XCTAssertEqualObjects([_input currentMarkdown], @"_on web_ x");
  XCTAssertFalse([self isUnderlineActive]);
}

- (void)testALetterTypedRightAfterTurningItOffJoinsTheWord
{
  [self type:@"hello"];
  [self select:NSMakeRange(3, 0)];
  [self toggleUnderline];
  [self select:NSMakeRange(5, 0)];
  [self toggleUnderline];
  [self type:@"x"];

  XCTAssertEqualObjects([_input currentMarkdown], @"_hellox_");
  XCTAssertTrue([self isUnderlineActive]);
}

- (void)testOneToggleAtTheStartOfAnUnderlinedWordKeepsIt
{
  [self type:@"hello"];
  [self select:NSMakeRange(3, 0)];
  [self toggleUnderline];
  [self select:NSMakeRange(0, 0)];

  XCTAssertTrue([self isUnderlineActive]);
  [self toggleUnderline];
  XCTAssertEqualObjects([_input currentMarkdown], @"_hello_");
  XCTAssertFalse([self isUnderlineActive]);
  [self type:@"a"];
  XCTAssertEqualObjects([_input currentMarkdown], @"_ahello_");
  XCTAssertTrue([self isUnderlineActive]);
}

- (void)testTurningItOnAtTheEndOfAPlainWordOnlyPends
{
  [self type:@"hello"];
  [self toggleUnderline];

  XCTAssertEqualObjects([_input currentMarkdown], @"hello");
  XCTAssertTrue([self isUnderlineActive]);
  [self type:@" world"];
  XCTAssertEqualObjects([_input currentMarkdown], @"hello _world_");
}

- (void)testCaretPastASpaceOrPunctuationShowsNoUnderline
{
  [self type:@"foo! bar"];
  [self select:NSMakeRange(0, 3)];
  [self toggleUnderline];
  [self select:NSMakeRange(4, 0)];
  XCTAssertFalse([self isUnderlineActive]);
  [self select:NSMakeRange(5, 0)];
  XCTAssertFalse([self isUnderlineActive]);
  [self type:@"x"];

  XCTAssertEqualObjects([_input currentMarkdown], @"_foo_! xbar");
}

// A chat input sends by calling setValue(""): what was pending at the old caret must not style the
// next message.
- (void)testClearingDropsAnUnderlinePendingAtTheCaret
{
  [self type:@"hello"];
  [self select:NSMakeRange(3, 0)];
  [self toggleUnderline];
  XCTAssertTrue([self isUnderlineActive]);

  [_input setValue:@""];
  XCTAssertFalse([self isUnderlineActive]);
  [self type:@"next"];
  XCTAssertEqualObjects([_input currentMarkdown], @"next");
}

- (void)testClearingDropsABoldPendingAtTheCaret
{
  [self type:@"hello"];
  [_input toggleInlineStyle:ENRMInputStyleTypeStrong];
  XCTAssertTrue([_input isEffectiveStyleActive:ENRMInputStyleTypeStrong atPosition:5]);

  [_input setValue:@""];
  XCTAssertFalse([_input isEffectiveStyleActive:ENRMInputStyleTypeStrong atPosition:0]);
  [self type:@"next"];
  XCTAssertEqualObjects([_input currentMarkdown], @"next");
}

@end
