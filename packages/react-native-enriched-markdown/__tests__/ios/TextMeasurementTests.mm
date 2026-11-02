#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import "../../ios/utils/ENRMTextViewSetup.h"
#import <XCTest/XCTest.h>

typedef struct {
  CGSize size;
  NSUInteger lineCount;
} ENRMMeasuredLayout;

static StyleConfig *ENRMMeasurementConfig(void)
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setCodeBlockPadding:12];
  [config setBlockquotePadding:12];
  return config;
}

@interface ENRMTextMeasurementTests : XCTestCase
@end

@implementation ENRMTextMeasurementTests

- (ENRMMeasuredLayout)layoutMarkdown:(NSString *)markdown maxWidth:(CGFloat)maxWidth numberOfLines:(NSInteger)lines
{
  StyleConfig *config = ENRMMeasurementConfig();
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init] parseMarkdown:markdown
                                                                    flags:[ENRMMd4cFlags defaultFlags]
                                                                    isGFM:YES];
  ENRMRenderResult *result = ENRMRenderASTNodes(ast.children, config, NO, YES, 0, NSLineBreakStrategyStandard);

  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)];
  container.lineFragmentPadding = 0;
  if (lines > 0) {
    container.maximumNumberOfLines = lines;
    container.lineBreakMode = NSLineBreakByTruncatingTail;
  }
  NSLayoutManager *manager = [[NSLayoutManager alloc] init];
  manager.allowsNonContiguousLayout = NO;
  [manager addTextContainer:container];
  NSTextStorage *storage = [[NSTextStorage alloc] initWithAttributedString:result.attributedText];
  [storage addLayoutManager:manager];
  [manager ensureLayoutForTextContainer:container];

  ENRMTextLayoutResult layout = {[manager usedRectForTextContainer:container], manager.extraLineFragmentRect};
  ENRMMeasuredLayout out;
  out.size =
      ENRMFinalizeMeasuredTextSize(layout, manager, maxWidth, config, NO, result.lastElementMarginBottom, YES, 3);
  __block NSUInteger lineCount = 0;
  [manager enumerateLineFragmentsForGlyphRange:NSMakeRange(0, manager.numberOfGlyphs)
                                    usingBlock:^(CGRect, CGRect, NSTextContainer *, NSRange, BOOL *) { lineCount++; }];
  out.lineCount = lineCount;
  return out;
}

// Yoga hands the measured width back as the frame, so relaying at it must not re-wrap.
- (void)assertTight:(NSString *)markdown
{
  ENRMMeasuredLayout measured = [self layoutMarkdown:markdown maxWidth:300 numberOfLines:0];
  XCTAssertLessThan(measured.size.width, 300, @"%@", markdown);
  ENRMMeasuredLayout relaid = [self layoutMarkdown:markdown maxWidth:measured.size.width numberOfLines:0];
  XCTAssertEqual(relaid.lineCount, measured.lineCount, @"%@ re-wrapped at %g", markdown, measured.size.width);
  XCTAssertEqualWithAccuracy(relaid.size.height, measured.size.height, 0.5, @"%@ at %g", markdown, measured.size.width);
}

- (void)assertPinned:(NSString *)markdown
{
  XCTAssertEqual([self layoutMarkdown:markdown maxWidth:80 numberOfLines:0].size.width, 80, @"%@", markdown);
}

- (void)testSingleLineKeepsItsIntrinsicWidth
{
  [self assertTight:@"short"];
  [self assertTight:@"short\n"];
}

- (void)testExplicitBreaksKeepTheirIntrinsicWidth
{
  [self assertTight:@"one\n\ntwo"];
  [self assertTight:@"one  \ntwo"];
  [self assertTight:@"one\u2028two"];
  [self assertTight:@"one\u2029two"];
  [self assertTight:@"\U0001F600\n\nshort"];
  [self assertTight:@"# Title here\n\nshort"];
}

- (void)testIndentedBlocksKeepAWidthThatDoesNotRewrap
{
  [self assertTight:@"- alpha beta\n- gamma"];
  [self assertTight:@"1. alpha beta\n2. gamma"];
  [self assertTight:@"- alpha beta\n- gamma\n  - nested item"];
  [self assertTight:@"- [ ] task item\n- [x] done item"];
  [self assertTight:@"```\nsome code here\nmore\n```"];
  [self assertTight:@"> quoted words here\n>\n> more"];
}

- (void)testSoftWrappingKeepsTheAvailableWidth
{
  [self assertPinned:@"one two three four five six seven eight nine ten"];
  [self assertPinned:@"short\n\none two three four five six seven eight nine ten"];
  [self assertPinned:@"- a\n- one two three four five six seven eight nine ten"];
  [self assertPinned:@"```\none two three four five six seven eight nine ten\n```"];
}

- (void)testLineClampStillMeasuresTight
{
  XCTAssertLessThan([self layoutMarkdown:@"one\n\ntwo three four" maxWidth:300 numberOfLines:1].size.width, 300);
}

@end
