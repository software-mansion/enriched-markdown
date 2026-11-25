#import "ENRMSegmentHeightMeasurer.h"
#import "ENRMBlockSlotMeasurer.h"
#import "ENRMBlockSlotSegmentView.h"
#import "ENRMBlockquoteContainerView.h"
#import "ENRMCodeBlockContainerView.h"
#import "ENRMCodeBlockWrapState.h"
#import "ENRMFeatureFlags.h"
#import "ENRMListContainerView.h"
#import "ENRMTextRenderer.h"
#import "ENRMViewFreeMeasurement.h"
#import "TableContainerView.h"
#if ENRICHED_MARKDOWN_MATH
#import "ENRMMathContainerView.h"
#endif
#if ENRICHED_MARKDOWN_VIDEO
#import "ENRMVideoContainerView.h"
#endif

CGFloat ENRMMeasureSegmentsHeightViewFree(NSArray<ENRMRenderedSegment *> *segments, StyleConfig *config,
                                          CGFloat contentWidth, BOOL allowTrailingMargin, CGFloat pointScaleFactor,
                                          ENRMWritingDirectionMode writingDirectionMode,
                                          NSWritingDirection resolvedLayoutDirection, NSWritingDirection quoteDirection,
                                          BOOL allowFontScaling, NSLineBreakStrategy lineBreakStrategy,
                                          ENRMCodeBlockWrapCursor *wrapCursor, ENRMBlockSlotMeasurer *slotMeasurer,
                                          CGPoint origin)
{
  return ENRMMeasureSegmentsHeightViewFreeWithContext(segments, config, contentWidth, allowTrailingMargin,
                                                      pointScaleFactor, writingDirectionMode, resolvedLayoutDirection,
                                                      quoteDirection, allowFontScaling, lineBreakStrategy, wrapCursor,
                                                      slotMeasurer, origin, YES);
}

CGFloat ENRMMeasureSegmentsHeightViewFreeWithContext(
    NSArray<ENRMRenderedSegment *> *segments, StyleConfig *config, CGFloat contentWidth, BOOL allowTrailingMargin,
    CGFloat pointScaleFactor, ENRMWritingDirectionMode writingDirectionMode, NSWritingDirection resolvedLayoutDirection,
    NSWritingDirection quoteDirection, BOOL allowFontScaling, NSLineBreakStrategy lineBreakStrategy,
    ENRMCodeBlockWrapCursor *wrapCursor, ENRMBlockSlotMeasurer *slotMeasurer, CGPoint origin,
    BOOL childrenInsideBlockquote)
{
  if (segments.count == 0) {
    return 0;
  }

  CGFloat totalHeight = 0;
  const NSUInteger lastIndex = segments.count - 1;

  for (NSUInteger i = 0; i < segments.count; i++) {
    ENRMRenderedSegment *segment = segments[i];
    const BOOL isLast = (i == lastIndex);
    const BOOL shouldAddBottomMargin = (!isLast || allowTrailingMargin);

    if (segment.kind == ENRMSegmentKindText && segment.textResult) {
      // GFM segments are never line-clamped (numberOfLines is a no-op for GFM).
      CGSize textSize = ENRMMeasureAttributedTextViewFree(
          segment.textResult.attributedText, contentWidth, config, shouldAddBottomMargin,
          segment.textResult.lastElementMarginBottom, pointScaleFactor, 0, NSLineBreakByWordWrapping, YES);
      totalHeight += textSize.height;
    } else if (segment.kind == ENRMSegmentKindTable && segment.tableSegment) {
      totalHeight += config.tableMarginTop;
      totalHeight += [TableContainerView measureHeightForTableNode:segment.tableSegment.tableNode
                                                            config:config
                                                  allowFontScaling:allowFontScaling
                                             maxFontSizeMultiplier:config.maxFontSizeMultiplier
                                              writingDirectionMode:writingDirectionMode
                                           resolvedLayoutDirection:resolvedLayoutDirection];
      if (shouldAddBottomMargin) {
        totalHeight += config.tableMarginBottom;
      }
    } else if (segment.kind == ENRMSegmentKindCodeBlock && segment.codeBlockSegment) {
      totalHeight += config.codeBlockMarginTop;
      MarkdownASTNode *codeBlockNode = segment.codeBlockSegment.codeBlockNode;
      totalHeight += [wrapCursor nextIsWrapped]
                         ? [ENRMCodeBlockContainerView measureWrappedHeightForCodeBlockNode:codeBlockNode
                                                                                     config:config
                                                                                   maxWidth:contentWidth]
                         : [ENRMCodeBlockContainerView measureHeightForCodeBlockNode:codeBlockNode config:config];
      if (shouldAddBottomMargin) {
        totalHeight += config.codeBlockMarginBottom;
      }
    } else if (segment.kind == ENRMSegmentKindList && segment.listSegment) {
      segment.listSegment.outerDirection = quoteDirection;
      BOOL root = segment.listSegment.depth == 0;
      if (root)
        totalHeight += config.listStyleMarginTop;
      totalHeight += [ENRMListContainerView measureListSegment:segment.listSegment
                                                        config:config
                                                         width:contentWidth
                                              pointScaleFactor:pointScaleFactor
                                              allowFontScaling:allowFontScaling
                                             lineBreakStrategy:lineBreakStrategy
                                                    wrapCursor:wrapCursor
                                                  slotMeasurer:slotMeasurer
                                                        origin:CGPointMake(origin.x, origin.y + totalHeight)];
      if (root && shouldAddBottomMargin)
        totalHeight += config.listStyleMarginBottom;
    } else if (segment.kind == ENRMSegmentKindBlockquote && segment.blockquoteSegment) {
      if (!childrenInsideBlockquote)
        totalHeight += config.blockquoteMarginTop;
      totalHeight +=
          [ENRMBlockquoteContainerView measureHeightForBlockquoteNode:segment.blockquoteSegment.blockquoteNode
                                                               config:config
                                                             maxWidth:contentWidth
                                                     pointScaleFactor:pointScaleFactor
                                                     allowFontScaling:allowFontScaling
                                                    lineBreakStrategy:lineBreakStrategy
                                                 writingDirectionMode:writingDirectionMode
                                              resolvedLayoutDirection:resolvedLayoutDirection
                                                       outerDirection:quoteDirection
                                                           wrapCursor:wrapCursor
                                                         slotMeasurer:slotMeasurer
                                                               origin:CGPointMake(origin.x, origin.y + totalHeight)
                                                          listContext:segment.blockquoteSegment.listContext];
      if (!childrenInsideBlockquote && shouldAddBottomMargin)
        totalHeight += config.blockquoteMarginBottom;
    } else if (segment.kind == ENRMSegmentKindBlockSlot && segment.blockSlotSegment) {
      ENRMBlockSlotSegment *slot = segment.blockSlotSegment;
      totalHeight += ENRMBlockSlotMarginTop(slot.kind, config);
      totalHeight += [slotMeasurer heightForSlot:slot.slotId
                                           width:contentWidth
                                          origin:CGPointMake(origin.x, origin.y + totalHeight)];
      if (shouldAddBottomMargin) {
        totalHeight += ENRMBlockSlotMarginBottom(slot.kind, config);
      }
    }
#if ENRICHED_MARKDOWN_MATH
    else if (segment.kind == ENRMSegmentKindMath && segment.mathSegment) {
      totalHeight += config.mathMarginTop;
      totalHeight += [ENRMMathContainerView measureHeightForLatex:segment.mathSegment.latex
                                                           config:config
                                                         maxWidth:contentWidth];
      if (shouldAddBottomMargin) {
        totalHeight += config.mathMarginBottom;
      }
    }
#endif
#if ENRICHED_MARKDOWN_VIDEO
    else if (segment.kind == ENRMSegmentKindVideo && segment.videoSegment) {
      totalHeight += config.videoMarginTop;
      totalHeight += [ENRMVideoContainerView measureHeightForVideoNode:segment.videoSegment.videoNode
                                                                config:config
                                                              maxWidth:contentWidth];
      if (shouldAddBottomMargin) {
        totalHeight += config.videoMarginBottom;
      }
    }
#endif
  }

  return totalHeight;
}
