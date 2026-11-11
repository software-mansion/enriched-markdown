#import "../../ios/attachments/ThematicBreakAttachment.h"
#import <XCTest/XCTest.h>

// The text draws a rule again on every frame of a streaming animation: it keeps its image.
@interface ThematicBreakAttachmentTests : XCTestCase
@end

@implementation ThematicBreakAttachmentTests

- (ThematicBreakAttachment *)rule
{
  ThematicBreakAttachment *attachment = [[ThematicBreakAttachment alloc] init];
  attachment.lineColor = UIColor.grayColor;
  attachment.lineHeight = 1;
  attachment.marginTop = 8;
  attachment.marginBottom = 8;
  return attachment;
}

- (UIImage *)imageOf:(ThematicBreakAttachment *)attachment width:(CGFloat)width
{
  return [attachment imageForBounds:CGRectMake(0, 0, width, 17) textContainer:nil characterIndex:0];
}

- (void)testTheImageIsDrawnOncePerLook
{
  ThematicBreakAttachment *attachment = [self rule];
  UIImage *image = [self imageOf:attachment width:300];
  XCTAssertEqual([self imageOf:attachment width:300], image);

  UIImage *wider = [self imageOf:attachment width:320];
  XCTAssertNotEqual(wider, image);
  XCTAssertEqual(wider.size.width, 320);

  attachment.lineColor = UIColor.redColor;
  UIImage *red = [self imageOf:attachment width:320];
  XCTAssertNotEqual(red, wider);

  attachment.lineHeight = 2;
  XCTAssertNotEqual([self imageOf:attachment width:320], red);
}

- (void)testADynamicColorIsDrawnAgainWhenTheAppearanceChanges
{
  ThematicBreakAttachment *attachment = [self rule];
  attachment.lineColor = UIColor.labelColor;
  __block UIImage *light = nil;
  __block UIImage *dark = nil;
  [[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight]
      performAsCurrentTraitCollection:^{ light = [self imageOf:attachment width:300]; }];
  [[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark]
      performAsCurrentTraitCollection:^{ dark = [self imageOf:attachment width:300]; }];
  XCTAssertNotEqual(light, dark);
}

@end
