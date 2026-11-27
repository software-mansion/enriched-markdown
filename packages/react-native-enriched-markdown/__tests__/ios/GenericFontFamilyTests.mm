#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import "../../ios/utils/FontUtils.h"
#import <React/RCTFont.h>
#import <XCTest/XCTest.h>

static UIFont *ENRMSystemFontWithDesign(UIFontDescriptorSystemDesign design, CGFloat size)
{
  UIFontDescriptor *descriptor = [[UIFont systemFontOfSize:size].fontDescriptor fontDescriptorWithDesign:design];
  return [UIFont fontWithDescriptor:descriptor size:size];
}

static BOOL ENRMIsSystemMonospaced(UIFont *font)
{
  return
      [font.fontName isEqualToString:ENRMSystemFontWithDesign(UIFontDescriptorSystemDesignMonospaced, 16).fontName] ||
      ([font.familyName hasPrefix:@"."] && (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitMonoSpace));
}

@interface GenericFontFamilyTests : XCTestCase
@end

@implementation GenericFontFamilyTests

- (void)testEachGenericFamilyResolvesToItsSystemDesignInAnyCase
{
  // The CSS generic families React Native's Fabric text accepts, and the system design each maps to.
  NSDictionary<NSString *, UIFontDescriptorSystemDesign> *families = @{
    @"system-ui" : UIFontDescriptorSystemDesignDefault,
    @"ui-sans-serif" : UIFontDescriptorSystemDesignDefault,
    @"ui-serif" : UIFontDescriptorSystemDesignSerif,
    @"ui-rounded" : UIFontDescriptorSystemDesignRounded,
    @"ui-monospace" : UIFontDescriptorSystemDesignMonospaced,
  };
  for (NSString *family in families) {
    NSString *expected = ENRMSystemFontWithDesign(families[family], 16).fontName;
    for (NSString *spelling in @[ family, family.uppercaseString ]) {
      UIFont *font = ENRMUpdateFont(nil, spelling, @16, nil, nil, 1.0);
      XCTAssertEqualObjects(font.fontName, expected, @"%@", spelling);
      XCTAssertEqualWithAccuracy(font.pointSize, 16, 0.01, @"%@", spelling);
    }
  }
}

- (void)testAGenericFamilyKeepsWeightStyleAndFontScale
{
  UIFont *font = ENRMUpdateFont(nil, @"ui-monospace", @16, @"bold", @"italic", 1.5);
  UIFontDescriptorSymbolicTraits traits = font.fontDescriptor.symbolicTraits;
  XCTAssertTrue(traits & UIFontDescriptorTraitMonoSpace);
  XCTAssertTrue(traits & UIFontDescriptorTraitBold);
  XCTAssertTrue(traits & UIFontDescriptorTraitItalic);
  XCTAssertEqualWithAccuracy(font.pointSize, 24, 0.01);

  // A restyled run: the current font's size carries over when no size is given.
  UIFont *restyled = ENRMUpdateFont([UIFont systemFontOfSize:20], @"ui-monospace", nil, @"bold", nil, 1.0);
  XCTAssertTrue(ENRMIsSystemMonospaced(restyled));
  XCTAssertTrue(restyled.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold);
  XCTAssertEqualWithAccuracy(restyled.pointSize, 20, 0.01);
}

- (void)testAnyOtherFamilyIsWhatRCTFontReturns
{
  for (NSString *family in @[ @"Menlo", @"Courier", @"System", @"No Such Family" ]) {
    UIFont *expected = [RCTFont updateFont:nil
                                withFamily:family
                                      size:@16
                                    weight:@"bold"
                                     style:nil
                                   variant:nil
                           scaleMultiplier:1.5];
    XCTAssertEqualObjects(ENRMUpdateFont(nil, family, @16, @"bold", nil, 1.5), expected, @"%@", family);
  }
  XCTAssertEqualObjects(ENRMUpdateFont(nil, nil, @16, nil, nil, 1.0), [RCTFont updateFont:nil
                                                                               withFamily:nil
                                                                                     size:@16
                                                                                   weight:nil
                                                                                    style:nil
                                                                                  variant:nil
                                                                          scaleMultiplier:1.0]);
}

- (void)testUIMonospaceStylesCodeTablesAndTheirRestyledRuns
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setParagraphFontSize:16];
  [config setCodeFontFamily:@"ui-monospace"];
  [config setCodeFontSize:14];
  [config setCodeBlockFontFamily:@"ui-monospace"];
  [config setCodeBlockFontSize:12];
  [config setTableFontFamily:@"ui-monospace"];
  [config setTableFontSize:10];
  [config setFontScaleMultiplier:1.5];

  XCTAssertTrue(ENRMIsSystemMonospaced(config.codeBlockFont));
  XCTAssertEqualWithAccuracy(config.codeBlockFont.pointSize, 18, 0.01);
  XCTAssertTrue(ENRMIsSystemMonospaced(config.tableFont));
  XCTAssertEqualWithAccuracy(config.tableFont.pointSize, 15, 0.01);

  MarkdownASTNode *ast =
      [[[ENRMMarkdownParser alloc] init] parseMarkdown:@"Plain `code`, **bold `strong`** and *it `em`*."
                                                 flags:[ENRMMd4cFlags defaultFlags]
                                                 isGFM:NO];
  NSAttributedString *text =
      ENRMRenderASTNodes(ast.children, config, NO, YES, 0, NSLineBreakStrategyStandard, 0).attributedText;
  UIFont * (^fontOf)(NSString *) = ^UIFont *(NSString *word)
  {
    return [text attribute:NSFontAttributeName atIndex:[text.string rangeOfString:word].location effectiveRange:NULL];
  };

  for (NSString *word in @[ @"code", @"strong", @"em" ]) {
    XCTAssertTrue(ENRMIsSystemMonospaced(fontOf(word)), @"%@ is %@", word, fontOf(word).fontName);
    XCTAssertEqualWithAccuracy(fontOf(word).pointSize, 21, 0.01, @"%@", word);
  }
  XCTAssertTrue(fontOf(@"strong").fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold);
  XCTAssertTrue(fontOf(@"em").fontDescriptor.symbolicTraits & UIFontDescriptorTraitItalic);
  XCTAssertFalse(ENRMIsSystemMonospaced(fontOf(@"Plain")));
}

@end
