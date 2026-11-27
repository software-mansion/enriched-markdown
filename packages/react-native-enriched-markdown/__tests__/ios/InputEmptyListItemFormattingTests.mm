#import "../../ios/input/ENRMBlockStore.h"
#import "../../ios/input/ENRMInputBlockType.h"
#import "../../ios/input/ENRMInputFormatter.h"
#import "../../ios/input/ENRMInputFormatterStyle.h"
#import "../../ios/input/ENRMInputLayoutManager.h"
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
  NSTextStorage *_textStorage;
  UITextView *_textView;
  ENRMInputFormatter *_formatter;
  ENRMInputFormatterStyle *_style;
}

- (void)setUp
{
  [super setUp];
  ENRMInputLayoutManager *layoutManager = [[ENRMInputLayoutManager alloc] init];
  layoutManager.usesFontLeading = NO;
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(0, CGFLOAT_MAX)];
  textContainer.widthTracksTextView = YES;
  textContainer.lineFragmentPadding = 0;
  [layoutManager addTextContainer:textContainer];
  _textStorage = [[NSTextStorage alloc] init];
  [_textStorage addLayoutManager:layoutManager];
  _textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) textContainer:textContainer];
  _textView.textContainerInset = UIEdgeInsetsZero;
  _textView.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
  _textView.backgroundColor = [UIColor whiteColor];
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

- (NSArray<NSNumber *> *)drawnMarkerCenters
{
  [_textView layoutIfNeeded];
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.scale = 4;
  format.opaque = YES;
  UITextView *textView = _textView;
  UIImage *image = [[[UIGraphicsImageRenderer alloc] initWithSize:textView.bounds.size format:format]
      imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [textView.layer renderInContext:context.CGContext];
      }];

  size_t width = CGImageGetWidth(image.CGImage);
  size_t height = CGImageGetHeight(image.CGImage);
  NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef bitmap = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, colorSpace,
                                              (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
  CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), image.CGImage);
  CGContextRelease(bitmap);
  CGColorSpaceRelease(colorSpace);

  const uint8_t *bytes = (const uint8_t *)pixels.bytes;
  size_t markerColumns = (size_t)(([self headIndentAtIndex:0] - 1) * format.scale);
  NSMutableArray<NSNumber *> *centers = [NSMutableArray array];
  NSInteger firstDarkRow = -1;
  for (size_t row = 0; row <= height; row++) {
    BOOL dark = NO;
    for (size_t column = 0; row < height && column < markerColumns && !dark; column++) {
      const uint8_t *pixel = bytes + (row * width + column) * 4;
      dark = pixel[0] + pixel[1] + pixel[2] < 3 * 128;
    }
    if (dark && firstDarkRow < 0) {
      firstDarkRow = (NSInteger)row;
    } else if (!dark && firstDarkRow >= 0) {
      [centers addObject:@((firstDarkRow + row) / 2.0 / format.scale)];
      firstDarkRow = -1;
    }
  }
  return centers;
}

- (void)testTheMarkerOfAnEmptyItemIsLevelWithTheMarkerOfItsText
{
  for (NSNumber *lineHeight in @[ @0, @26 ]) {
    _style.baseLineHeight = lineHeight.doubleValue;
    [self importMarkdown:@"- A\n- A\n- \n- B"];
    NSArray<NSNumber *> *empty = [self drawnMarkerCenters];
    [self importMarkdown:@"- A\n- A\n- C\n- B"];
    NSArray<NSNumber *> *typed = [self drawnMarkerCenters];

    XCTAssertEqual(empty.count, 4u, @"line height %@", lineHeight);
    XCTAssertEqual(typed.count, 4u, @"line height %@", lineHeight);
    if (empty.count == 4 && typed.count == 4) {
      XCTAssertEqualWithAccuracy(empty[2].doubleValue, typed[2].doubleValue, 0.5, @"line height %@", lineHeight);
    }
  }
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
