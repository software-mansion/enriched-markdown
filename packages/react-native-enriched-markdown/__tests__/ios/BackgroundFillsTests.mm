#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import "../../ios/utils/ENRMTextViewSetup.h"
#import "../../ios/utils/TextViewLayoutManager.h"
#import "../../ios/views/ENRMMarkdownTextView.h"
#import <XCTest/XCTest.h>

static NSString *const kBoxesMarkdown = @"Inline `code` here.\n\n> Quoted text\n\n```\ncode block\n```\n";

static StyleConfig *ENRMBoxesConfig(void)
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setCodeBlockPadding:12];
  [config setBlockquotePadding:12];
  [config setCodeBackgroundColor:UIColor.greenColor];
  [config setBlockquoteBackgroundColor:UIColor.blueColor];
  [config setCodeBlockBackgroundColor:UIColor.redColor];
  return config;
}

static BOOL ENRMColorsEqual(CGColorRef color, UIColor *expected)
{
  return color && CGColorEqualToColor(color, expected.CGColor);
}

@interface ENRMBackgroundFillsTests : XCTestCase
@end

@implementation ENRMBackgroundFillsTests

- (NSAttributedString *)render:(NSString *)markdown config:(StyleConfig *)config
{
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init] parseMarkdown:markdown
                                                                    flags:[ENRMMd4cFlags defaultFlags]
                                                                    isGFM:NO];
  return ENRMRenderASTNodes(ast.children, config, NO, YES, 0, NSLineBreakStrategyStandard).attributedText;
}

- (ENRMMarkdownTextView *)textViewWithConfig:(StyleConfig *)config
{
  ENRMMarkdownTextView *textView = [[ENRMMarkdownTextView alloc] init];
  ENRMAttachLayoutManager(textView, config);
  textView.scrollEnabled = NO;
  textView.frame = CGRectMake(0, 0, 320, 600);
  textView.attributedText = [self render:kBoxesMarkdown config:config];
  [textView layoutIfNeeded];
  return textView;
}

/// The box layers filled with `color`.
- (NSArray<CAShapeLayer *> *)boxesOf:(UITextView *)textView colored:(UIColor *)color
{
  NSMutableArray *boxes = [NSMutableArray array];
  for (CALayer *layer in [self boxesLayerOf:textView].sublayers) {
    if ([layer isKindOfClass:CAShapeLayer.class] && ENRMColorsEqual(((CAShapeLayer *)layer).fillColor, color))
      [boxes addObject:layer];
  }
  return boxes;
}

/// The layer holding the boxes: the bottom sublayer, below every subview's layer.
- (CALayer *)boxesLayerOf:(UITextView *)textView
{
  return textView.layer.sublayers.firstObject;
}

/// The color the layout manager paints at `point` when drawing the text's backgrounds.
- (UIColor *)paintedColorAt:(CGPoint)point layoutManager:(NSLayoutManager *)layoutManager
{
  unsigned char pixel[4] = {0, 0, 0, 0};
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
  CGColorSpaceRelease(space);
  // Flip to UIKit coordinates and move `point` onto the single pixel.
  CGContextTranslateCTM(context, -point.x, point.y + 1);
  CGContextScaleCTM(context, 1, -1);
  UIGraphicsPushContext(context);
  NSRange glyphs = [layoutManager glyphRangeForTextContainer:layoutManager.textContainers.firstObject];
  [layoutManager drawBackgroundForGlyphRange:glyphs atPoint:CGPointZero];
  UIGraphicsPopContext();
  CGContextRelease(context);
  return [UIColor colorWithRed:pixel[0] / 255.0 green:pixel[1] / 255.0 blue:pixel[2] / 255.0 alpha:pixel[3] / 255.0];
}

- (CGPoint)centerOfFillColored:(UIColor *)color in:(TextViewLayoutManager *)layoutManager
{
  __block CGPoint center = CGPointZero;
  [layoutManager enumerateBackgroundFillsAtPoint:CGPointZero
                                      usingBlock:^(UIBezierPath *path, UIColor *fill, UIColor *stroke) {
                                        if ([fill isEqual:color])
                                          center = CGPointMake(CGRectGetMidX(path.bounds), CGRectGetMidY(path.bounds));
                                      }];
  return center;
}

- (void)testBoxesAreShapeLayersAtTheBottomOfTheTextView
{
  ENRMMarkdownTextView *textView = [self textViewWithConfig:ENRMBoxesConfig()];
  CALayer *boxes = [self boxesLayerOf:textView];
  for (UIView *subview in textView.subviews) {
    XCTAssertNotEqual(subview.layer, boxes);
  }

  NSMutableArray<UIColor *> *found = [NSMutableArray array];
  for (CALayer *layer in boxes.sublayers) {
    XCTAssertTrue([layer isKindOfClass:CAShapeLayer.class]);
    for (UIColor *color in @[ UIColor.greenColor, UIColor.blueColor, UIColor.redColor ]) {
      if (ENRMColorsEqual(((CAShapeLayer *)layer).fillColor, color))
        [found addObject:color];
    }
  }
  XCTAssertTrue([found containsObject:UIColor.greenColor], @"inline code box");
  XCTAssertTrue([found containsObject:UIColor.blueColor], @"blockquote box");
  XCTAssertTrue([found containsObject:UIColor.redColor], @"code block box");
}

- (void)testBoxesFollowNewText
{
  StyleConfig *config = ENRMBoxesConfig();
  ENRMMarkdownTextView *textView = [self textViewWithConfig:config];

  textView.attributedText = [self render:@"Only a paragraph." config:config];
  [textView layoutIfNeeded];
  XCTAssertEqual([self boxesLayerOf:textView].sublayers.count, 0u);

  textView.attributedText = [self render:kBoxesMarkdown config:config];
  [textView layoutIfNeeded];
  XCTAssertEqual([self boxesOf:textView colored:UIColor.redColor].count, 1u);
}

- (void)testBoxesFollowWidthChanges
{
  ENRMMarkdownTextView *textView = [self textViewWithConfig:ENRMBoxesConfig()];
  CGFloat wide = CGRectGetWidth([self boxesOf:textView colored:UIColor.redColor].firstObject.frame);

  textView.frame = CGRectMake(0, 0, 220, 600);
  [textView layoutIfNeeded];
  CGFloat narrow = CGRectGetWidth([self boxesOf:textView colored:UIColor.redColor].firstObject.frame);

  // The code block box spans the text container, so it narrows with the view.
  XCTAssertEqualWithAccuracy(wide - narrow, 100, 1);
}

- (void)testBoxesFollowConfigChanges
{
  ENRMMarkdownTextView *textView = [self textViewWithConfig:ENRMBoxesConfig()];
  StyleConfig *config = ENRMBoxesConfig();
  [config setCodeBlockBackgroundColor:UIColor.purpleColor];
  [textView.layoutManager setValue:config forKey:@"config"];
  [textView layoutIfNeeded];

  XCTAssertEqual([self boxesOf:textView colored:UIColor.redColor].count, 0u);
  XCTAssertEqual([self boxesOf:textView colored:UIColor.purpleColor].count, 1u);
}

- (void)testHostIsReleasedWithItsTextView
{
  TextViewLayoutManager *layoutManager;
  @autoreleasepool {
    ENRMMarkdownTextView *textView = [self textViewWithConfig:ENRMBoxesConfig()];
    layoutManager = (TextViewLayoutManager *)textView.layoutManager;
    XCTAssertNotNil(layoutManager.backgroundFillsHost);
  }
  XCTAssertNil(layoutManager.backgroundFillsHost);
}

- (void)testBoxesStayBeneathSubviewsAddedLater
{
  ENRMMarkdownTextView *textView = [self textViewWithConfig:ENRMBoxesConfig()];
  CALayer *boxes = [self boxesLayerOf:textView];
  // UIKit adds the selection highlight's view lazily.
  [textView insertSubview:[[UIView alloc] init] atIndex:0];
  XCTAssertEqual(textView.layer.sublayers.firstObject, boxes);
}

- (void)testTextPassLeavesTheBoxesToTheHost
{
  ENRMMarkdownTextView *textView = [self textViewWithConfig:ENRMBoxesConfig()];
  TextViewLayoutManager *layoutManager = (TextViewLayoutManager *)textView.layoutManager;
  CGPoint codeBlock = [self centerOfFillColored:UIColor.redColor in:layoutManager];
  XCTAssertFalse(CGPointEqualToPoint(codeBlock, CGPointZero));

  CGFloat red = 0, green = 0, blue = 0, alpha = 0;
  [[self paintedColorAt:codeBlock layoutManager:layoutManager] getRed:&red green:&green blue:&blue alpha:&alpha];
  XCTAssertEqualWithAccuracy(alpha, 0, 0.01, @"the text pass painted the code block box");

  // Without a host, e.g. on macOS, the text pass still paints the box itself.
  layoutManager.backgroundFillsHost = nil;
  [[self paintedColorAt:codeBlock layoutManager:layoutManager] getRed:&red green:&green blue:&blue alpha:&alpha];
  XCTAssertEqualWithAccuracy(red, 1, 0.01);
  XCTAssertEqualWithAccuracy(green, 0, 0.01);
  XCTAssertEqualWithAccuracy(blue, 0, 0.01);
  XCTAssertEqualWithAccuracy(alpha, 1, 0.01);
}

@end
