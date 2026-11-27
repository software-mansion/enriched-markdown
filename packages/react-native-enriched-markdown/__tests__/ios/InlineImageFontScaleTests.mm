#import "../../ios/attachments/ENRMImageAttachment.h"
#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <stdatomic.h>

static CGFloat const ENRMInlineImageTestMultiplier = 3.571;
// Reads of the shared application's content size category (#1120): rendering can run on the
// layout thread, so it must take the scale it was given and never read UIKit for it.
static atomic_int ENRMContentSizeCategoryReads;

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
  atomic_store(&ENRMContentSizeCategoryReads, 0);
  _originalCategoryIMP =
      method_setImplementation(_categoryMethod, imp_implementationWithBlock(^UIContentSizeCategory(id) {
                                 atomic_fetch_add(&ENRMContentSizeCategoryReads, 1);
                                 return UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
                               }));
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
  // The views pass the observed font scale; 1 means no scaling.
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

- (void)testRenderingOffMainUsesTheGivenScaleWithoutReadingUIKit
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setParagraphFontSize:16];
  [config setParagraphLineHeight:20];
  [config setCodeFontSize:14];
  [config setFontScaleMultiplier:1.5];
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init]
      parseMarkdown:@"# Title\n\nSome `code` and **bold**.\n\n> quote\n\n- item\n\n```\nblock\n```\n"
              flags:[ENRMMd4cFlags defaultFlags]
              isGFM:NO];

  __block NSAttributedString *text;
  __block int reads = -1;
  XCTestExpectation *rendered = [self expectationWithDescription:@"rendered"];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    atomic_store(&ENRMContentSizeCategoryReads, 0);
    text = ENRMRenderASTNodes(ast.children, config, NO, YES, 0, NSLineBreakStrategyStandard, 0).attributedText;
    reads = atomic_load(&ENRMContentSizeCategoryReads);
    [rendered fulfill];
  });
  [self waitForExpectations:@[ rendered ] timeout:10];

  XCTAssertEqual(reads, 0);
  NSRange some = [text.string rangeOfString:@"Some"];
  UIFont *font = [text attribute:NSFontAttributeName atIndex:some.location effectiveRange:NULL];
  XCTAssertEqualWithAccuracy(font.pointSize, 24, 0.01);
  NSParagraphStyle *paragraph = [text attribute:NSParagraphStyleAttributeName
                                        atIndex:some.location
                                 effectiveRange:NULL];
  XCTAssertEqualWithAccuracy(paragraph.minimumLineHeight, 30, 0.01);
  NSRange code = [text.string rangeOfString:@"code"];
  UIFont *codeFont = [text attribute:NSFontAttributeName atIndex:code.location effectiveRange:NULL];
  XCTAssertEqualWithAccuracy(codeFont.pointSize, 21, 0.01);
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
