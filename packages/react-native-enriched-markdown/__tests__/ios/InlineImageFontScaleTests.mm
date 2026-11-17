#import "../../ios/attachments/ENRMImageAttachment.h"
#import "../../ios/styles/StyleConfig.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

// RCTFontSizeMultiplier() reads the shared application's content size category,
// so the tests pin it to the largest accessibility size (multiplier 3.571).
static UIContentSizeCategory const ENRMInlineImageTestCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
static CGFloat const ENRMInlineImageTestMultiplier = 3.571;

@interface ENRMInlineImageFontScaleTests : XCTestCase
@end

@implementation ENRMInlineImageFontScaleTests {
  Method _categoryMethod;
  IMP _originalCategoryIMP;
}

- (void)setUp
{
  [super setUp];
  _categoryMethod = class_getInstanceMethod([UIApplication class], @selector(preferredContentSizeCategory));
  _originalCategoryIMP = method_setImplementation(
      _categoryMethod, imp_implementationWithBlock(^UIContentSizeCategory(id) { return ENRMInlineImageTestCategory; }));
}

- (void)tearDown
{
  IMP stub = method_setImplementation(_categoryMethod, _originalCategoryIMP);
  imp_removeBlock(stub);
  [super tearDown];
}

- (StyleConfig *)configWithFontScaling:(BOOL)allowFontScaling maxFontSizeMultiplier:(CGFloat)maxMultiplier
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setParagraphFontSize:16];
  [config setInlineImageSize:20];
  // The views pass the observed font scale; any value other than 1 turns scaling on.
  [config setFontScaleMultiplier:allowFontScaling ? ENRMInlineImageTestMultiplier : 1.0];
  [config setMaxFontSizeMultiplier:maxMultiplier];
  return config;
}

- (CGSize)inlineImageSizeForConfig:(StyleConfig *)config
{
  // An empty URL keeps the placeholder and starts no download.
  ENRMImageAttachment *attachment = [ENRMImageAttachment attachmentForURL:@"" config:config isInline:YES];
  CGRect bounds = [attachment attachmentBoundsForTextContainer:nil
                                          proposedLineFragment:CGRectMake(0, 0, 300, 20)
                                                 glyphPosition:CGPointZero
                                                characterIndex:0];
  return bounds.size;
}

- (void)testInlineImageScalesWithParagraphFont
{
  StyleConfig *config = [self configWithFontScaling:YES maxFontSizeMultiplier:0];
  CGFloat fontScale = [config paragraphFont].pointSize / [config paragraphFontSize];
  XCTAssertEqualWithAccuracy(fontScale, ENRMInlineImageTestMultiplier, 0.05);

  CGSize size = [self inlineImageSizeForConfig:config];
  XCTAssertEqualWithAccuracy(size.height, 20 * fontScale, 0.5);
  XCTAssertEqualWithAccuracy(size.width, size.height, 0.01);
}

- (void)testInlineImageRespectsMaxFontSizeMultiplier
{
  StyleConfig *config = [self configWithFontScaling:YES maxFontSizeMultiplier:2];
  XCTAssertEqualWithAccuracy([config paragraphFont].pointSize, 32, 0.5);
  XCTAssertEqualWithAccuracy([self inlineImageSizeForConfig:config].height, 40, 0.01);
}

- (void)testInlineImageKeepsItsSizeWithoutFontScaling
{
  StyleConfig *config = [self configWithFontScaling:NO maxFontSizeMultiplier:0];
  XCTAssertEqualWithAccuracy([config paragraphFont].pointSize, 16, 0.01);
  XCTAssertEqualWithAccuracy([self inlineImageSizeForConfig:config].height, 20, 0.01);
}

@end
