#import "ENRMTextRenderer.h"
#import "AccessibilityInfo.h"
#import "AttributedRenderer.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RenderContext.h"
#import "StyleConfig.h"

@implementation ENRMRenderResult
@end

ENRMRenderResult *ENRMRenderASTNodes(NSArray<MarkdownASTNode *> *nodes, StyleConfig *config, BOOL allowTrailingMargin,
                                     BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                     NSLineBreakStrategy lineBreakStrategy)
{
  MarkdownASTNode *root = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeDocument];
  for (MarkdownASTNode *node in nodes) {
    [root addChild:node];
  }

  AttributedRenderer *renderer = [[AttributedRenderer alloc] initWithConfig:config];
  [renderer setAllowTrailingMargin:allowTrailingMargin];

  RenderContext *context = [RenderContext new];
  context.allowFontScaling = allowFontScaling;
  context.maxFontSizeMultiplier = maxFontSizeMultiplier;

  NSMutableAttributedString *attributedText = [renderer renderRoot:root context:context];
  [context applyLinkAttributesToString:attributedText];
  [context applyImageAttributesToString:attributedText];
  ENRMApplyLineBreakStrategyToParagraphStyles(attributedText, lineBreakStrategy);

  ENRMRenderResult *result = [[ENRMRenderResult alloc] init];
  result.attributedText = attributedText;
  result.context = context;
  result.accessibilityInfo = [AccessibilityInfo infoFromContext:context];
  result.lastElementMarginBottom = [renderer getLastElementMarginBottom];
  return result;
}
