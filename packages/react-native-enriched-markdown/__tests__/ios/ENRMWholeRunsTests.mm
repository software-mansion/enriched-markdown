#import "../../ios/utils/CodeBackground.h"
#import <XCTest/XCTest.h>

// A tile draws the backgrounds of the text it shows: a code run crossing its edge is still one box.
@interface ENRMWholeRunsTests : XCTestCase
@end

@implementation ENRMWholeRunsTests

- (NSArray<NSValue *> *)runsIn:(NSAttributedString *)text range:(NSRange)range
{
  NSMutableArray<NSValue *> *runs = [NSMutableArray array];
  ENRMEnumerateWholeRuns(text, CodeAttributeName, range,
                         ^(NSRange run) { [runs addObject:[NSValue valueWithRange:run]]; });
  return runs;
}

- (void)testARunCrossingAnEdgeIsReportedWhole
{
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[@"" stringByPaddingToLength:100
                                                                                                        withString:@"a"
                                                                                                   startingAtIndex:0]];
  [text addAttribute:CodeAttributeName value:@YES range:NSMakeRange(10, 20)];
  [text addAttribute:CodeAttributeName value:@YES range:NSMakeRange(40, 5)];
  [text addAttribute:CodeAttributeName value:@YES range:NSMakeRange(60, 30)];

  NSArray<NSValue *> *expected = @[
    [NSValue valueWithRange:NSMakeRange(10, 20)], [NSValue valueWithRange:NSMakeRange(40, 5)],
    [NSValue valueWithRange:NSMakeRange(60, 30)]
  ];
  XCTAssertEqualObjects([self runsIn:text range:NSMakeRange(20, 50)], expected);
  XCTAssertEqualObjects([self runsIn:text range:NSMakeRange(12, 3)], @[ expected[0] ]);
  XCTAssertEqualObjects([self runsIn:text range:NSMakeRange(31, 8)], @[]);
}

// Other attributes inside a run (a link in code) may split the enumeration, not the box.
- (void)testARunSplitByOtherAttributesIsOneBox
{
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"0123456789abcdefghij"];
  [text addAttribute:CodeAttributeName value:@YES range:NSMakeRange(2, 16)];
  [text addAttribute:NSLinkAttributeName value:@"https://e.com" range:NSMakeRange(6, 4)];
  XCTAssertEqualObjects([self runsIn:text range:NSMakeRange(8, 4)], @[ [NSValue valueWithRange:NSMakeRange(2, 16)] ]);
}

@end
