#import "../../ios/attachments/ENRMImageAttachment.h"
#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

/// Inline images fit inside their square (contain) and centre on the text's cap height.
@interface ENRMInlineImagePlacementTests : XCTestCase
@property (nonatomic, strong) NSMutableArray<NSString *> *temporaryFiles;
@end

@implementation ENRMInlineImagePlacementTests

- (void)setUp
{
  [super setUp];
  self.temporaryFiles = [NSMutableArray array];
}

- (void)tearDown
{
  for (NSString *path in self.temporaryFiles) {
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
  }
  [super tearDown];
}

- (NSTextStorage *)render:(NSString *)markdown
                imageSize:(CGSize)imageSize
         strongFontFamily:(NSString *)strongFontFamily
                    image:(ENRMImageAttachment *__strong *)image
                    index:(NSUInteger *)index
{
  NSData *png = [[[UIGraphicsImageRenderer alloc] initWithSize:imageSize]
      PNGDataWithActions:^(UIGraphicsImageRendererContext *context) {
        [[UIColor redColor] setFill];
        [context fillRect:CGRectMake(0, 0, imageSize.width, imageSize.height)];
      }];
  NSString *path = [NSTemporaryDirectory()
      stringByAppendingPathComponent:[NSString stringWithFormat:@"enrm-inline-%@.png", [NSUUID UUID].UUIDString]];
  [png writeToFile:path atomically:YES];
  [self.temporaryFiles addObject:path];

  StyleConfig *config = [[StyleConfig alloc] init];
  [config setInlineImageSize:30];
  [config setParagraphFontSize:18];
  [config setH1FontSize:30];
  if (strongFontFamily) {
    [config setStrongFontFamily:strongFontFamily];
  }
  NSString *imageMarkdown = [NSString stringWithFormat:@"![red](%@)", [NSURL fileURLWithPath:path].absoluteString];
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init]
      parseMarkdown:[markdown stringByReplacingOccurrencesOfString:@"{image}" withString:imageMarkdown]
              flags:[ENRMMd4cFlags defaultFlags]
              isGFM:YES];
  NSAttributedString *text =
      ENRMRenderASTNodes(ast.children, config, NO, YES, 0, NSLineBreakStrategyStandard, 0).attributedText;

  [text enumerateAttribute:NSAttachmentAttributeName
                   inRange:NSMakeRange(0, text.length)
                   options:0
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  if ([value isKindOfClass:[ENRMImageAttachment class]]) {
                    *image = value;
                    *index = range.location;
                    *stop = YES;
                  }
                }];
  XCTAssertNotNil(*image, @"%@: no image", markdown);
  return [[NSTextStorage alloc] initWithAttributedString:text];
}

- (void)testInlineImageIsCentredOnTheCapHeight
{
  for (NSArray<NSString *> *item in @[ @[ @"HH {image} HH", @"" ], @[ @"# HH {image} HH", @"" ] ]) {
    ENRMImageAttachment *image = nil;
    NSUInteger index = 0;
    NSTextStorage *storage = [self render:item[0]
                                imageSize:CGSizeMake(32, 32)
                         strongFontFamily:item[1].length > 0 ? item[1] : nil
                                    image:&image
                                    index:&index];

    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(300, CGFLOAT_MAX)];
    container.lineFragmentPadding = 0;
    NSLayoutManager *manager = [[NSLayoutManager alloc] init];
    [manager addTextContainer:container];
    [storage addLayoutManager:manager];
    [manager ensureLayoutForTextContainer:container];

    // TextKit places a text glyph on the baseline and an attachment glyph at the image's bottom edge.
    NSUInteger glyph = [manager glyphIndexForCharacterAtIndex:index];
    NSUInteger textGlyph = [manager glyphIndexForCharacterAtIndex:index + 2];
    CGFloat lineTop = CGRectGetMinY([manager lineFragmentRectForGlyphAtIndex:glyph effectiveRange:NULL]);
    CGFloat imageBottom = lineTop + [manager locationForGlyphAtIndex:glyph].y;
    CGFloat baseline = lineTop + [manager locationForGlyphAtIndex:textGlyph].y;
    CGFloat imageHeight = [manager attachmentSizeForGlyphAtIndex:glyph].height;
    UIFont *textFont = [storage attribute:NSFontAttributeName atIndex:index + 2 effectiveRange:NULL];

    XCTAssertEqualWithAccuracy(imageHeight, 30, 0.5, @"%@", item[0]);
    XCTAssertEqualWithAccuracy(imageBottom - imageHeight / 2, baseline - textFont.capHeight / 2, 0.5, @"%@ %@", item[0],
                               item[1]);
  }
}

- (void)testInlineImageTakesTheFontOfStrongText
{
  ENRMImageAttachment *image = nil;
  NSUInteger index = 0;
  NSTextStorage *storage = [self render:@"**HH {image} HH**"
                              imageSize:CGSizeMake(32, 32)
                       strongFontFamily:@"Georgia"
                                  image:&image
                                  index:&index];
  UIFont *textFont = [storage attribute:NSFontAttributeName atIndex:index + 2 effectiveRange:NULL];

  XCTAssertEqualObjects(textFont.familyName, @"Georgia");
  XCTAssertEqualObjects(image.textFont, textFont);
}

- (void)testWideInlineImageFitsInsideItsSquare
{
  ENRMImageAttachment *image = nil;
  NSUInteger index = 0;
  [self render:@"HH {image} HH" imageSize:CGSizeMake(64, 32) strongFontFamily:nil image:&image index:&index];
  XCTestExpectation *loaded = [self expectationWithDescription:@"the image loads"];
  loaded.assertForOverFulfill = NO;
  image.onImageLoaded = ^{ [loaded fulfill]; };
  [self waitForExpectations:@[ loaded ] timeout:5];
  image.onImageLoaded = nil;

  CGImageRef square = ((UIImage *)[image valueForKey:@"loadedImage"]).CGImage;
  size_t w = CGImageGetWidth(square), h = CGImageGetHeight(square);
  NSMutableData *pixels = [NSMutableData dataWithLength:w * h * 4];
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(pixels.mutableBytes, w, h, 8, w * 4, space,
                                               kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
  CGContextDrawImage(context, CGRectMake(0, 0, w, h), square);
  CGContextRelease(context);
  CGColorSpaceRelease(space);

  const uint8_t *bytes = (const uint8_t *)pixels.bytes;
  NSInteger top = NSIntegerMax, bottom = -1, left = NSIntegerMax, right = -1;
  for (size_t y = 0; y < h; y++) {
    for (size_t x = 0; x < w; x++) {
      const uint8_t *p = bytes + (y * w + x) * 4;
      if (p[0] > 200 && p[1] < 80 && p[2] < 80) {
        top = MIN(top, (NSInteger)y), bottom = MAX(bottom, (NSInteger)y);
        left = MIN(left, (NSInteger)x), right = MAX(right, (NSInteger)x);
      }
    }
  }

  XCTAssertEqual(w, h, @"the square");
  XCTAssertEqualWithAccuracy(right - left + 1, w, 1, @"full width");
  XCTAssertEqualWithAccuracy(bottom - top + 1, h / 2.0, 1, @"half the height");
  XCTAssertEqualWithAccuracy((top + bottom + 1) / 2.0, h / 2.0, 1, @"centred");
}

@end
