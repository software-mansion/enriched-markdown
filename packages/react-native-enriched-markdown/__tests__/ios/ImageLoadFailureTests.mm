#import "../../ios/attachments/ENRMImageAttachment.h"
#import "../../ios/renderer/RenderContext.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/views/EnrichedMarkdownInternalText.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

// Issue #1123: an image that fails to load used to stay an empty box. file:// URLs that do
// not exist fail synchronously on the main thread, so no network or wait is involved.
static const CGFloat kInlineSize = 20;
static const CGFloat kBlockHeight = 100;

@interface EnrichedMarkdownInternalText (ImageLayoutObserver)
- (void)imageAttachmentDidResolveLayout;
@end

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

// Issue #1123: a list item indents its paragraph inside a full-width text container, and the
// box took the container's width, so it ran past the right edge by the indent.
- (CGFloat)laidOutWidthOfBlockImageWithHeadIndent:(CGFloat)headIndent tailIndent:(CGFloat)tailIndent
{
  ENRMImageAttachment *attachment = [self attachmentForURL:[self missingFile:@"indent"] alt:@"a diagram" isInline:NO];
  NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
  style.firstLineHeadIndent = headIndent;
  style.headIndent = headIndent;
  style.tailIndent = tailIndent;

  NSMutableAttributedString *text = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
  [text addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, text.length)];

  NSTextStorage *storage = [[NSTextStorage alloc] initWithAttributedString:text];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(300, CGFLOAT_MAX)];
  container.lineFragmentPadding = 0;
  [layoutManager addTextContainer:container];
  [storage addLayoutManager:layoutManager];
  [layoutManager ensureLayoutForTextContainer:container];
  return [layoutManager attachmentSizeForGlyphAtIndex:0].width;
}

- (void)testBlockImageWithoutIndentFillsTheLine
{
  XCTAssertEqual([self laidOutWidthOfBlockImageWithHeadIndent:0 tailIndent:0], 300);
}

- (void)testBlockImageFitsInsideAListItemsIndent
{
  XCTAssertEqual([self laidOutWidthOfBlockImageWithHeadIndent:30 tailIndent:0], 270);
}

- (void)testBlockImageFitsInsideATailIndent
{
  XCTAssertEqual([self laidOutWidthOfBlockImageWithHeadIndent:30 tailIndent:-10], 260);
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

// The alt text has to follow the paragraph text when the user picks a larger text size. Only
// the chip's width shows the font it was given, so the chip is tall enough not to cap it.
- (CGFloat)chipWidthAtContentSize:(UIContentSizeCategory)category
{
  Method method = class_getInstanceMethod([UIApplication class], @selector(preferredContentSizeCategory));
  IMP original = method_getImplementation(method);
  IMP fake = imp_implementationWithBlock(^UIContentSizeCategory(id application) { return category; });
  method_setImplementation(method, fake);

  StyleConfig *config = [self config];
  [config setInlineImageSize:100];
  ENRMImageAttachment *attachment =
      [NSClassFromString(@"ENRMImageAttachment") attachmentForURL:[self missingFile:@"scaled"]
                                                           source:nil
                                                          altText:@"ab"
                                                           config:config
                                                         isInline:YES];
  CGFloat width = [self boundsOf:attachment lineWidth:320].size.width;

  method_setImplementation(method, original);
  imp_removeBlock(fake);
  return width;
}

- (void)testAltTextFollowsTheUsersTextSize
{
  XCTAssertGreaterThan([self chipWidthAtContentSize:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge],
                       [self chipWidthAtContentSize:UIContentSizeCategoryLarge]);
}

// A failure that arrives after VoiceOver has read the text widens the image and reflows the
// text, so the elements built before it point at the old lines.
- (CGFloat)accessibilityHeightAfterReflowNotifying:(BOOL)notify
{
  EnrichedMarkdownInternalText *view = [[EnrichedMarkdownInternalText alloc] initWithConfig:[self config]];
  view.frame = CGRectMake(0, 0, 320, 600);
  NSString *words = @"one two three four five six seven eight nine ten eleven twelve";
  NSDictionary *attributes = @{NSFontAttributeName : [UIFont systemFontOfSize:16]};
  [view applyAttributedText:[[NSMutableAttributedString alloc] initWithString:words attributes:attributes]
                    context:[RenderContext new]];
  view.textView.textContainer.size = CGSizeMake(320, CGFLOAT_MAX);
  CGFloat before = CGRectGetHeight([view.accessibilityElements.firstObject accessibilityFrameInContainerSpace]);

  view.textView.textContainer.size = CGSizeMake(80, CGFLOAT_MAX);
  if (notify) {
    [view imageAttachmentDidResolveLayout];
  }
  CGFloat after = CGRectGetHeight([view.accessibilityElements.firstObject accessibilityFrameInContainerSpace]);
  return after - before;
}

- (void)testVoiceOverFramesFollowALateImageLayout
{
  XCTAssertEqual([self accessibilityHeightAfterReflowNotifying:NO], 0, @"elements are cached between layouts");
  XCTAssertGreaterThan([self accessibilityHeightAfterReflowNotifying:YES], 0);
}

@end
