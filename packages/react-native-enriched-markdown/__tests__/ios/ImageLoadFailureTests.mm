#import "../../ios/attachments/ENRMImageAttachment.h"
#import "../../ios/renderer/RenderContext.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/RuntimeKeys.h"
#import "../../ios/views/EnrichedMarkdownInternalText.h"
#import <XCTest/XCTest.h>

// Issue #1123: an image that fails to load used to stay an empty box. file:// URLs that do
// not exist fail synchronously on the main thread, so no network or wait is involved.
static const CGFloat kInlineSize = 20;
static const CGFloat kBlockHeight = 100;

@interface EnrichedMarkdownInternalText (ImageLayoutObserver)
- (void)imageAttachmentDidResolveLayout;
@end

// The download's outcome, driven by hand so the text can be laid out before the failure.
@protocol ENRMLateFailure
@property (nonatomic, assign) BOOL loadFailed;
- (void)handleLoadFailure;
@end

@interface ENRMRecordingLayoutObserver : UIView <ENRMImageLayoutObserver>
@property (nonatomic, copy) void (^onResolve)(void);
@end

@implementation ENRMRecordingLayoutObserver
- (void)imageAttachmentDidResolveLayout
{
  self.onResolve();
}
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
- (CGFloat)chipWidthAtFontScale:(CGFloat)fontScale
{
  StyleConfig *config = [self config];
  [config setInlineImageSize:100];
  [config setFontScaleMultiplier:fontScale];
  ENRMImageAttachment *attachment =
      [NSClassFromString(@"ENRMImageAttachment") attachmentForURL:[self missingFile:@"scaled"]
                                                           source:nil
                                                          altText:@"ab"
                                                           config:config
                                                         isInline:YES];
  return [self boundsOf:attachment lineWidth:320].size.width;
}

- (void)testAltTextFollowsTheUsersTextSize
{
  XCTAssertGreaterThan([self chipWidthAtFontScale:2.0], [self chipWidthAtFontScale:1.0]);
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

  // The text reflows as it does around a settled image; its container's size belongs to the viewport.
  NSTextStorage *storage = view.textView.textStorage;
  [storage addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:48] range:NSMakeRange(0, storage.length)];
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

// The app links a text view to its container before it sets the text (applyRenderedText:,
// applyAttributedText:). The text view holds that host's measurement, made earlier by its own copy.
- (UITextView *)linkedTextViewIn:(ENRMRecordingLayoutObserver *)host
{
  UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
  (void)textView.layoutManager; // TextKit 1, as the app's text views
  objc_setAssociatedObject(textView.textContainer, kTextViewKey, textView, OBJC_ASSOCIATION_ASSIGN);
  [host addSubview:textView];
  return textView;
}

- (NSAttributedString *)textWith:(ENRMImageAttachment *)attachment
{
  NSMutableAttributedString *text = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:@" after"]];
  return text;
}

- (void)runMainLoopFor:(NSTimeInterval)seconds
{
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

// A failure that arrives after the host measured the text, but before the view laid it out
// (it mounts below the fold): the view lays out the chip, while the host keeps the height it
// measured with the square. The attachment tells the host when the view lays it out.
- (void)testFailureAfterMeasurementIsReportedWhenTheViewLaysItOut
{
  ENRMImageAttachment<ENRMLateFailure> *attachment =
      (id)[self attachmentForURL:[self missingFile:@"before-mount"] alt:@"a diagram" isInline:YES];
  attachment.loadFailed = NO; // the download is still running when the text is measured

  NSTextStorage *storage = [[NSTextStorage alloc] initWithAttributedString:[self textWith:attachment]];
  NSLayoutManager *measurement = [[NSLayoutManager alloc] init];
  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(320, CGFLOAT_MAX)];
  [measurement addTextContainer:container];
  [storage addLayoutManager:measurement];
  [measurement ensureLayoutForTextContainer:container];
  XCTAssertEqual([measurement attachmentSizeForGlyphAtIndex:0].width, kInlineSize);

  [attachment handleLoadFailure];

  ENRMRecordingLayoutObserver *host = [[ENRMRecordingLayoutObserver alloc] init];
  __block NSUInteger reports = 0;
  XCTestExpectation *resolved = [self expectationWithDescription:@"host re-measures"];
  host.onResolve = ^{
    if (++reports == 1)
      [resolved fulfill];
  };
  UITextView *textView = [self linkedTextViewIn:host];
  textView.attributedText = [self textWith:attachment];
  [textView.layoutManager ensureLayoutForTextContainer:textView.textContainer];
  XCTAssertGreaterThan([textView.layoutManager attachmentSizeForGlyphAtIndex:0].width, kInlineSize);
  [self waitForExpectations:@[ resolved ] timeout:1];

  // Drawing it afterwards has nothing left to report.
  (void)[attachment imageForBounds:CGRectMake(0, 0, kInlineSize, kInlineSize)
                     textContainer:textView.textContainer
                    characterIndex:0];
  [self runMainLoopFor:0.2];
  XCTAssertEqual(reports, 1);
  host.onResolve = ^{}; // a late report must not reach a later test's run loop
}

// A failure before anything was measured (a missing local file fails at once) leaves no size
// to correct: the host is not asked to measure the text again.
- (void)testFailureBeforeAnyMeasurementIsNotReported
{
  ENRMImageAttachment *attachment = [self attachmentForURL:[self missingFile:@"unmeasured"]
                                                       alt:@"a diagram"
                                                  isInline:YES];

  ENRMRecordingLayoutObserver *host = [[ENRMRecordingLayoutObserver alloc] init];
  __block NSUInteger reports = 0;
  host.onResolve = ^{ reports++; };
  UITextView *textView = [self linkedTextViewIn:host];
  textView.attributedText = [self textWith:attachment];
  [textView.layoutManager ensureLayoutForTextContainer:textView.textContainer];
  XCTAssertGreaterThan([textView.layoutManager attachmentSizeForGlyphAtIndex:0].width, kInlineSize);
  (void)[attachment imageForBounds:CGRectMake(0, 0, kInlineSize, kInlineSize)
                     textContainer:textView.textContainer
                    characterIndex:0];
  [self runMainLoopFor:0.2];
  XCTAssertEqual(reports, 0);
  host.onResolve = ^{};
}

@end
