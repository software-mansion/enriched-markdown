#import "../../ios/input/ENRMInputFormatterStyle.h"
#import "../../ios/utils/FontUtils.h"
#import <XCTest/XCTest.h>

@interface InputHeadingFontTests : XCTestCase
@end

@implementation InputHeadingFontTests

static UIFont *ENRMHeadingOver(UIFont *baseFont, NSString *weight)
{
  ENRMInputFormatterStyle *style = [[ENRMInputFormatterStyle alloc] init];
  style.baseFont = baseFont;
  [style setHeadingFontSize:24 forLevel:1];
  [style setHeadingFontWeight:weight forLevel:1];
  return [style headingFontForLevel:1];
}

// A custom font's descriptor names its exact face, so a weight trait added to it was ignored (#1163).
- (void)testHeadingWeightResolvesWithinACustomFamilyLikeTheRenderer
{
  UIFont *heading = ENRMHeadingOver([UIFont fontWithName:@"AvenirNext-Regular" size:16], @"bold");
  XCTAssertEqualObjects(heading.fontName, @"AvenirNext-Bold");
  XCTAssertEqualObjects(heading, ENRMUpdateFont(nil, @"Avenir Next", @24, @"bold", nil, 1.0));

  XCTAssertEqualObjects(ENRMHeadingOver([UIFont fontWithName:@"AvenirNext-Italic" size:16], @"bold").fontName,
                        @"AvenirNext-BoldItalic");
  // RCTFont alone would resolve a weight name it doesn't know to regular.
  XCTAssertEqualObjects(ENRMHeadingOver([UIFont fontWithName:@"AvenirNext-Regular" size:16], @"semibold").fontName,
                        @"AvenirNext-DemiBold");
}

- (void)testHeadingWeightOverTheSystemFont
{
  XCTAssertEqualObjects(ENRMHeadingOver([UIFont systemFontOfSize:16], @"bold").fontName,
                        [UIFont systemFontOfSize:24 weight:UIFontWeightBold].fontName);
}

@end
