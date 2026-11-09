#pragma once

#import "ParagraphStyleUtils.h"
#import <Foundation/Foundation.h>

@class ENRMRenderResult;
@class ENRMRenderedSegment;
@class ENRMTextRenderCache;
@class MarkdownASTNode;
@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

// blockquoteContent = YES when splitting a blockquote's own children (called by
// ENRMBlockquoteContainerView): text segments are then rendered with blockquote styling
// (tight paragraphs, quote font/color/line height) instead of paragraph styling.
NSArray<ENRMRenderedSegment *> *
ENRMRenderSegmentsFromAST(MarkdownASTNode *ast, StyleConfig *config, BOOL allowTrailingMargin, BOOL allowFontScaling,
                          CGFloat maxFontSizeMultiplier, NSLineBreakStrategy lineBreakStrategy, BOOL blockquoteContent);

// The host's segments, reusing what `cache` kept from the previous render (ENRMTextRenderCache).
// Unlike ENRMRenderSegmentsFromAST, the text segments come with their writing direction applied.
NSArray<ENRMRenderedSegment *> *
ENRMRenderSegmentsFromASTCached(MarkdownASTNode *ast, StyleConfig *config, BOOL allowTrailingMargin,
                                BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                NSLineBreakStrategy lineBreakStrategy, ENRMWritingDirectionMode writingDirectionMode,
                                NSWritingDirection layoutDirection, ENRMTextRenderCache *cache);

// One text of all of `nodes`, the way ENRMRenderSegmentsFromASTCached renders its last text
// segment: for a view that shows the whole document as one text.
ENRMRenderResult *ENRMRenderTextCached(NSArray<MarkdownASTNode *> *nodes, StyleConfig *config, BOOL allowTrailingMargin,
                                       BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                       NSLineBreakStrategy lineBreakStrategy,
                                       ENRMWritingDirectionMode writingDirectionMode,
                                       NSWritingDirection layoutDirection, ENRMTextRenderCache *cache);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
