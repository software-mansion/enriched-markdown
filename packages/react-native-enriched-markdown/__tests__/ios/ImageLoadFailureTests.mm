#import "../../ios/attachments/ENRMImageAttachment.h"
#import "../../ios/styles/StyleConfig.h"
#import <XCTest/XCTest.h>

// Issue #1123: an image that fails to load used to stay an empty box. file:// URLs that do
// not exist fail synchronously on the main thread, so no network or wait is involved.
static const CGFloat kInlineSize = 20;
static const CGFloat kBlockHeight = 100;

@interface ENRMImageLoadFailureTests : XCTestCase
@end

@implementation ENRMImageLoadFailureTests

- (StyleConfig *)config
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setInlineImageSize:kInlineSize];
  [config setImageHeight:kBlockHeight];
  [config setParagraphFontSize:16];
  [config setParagraphColor:[RCTUIColor blackColor]];
  return config;
}

- (NSString *)missingFile:(NSString *)name
{
  return [NSString stringWithFormat:@"file:///nonexistent/%@-%@.png", name, NSUUID.UUID.UUIDString];
}

- (ENRMImageAttachment *)attachmentForURL:(NSString *)url alt:(NSString *)alt isInline:(BOOL)isInline
{
  return [NSClassFromString(@"ENRMImageAttachment") attachmentForURL:url
                                                              source:nil
                                                             altText:alt
                                                              config:[self config]
                                                            isInline:isInline];
}

- (CGRect)boundsOf:(ENRMImageAttachment *)attachment lineWidth:(CGFloat)lineWidth
{
  return [attachment attachmentBoundsForTextContainer:nil
                                 proposedLineFragment:CGRectMake(0, 0, lineWidth, 24)
                                        glyphPosition:CGPointZero
                                       characterIndex:0];
}

- (void)testFailedInlineImageGrowsToFitItsAltText
{
  ENRMImageAttachment *attachment = [self attachmentForURL:[self missingFile:@"grows"] alt:@"a diagram" isInline:YES];
  XCTAssertGreaterThan([self boundsOf:attachment lineWidth:320].size.width, kInlineSize);
  XCTAssertEqual([self boundsOf:attachment lineWidth:320].size.height, kInlineSize);
}

- (void)testFailedInlineImageWithoutAltTextStaysSquare
{
  ENRMImageAttachment *attachment = [self attachmentForURL:[self missingFile:@"no-alt"] alt:@"" isInline:YES];
  XCTAssertEqual([self boundsOf:attachment lineWidth:320].size.width, kInlineSize);
}

- (void)testFailedInlineChipIsCappedByTheLine
{
  NSString *alt = [@"" stringByPaddingToLength:400 withString:@"long " startingAtIndex:0];
  ENRMImageAttachment *wide = [self attachmentForURL:[self missingFile:@"cap"] alt:alt isInline:YES];
  XCTAssertEqual([self boundsOf:wide lineWidth:320].size.width, 200);
  XCTAssertEqual([self boundsOf:wide lineWidth:120].size.width, 120);
}

- (void)testAttachmentBuiltAfterTheFailureStartsAsAChip
{
  NSString *url = [self missingFile:@"later"];
  (void)[self attachmentForURL:url alt:@"a diagram" isInline:YES];
  ENRMImageAttachment *fresh = [self attachmentForURL:url alt:@"a diagram" isInline:YES];
  XCTAssertGreaterThan([self boundsOf:fresh lineWidth:320].size.width, kInlineSize);
}

- (void)testFailedBlockImageKeepsItsBoxAndDrawsAPlaceholder
{
  ENRMImageAttachment *attachment = [self attachmentForURL:[self missingFile:@"block"] alt:@"a diagram" isInline:NO];
  CGRect bounds = [self boundsOf:attachment lineWidth:320];
  XCTAssertEqual(bounds.size.width, 320);
  XCTAssertEqual(bounds.size.height, kBlockHeight);

  RCTUIImage *image = [attachment imageForBounds:bounds textContainer:nil characterIndex:0];
  XCTAssertEqual(image.size.width, 320);
  XCTAssertEqual(image.size.height, kBlockHeight);
}

@end
