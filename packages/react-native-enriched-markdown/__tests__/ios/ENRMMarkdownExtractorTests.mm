#import "ListItemRenderer.h"
#import "MarkdownExtractor.h"
#import <XCTest/XCTest.h>

@interface ENRMMarkdownExtractorTests : XCTestCase
@end

@implementation ENRMMarkdownExtractorTests

- (UIFont *)enrmExtractorBoldFont
{
  return [UIFont boldSystemFontOfSize:16];
}

- (void)testBoldSplitAcrossAttributeRunsCopiesAsOneSpan
{
  NSMutableAttributedString *text =
      [[NSMutableAttributedString alloc] initWithString:@"What"
                                             attributes:@{NSFontAttributeName : [self enrmExtractorBoldFont]}];
  // Any attribute without inline meaning splits the run after the first character.
  [text addAttribute:@"ENRMTestUnrelatedAttribute" value:@YES range:NSMakeRange(0, 1)];

  XCTAssertEqualObjects(extractMarkdownFromAttributedString(text, NSMakeRange(0, text.length)), @"**What**");
}

- (void)testBoldAtListItemStartCopiesAsOneSpan
{
  NSDictionary *listAttrs = @{
    ListDepthAttribute : @0,
    ListTypeAttribute : @0,
    ListItemNumberAttribute : @1,
  };
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"What: next"
                                                                           attributes:listAttrs];
  [text addAttribute:NSFontAttributeName value:[self enrmExtractorBoldFont] range:NSMakeRange(0, 4)];
  [text addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:16] range:NSMakeRange(4, 6)];
  // ListItemRenderer anchors the bullet marker on the item's first grapheme.
  [text addAttribute:ListItemMarkerStartAttribute value:@[] range:NSMakeRange(0, 1)];

  XCTAssertEqualObjects(extractMarkdownFromAttributedString(text, NSMakeRange(0, text.length)), @"- **What**: next");
}

- (void)testAdjacentRunsWithDifferentFormattingStayWrappedSeparately
{
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"ab"];
  [text addAttribute:NSFontAttributeName value:[self enrmExtractorBoldFont] range:NSMakeRange(0, 1)];
  [text addAttribute:NSFontAttributeName value:[UIFont italicSystemFontOfSize:16] range:NSMakeRange(1, 1)];

  XCTAssertEqualObjects(extractMarkdownFromAttributedString(text, NSMakeRange(0, text.length)), @"**a***b*");
}

@end
