#import "ENRMTextRenderer.h"
#import "AccessibilityInfo.h"
#import "AttributedRenderer.h"
#import "ENRMBlockquoteTextRenderer.h"
#import "ParagraphStyleUtils.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation ENRMRenderResult
@end

static ENRMRenderResult *ENRMRenderASTNodesCore(NSArray<MarkdownASTNode *> *nodes, StyleConfig *config,
                                                BOOL allowTrailingMargin, BOOL allowFontScaling,
                                                CGFloat maxFontSizeMultiplier, NSLineBreakStrategy lineBreakStrategy,
                                                ENRMBlockquoteTextRenderer *block)
{
  AttributedRenderer *renderer = [[AttributedRenderer alloc] initWithConfig:config];
  [renderer setAllowTrailingMargin:allowTrailingMargin];

  RenderContext *context = [RenderContext new];
  context.allowFontScaling = allowFontScaling;
  context.maxFontSizeMultiplier = maxFontSizeMultiplier;

  NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] init];
  NSMutableArray<NSNumber *> *blockStarts = [NSMutableArray arrayWithCapacity:nodes.count];
  NSMutableArray<NSNumber *> *blockTaskStarts = [NSMutableArray arrayWithCapacity:nodes.count];
  NSMutableArray<NSNumber *> *blockMathStarts = [NSMutableArray arrayWithCapacity:nodes.count];
  [renderer renderNodes:nodes
                   into:attributedText
                context:context
                  block:block
           onBlockStart:^(NSUInteger index) {
             [blockStarts addObject:@(attributedText.length)];
             [blockTaskStarts addObject:@(context.taskItemCount)];
             [blockMathStarts addObject:@(context.mathReporters.count)];
           }];

  [context applyLinkAttributesToString:attributedText];
  [context applyImageAttributesToString:attributedText];
  ENRMApplyLineBreakStrategyToParagraphStyles(attributedText, lineBreakStrategy);
  ENRMPinLineMetricsToStyledFonts(attributedText, NSMakeRange(0, attributedText.length));

  ENRMRenderResult *result = [[ENRMRenderResult alloc] init];
  result.attributedText = attributedText;
  result.textLength = attributedText.length;
  result.context = context;
  result.accessibilityInfo = [AccessibilityInfo infoFromContext:context];
  result.lastElementMarginBottom = [renderer getLastElementMarginBottom];
  result.blockStarts = blockStarts;
  result.blockTaskStarts = blockTaskStarts;
  result.blockMathStarts = blockMathStarts;
  return result;
}

// Renderers tell the first block of a text by its position (0, or 1 after a spacer), so the
// tail renders after the two characters before it, as it would in the whole text.
static const NSUInteger kResumeSeedLength = 2;

static NSArray *ENRMPrefixOf(NSArray *values, NSUInteger count)
{
  return [values subarrayWithRange:NSMakeRange(0, count)];
}

// The seed of a block starting at `start` of the whole text, read from `text`, which holds the
// whole text from `textStart` on.
static id ENRMSeedAt(NSAttributedString *text, NSUInteger textStart, NSUInteger start)
{
  if (start < textStart + kResumeSeedLength || start - textStart > text.length) {
    return [NSNull null];
  }
  return [text attributedSubstringFromRange:NSMakeRange(start - textStart - kResumeSeedLength, kResumeSeedLength)];
}

NSArray *ENRMBlockSeeds(NSAttributedString *text, NSArray<NSNumber *> *blockStarts)
{
  NSMutableArray *seeds = [NSMutableArray arrayWithCapacity:blockStarts.count];
  for (NSNumber *start in blockStarts) {
    [seeds addObject:ENRMSeedAt(text, 0, start.unsignedIntegerValue)];
  }
  return seeds;
}

ENRMRenderResult *ENRMRenderASTNodesResuming(NSArray<MarkdownASTNode *> *nodes, NSUInteger from,
                                             ENRMRenderResult *previous, StyleConfig *config, BOOL allowTrailingMargin,
                                             BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                             NSLineBreakStrategy lineBreakStrategy,
                                             ENRMWritingDirectionMode writingDirectionMode,
                                             NSWritingDirection layoutDirection)
{
  if (from == 0 || from >= nodes.count || from >= previous.blockStarts.count || from >= previous.blockSeeds.count) {
    return nil;
  }
  const NSUInteger start = previous.blockStarts[from].unsignedIntegerValue;
  NSAttributedString *seed = previous.blockSeeds[from];
  if (start > previous.textLength || ![seed isKindOfClass:[NSAttributedString class]]) {
    return nil;
  }

  AttributedRenderer *renderer = [[AttributedRenderer alloc] initWithConfig:config];
  [renderer setAllowTrailingMargin:allowTrailingMargin];
  RenderContext *context = [RenderContext new];
  context.allowFontScaling = allowFontScaling;
  context.maxFontSizeMultiplier = maxFontSizeMultiplier;
  context.taskItemCount = previous.blockTaskStarts[from].integerValue;

  // Positions in `tail` are `start - kResumeSeedLength` ahead of the whole text's.
  const NSInteger offset = (NSInteger)start - (NSInteger)kResumeSeedLength;
  const NSUInteger mathBefore = previous.blockMathStarts[from].unsignedIntegerValue;
  NSMutableAttributedString *tail = [seed mutableCopy];
  NSMutableArray<NSNumber *> *blockStarts = [ENRMPrefixOf(previous.blockStarts, from) mutableCopy];
  NSMutableArray<NSNumber *> *blockTaskStarts = [ENRMPrefixOf(previous.blockTaskStarts, from) mutableCopy];
  NSMutableArray<NSNumber *> *blockMathStarts = [ENRMPrefixOf(previous.blockMathStarts, from) mutableCopy];
  [renderer renderNodes:[nodes subarrayWithRange:NSMakeRange(from, nodes.count - from)]
                   into:tail
                context:context
                  block:nil
           onBlockStart:^(NSUInteger index) {
             [blockStarts addObject:@(tail.length + offset)];
             [blockTaskStarts addObject:@(context.taskItemCount)];
             [blockMathStarts addObject:@(mathBefore + context.mathReporters.count)];
           }];

  [context applyLinkAttributesToString:tail];
  [context applyImageAttributesToString:tail];
  ENRMApplyLineBreakStrategyToParagraphStyles(tail, lineBreakStrategy);
  // A renderer that changed the text before the tail would have changed it in the whole text too.
  if (tail.length < kResumeSeedLength || ![[tail attributedSubstringFromRange:NSMakeRange(0, kResumeSeedLength)]
                                             isEqualToAttributedString:seed]) {
    return nil;
  }
  [tail deleteCharactersInRange:NSMakeRange(0, kResumeSeedLength)];
  ENRMPinLineMetricsToStyledFonts(tail, NSMakeRange(0, tail.length));
  ENRMApplyWritingDirectionMode(tail, writingDirectionMode, layoutDirection);

  NSMutableArray *blockSeeds = [ENRMPrefixOf(previous.blockSeeds, from + 1) mutableCopy];
  for (NSUInteger i = from + 1; i < blockStarts.count; i++) {
    [blockSeeds addObject:ENRMSeedAt(tail, start, blockStarts[i].unsignedIntegerValue)];
  }
  NSMutableArray *mathReporters = [ENRMPrefixOf((NSArray *)previous.context.mathReporters, mathBefore) mutableCopy];
  [mathReporters addObjectsFromArray:context.mathReporters];
  context.mathReporters = mathReporters;

  ENRMRenderResult *result = [[ENRMRenderResult alloc] init];
  result.textLength = start + tail.length;
  result.context = context;
  result.accessibilityInfo = [previous.accessibilityInfo infoKeepingBefore:start
                                                                 appending:[AccessibilityInfo infoFromContext:context]
                                                                    offset:offset];
  result.lastElementMarginBottom = [renderer getLastElementMarginBottom];
  result.blockStarts = blockStarts;
  result.blockTaskStarts = blockTaskStarts;
  result.blockMathStarts = blockMathStarts;
  result.blockSeeds = blockSeeds;
  result.patchBaseRevision = previous.revision;
  result.patchStart = start;
  result.patchTail = tail;
  return result;
}

ENRMRenderResult *ENRMRenderASTNodes(NSArray<MarkdownASTNode *> *nodes, StyleConfig *config, BOOL allowTrailingMargin,
                                     BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                     NSLineBreakStrategy lineBreakStrategy)
{
  return ENRMRenderASTNodesCore(nodes, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier,
                                lineBreakStrategy, /*block*/ nil);
}

ENRMRenderResult *ENRMRenderBlockquoteContentNodes(NSArray<MarkdownASTNode *> *nodes, StyleConfig *config,
                                                   BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                                   NSLineBreakStrategy lineBreakStrategy)
{
  ENRMBlockquoteTextRenderer *block = [[ENRMBlockquoteTextRenderer alloc] initWithConfig:config];
  return ENRMRenderASTNodesCore(nodes, config, /*allowTrailingMargin*/ NO, allowFontScaling, maxFontSizeMultiplier,
                                lineBreakStrategy, block);
}
