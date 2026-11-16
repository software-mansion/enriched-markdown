#pragma once

#import <Foundation/Foundation.h>

@class ENRMRenderedSegment;
@class MarkdownASTNode;
@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

// blockquoteContent = YES when splitting a blockquote's own children (called by
// ENRMBlockquoteContainerView): text segments are then rendered with blockquote styling
// (tight paragraphs, quote font/color/line height) instead of paragraph styling.
// Task items are numbered from startingTaskIndex, so indices stay document-wide (the toggle
// rewrites the Nth task of the markdown): 0 for the document, its first task's index for a quote.
NSArray<ENRMRenderedSegment *> *ENRMRenderSegmentsFromAST(MarkdownASTNode *ast, StyleConfig *config,
                                                          BOOL allowTrailingMargin, BOOL allowFontScaling,
                                                          CGFloat maxFontSizeMultiplier,
                                                          NSLineBreakStrategy lineBreakStrategy, BOOL blockquoteContent,
                                                          NSInteger startingTaskIndex);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
