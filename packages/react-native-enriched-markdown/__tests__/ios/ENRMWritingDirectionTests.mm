#import "LastElementUtils.h"
#import "ParagraphStyleUtils.h"
#import <XCTest/XCTest.h>

@interface ENRMWritingDirectionTests : XCTestCase
@end

@implementation ENRMWritingDirectionTests

- (void)testFirstStrongDetectsRightToLeftScripts
{
  XCTAssertEqual(ENRMFirstStrongDirection(@"مرحبا بالعالم"), NSWritingDirectionRightToLeft);
  XCTAssertEqual(ENRMFirstStrongDirection(@"שלום עולם"), NSWritingDirectionRightToLeft);
  XCTAssertEqual(ENRMFirstStrongDirection(@"سلام دنیا"), NSWritingDirectionRightToLeft);
  XCTAssertEqual(ENRMFirstStrongDirection(@"\U0001E900\U0001E901"), NSWritingDirectionRightToLeft, @"Adlam");
  XCTAssertEqual(ENRMFirstStrongDirection(@"\U00010C80\U00010C81"), NSWritingDirectionRightToLeft, @"Old Hungarian");
  XCTAssertEqual(ENRMFirstStrongDirection(@"\U00010900\U00010901"), NSWritingDirectionRightToLeft, @"Phoenician");
  XCTAssertEqual(ENRMFirstStrongDirection(@"\U0001EE00\U0001EE01"), NSWritingDirectionRightToLeft,
                 @"Arabic mathematical alphabet");
}

- (void)testFirstStrongDetectsLeftToRightScripts
{
  XCTAssertEqual(ENRMFirstStrongDirection(@"Hello"), NSWritingDirectionLeftToRight);
  XCTAssertEqual(ENRMFirstStrongDirection(@"こんにちは"), NSWritingDirectionLeftToRight);
  XCTAssertEqual(ENRMFirstStrongDirection(@"\U00010400\U00010401"), NSWritingDirectionLeftToRight, @"Deseret");
  XCTAssertEqual(ENRMFirstStrongDirection(@"\U00011005\U00011006"), NSWritingDirectionLeftToRight, @"Brahmi");
  XCTAssertEqual(ENRMFirstStrongDirection(@"\U0001E7E0\U0001E7E1"), NSWritingDirectionLeftToRight,
                 @"Ethiopic Extended-B");
}

- (void)testFirstStrongSkipsLeadingNeutralCharacters
{
  XCTAssertEqual(ENRMFirstStrongDirection(@"123 مرحبا"), NSWritingDirectionRightToLeft);
  XCTAssertEqual(ENRMFirstStrongDirection(@"(\"Hello\") مرحبا"), NSWritingDirectionLeftToRight);
  XCTAssertEqual(ENRMFirstStrongDirection(@"😀 سلام"), NSWritingDirectionRightToLeft);
  XCTAssertEqual(ENRMFirstStrongDirection(@"\u2764\uFE0F مرحبا"), NSWritingDirectionRightToLeft,
                 @"emoji variation selector");
  XCTAssertEqual(ENRMFirstStrongDirection(@"\U0001E944Hello"), NSWritingDirectionLeftToRight, @"Adlam combining mark");
}

- (void)testFirstStrongHonorsDirectionalMarks
{
  XCTAssertEqual(ENRMFirstStrongDirection(@"\u200F123"), NSWritingDirectionRightToLeft);
  XCTAssertEqual(ENRMFirstStrongDirection(@"\u061C123"), NSWritingDirectionRightToLeft);
  XCTAssertEqual(ENRMFirstStrongDirection(@"\u200Eمرحبا"), NSWritingDirectionLeftToRight);
}

- (void)testFirstStrongIsNaturalWithoutStrongCharacters
{
  XCTAssertEqual(ENRMFirstStrongDirection(@"123 456."), NSWritingDirectionNatural);
  XCTAssertEqual(ENRMFirstStrongDirection(@"\U0001F600"), NSWritingDirectionNatural);
  XCTAssertEqual(ENRMFirstStrongDirection(@""), NSWritingDirectionNatural);
}

- (void)testParagraphsResolveFromTheirOwnContent
{
  NSMutableAttributedString *output = [[NSMutableAttributedString alloc]
      initWithString:@"😀 Hello\n🙂🙂 مرحبا\nשלום\n\u200F123\n\U0001E900\U0001E901"];

  ENRMApplyFirstStrongParagraphDirections(output, NSWritingDirectionLeftToRight);

  XCTAssertEqual([self directionOf:@"Hello" in:output], NSWritingDirectionLeftToRight);
  XCTAssertEqual([self directionOf:@"مرحبا" in:output], NSWritingDirectionRightToLeft);
  XCTAssertEqual([self directionOf:@"שלום" in:output], NSWritingDirectionRightToLeft);
  XCTAssertEqual([self directionOf:@"\u200F123" in:output], NSWritingDirectionRightToLeft);
  XCTAssertEqual([self directionOf:@"\U0001E900" in:output], NSWritingDirectionRightToLeft);
}

- (void)testNeutralParagraphFallsBackToTheLayoutDirection
{
  NSMutableAttributedString *output = [[NSMutableAttributedString alloc] initWithString:@"Hello\n123"];

  ENRMApplyFirstStrongParagraphDirections(output, NSWritingDirectionRightToLeft);

  XCTAssertEqual([self directionOf:@"Hello" in:output], NSWritingDirectionLeftToRight);
  XCTAssertEqual([self directionOf:@"123" in:output], NSWritingDirectionRightToLeft);
}

- (void)testCodeBlocksKeepTheirDirection
{
  NSMutableAttributedString *output = [[NSMutableAttributedString alloc] initWithString:@"مرحبا"];
  [output addAttribute:CodeBlockAttributeName value:@YES range:NSMakeRange(0, output.length)];

  ENRMApplyFirstStrongParagraphDirections(output, NSWritingDirectionRightToLeft);

  XCTAssertEqual([self directionOf:@"مرحبا" in:output], NSWritingDirectionNatural);
}

- (NSWritingDirection)directionOf:(NSString *)text in:(NSAttributedString *)output
{
  NSRange range = [output.string rangeOfString:text];
  XCTAssertNotEqual(range.location, (NSUInteger)NSNotFound, @"%@ was not found", text);
  NSParagraphStyle *style = [output attribute:NSParagraphStyleAttributeName atIndex:range.location effectiveRange:nil];
  return style ? style.baseWritingDirection : NSWritingDirectionNatural;
}

@end
