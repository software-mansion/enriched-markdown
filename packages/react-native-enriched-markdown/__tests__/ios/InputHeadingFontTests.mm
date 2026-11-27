#import "../../ios/input/ENRMInputFormatterStyle.h"
#import "../../ios/utils/FontUtils.h"
#import <XCTest/XCTest.h>

@interface InputHeadingFontTests : XCTestCase
@end

@implementation InputHeadingFontTests

static UIFont *ENRMBoldHeadingOver(UIFont *baseFont)
{
  ENRMInputFormatterStyle *style = [[ENRMInputFormatterStyle alloc] init];
  style.baseFont = baseFont;
  [style setHeadingFontSize:24 forLevel:1];
  [style setHeadingFontWeight:@"bold" forLevel:1];
  return [style headingFontForLevel:1];
}

// A custom font's descriptor names its exact face, so a weight trait added to it was ignored (#1163).
- (void)testHeadingWeightResolvesWithinACustomFamilyLikeTheRenderer
{
  UIFont *heading = ENRMBoldHeadingOver([UIFont fontWithName:@"AvenirNext-Regular" size:16]);
  XCTAssertEqualObjects(heading.fontName, @"AvenirNext-Bold");
  XCTAssertEqualObjects(heading, ENRMUpdateFont(nil, @"Avenir Next", @24, @"bold", nil, 1.0));

  XCTAssertEqualObjects(ENRMBoldHeadingOver([UIFont fontWithName:@"AvenirNext-Italic" size:16]).fontName,
                        @"AvenirNext-BoldItalic");
}

- (void)testHeadingWeightOverTheSystemFont
{
  XCTAssertEqualObjects(ENRMBoldHeadingOver([UIFont systemFontOfSize:16]).fontName,
                        [UIFont systemFontOfSize:24 weight:UIFontWeightBold].fontName);
}

@end
