#import "../../ios/input/ENRMBlockStore.h"
#import "../../ios/input/ENRMInputBlockType.h"
#import "../../ios/input/ENRMInputFormatter.h"
#import "../../ios/input/ENRMInputFormatterStyle.h"
#import "../../ios/input/ENRMInputParser.h"
#import <XCTest/XCTest.h>

// An imported empty list item is a zero-length block on a line of its own. The
// list marker drawer finds a line's marker through the block attributes on its
// first character, so the formatter has to stamp those on the empty line's
// terminator; otherwise the item draws no marker and no indent unless the caret
// is on it.

@interface ENRMInputEmptyListItemFormattingTests : XCTestCase
@end

@implementation ENRMInputEmptyListItemFormattingTests {
  UITextView *_textView;
  ENRMInputFormatter *_formatter;
  ENRMInputFormatterStyle *_style;
}

- (void)setUp
{
  [super setUp];
  _textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
  _formatter = [[ENRMInputFormatter alloc] init];
  _style = [[ENRMInputFormatterStyle alloc] init];
  _style.baseFont = [UIFont systemFontOfSize:16];
  _style.baseTextColor = [UIColor blackColor];
}

/// Imports `markdown` the way the input view does: the parsed blocks settle in
/// the block store, then the formatter stamps them on the text.
- (NSArray<ENRMBlockRange *> *)importMarkdown:(NSString *)markdown
{
  ENRMParseResult *parsed = [[[ENRMInputParser alloc] init] parseToPlainTextAndRanges:markdown];
  ENRMBlockStore *store = [[ENRMBlockStore alloc] init];
  [store setRanges:parsed.blockRanges];
  [store normalizeToLineBoundsInText:parsed.plainText];
  _textView.text = parsed.plainText;
  [_formatter applyBlockRanges:store.allRanges toTextView:_textView style:_style];
  return store.allRanges;
}

- (NSNumber *)attribute:(NSAttributedStringKey)name atIndex:(NSUInteger)index
{
  return [_textView.textStorage attribute:name atIndex:index effectiveRange:NULL];
}

- (CGFloat)headIndentAtIndex:(NSUInteger)index
{
  NSParagraphStyle *paragraph = [_textView.textStorage attribute:NSParagraphStyleAttributeName
                                                         atIndex:index
                                                  effectiveRange:NULL];
  return paragraph.headIndent;
}

- (void)testAnEmptyItemBetweenItemsIsStampedOnItsLine
{
  [self importMarkdown:@"1. a\n2. \n3. c"];
  XCTAssertEqualObjects(_textView.text, @"a\n\nc");

  XCTAssertEqualObjects([self attribute:ENRMBlockTypeAttributeName atIndex:2], @(ENRMInputBlockTypeOrderedListItem));
  XCTAssertEqualObjects([self attribute:ENRMBlockOrdinalAttributeName atIndex:2], @2);
  XCTAssertEqualObjects([self attribute:ENRMBlockLevelAttributeName atIndex:2], @0);
  XCTAssertGreaterThan([self headIndentAtIndex:2], 0);
  XCTAssertEqual([self headIndentAtIndex:2], [self headIndentAtIndex:0]);
}

- (void)testAnEmptyBulletKeepsItsDepth
{
  [self importMarkdown:@"- a\n  - b\n  - \n- d"];
  XCTAssertEqualObjects(_textView.text, @"a\nb\n\nd");

  XCTAssertEqualObjects([self attribute:ENRMBlockTypeAttributeName atIndex:4], @(ENRMInputBlockTypeUnorderedListItem));
  XCTAssertEqualObjects([self attribute:ENRMBlockLevelAttributeName atIndex:4], @1);
  XCTAssertEqual([self headIndentAtIndex:4], [self headIndentAtIndex:2]);
}

- (void)testTheStampLeavesWithTheEmptyItem
{
  NSArray<ENRMBlockRange *> *blocks = [self importMarkdown:@"- a\n- \n- c"];
  XCTAssertNotNil([self attribute:ENRMBlockTypeAttributeName atIndex:2]);

  NSMutableArray<ENRMBlockRange *> *withoutEmptyItem = [blocks mutableCopy];
  [withoutEmptyItem removeObjectAtIndex:1];
  [_formatter applyBlockRanges:withoutEmptyItem toTextView:_textView style:_style];

  XCTAssertNil([self attribute:ENRMBlockTypeAttributeName atIndex:2]);
  XCTAssertEqual([self headIndentAtIndex:2], 0);
}

- (void)testAnEmptyLineThatIsNotAnItemStaysPlain
{
  [self importMarkdown:@"- a\n\nc"];
  XCTAssertEqualObjects(_textView.text, @"a\n\nc");

  XCTAssertNil([self attribute:ENRMBlockTypeAttributeName atIndex:2]);
}

@end
