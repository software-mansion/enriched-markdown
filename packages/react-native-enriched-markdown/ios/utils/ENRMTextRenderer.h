#pragma once
#import "ParagraphStyleUtils.h"
#import <Foundation/Foundation.h>

@class AccessibilityInfo;
@class MarkdownASTNode;
@class RenderContext;
@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

@interface ENRMRenderResult : NSObject
// Nil when the result is only a patch (patchStart, patchTail): a view that shows its base gets
// there by the patch, and any other one needs a full render.
@property (nonatomic, strong, nullable) NSMutableAttributedString *attributedText;
@property (nonatomic, assign) NSUInteger textLength;
@property (nonatomic, strong) RenderContext *context;
@property (nonatomic, strong) AccessibilityInfo *accessibilityInfo;
@property (nonatomic, assign) CGFloat lastElementMarginBottom;
// Where each top-level node starts in attributedText, and the task and math reporter counts
// before it: rendering can resume at any of them (ENRMRenderASTNodesResuming).
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *blockStarts;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *blockTaskStarts;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *blockMathStarts;
// For the text a stream grows (ENRMTextRenderCache): the two characters before each block start
// as they stand in the finished text, NSNull where there are none to resume after.
@property (nonatomic, copy, nullable) NSArray *blockSeeds;
// Identifies this text; a later result can be a patch to it (ENRMTextRenderCache).
@property (nonatomic, assign) uint64_t revision;
// When non-zero, this text is that revision's up to patchStart, then patchTail.
@property (nonatomic, assign) uint64_t patchBaseRevision;
@property (nonatomic, assign) NSUInteger patchStart;
@property (nonatomic, strong, nullable) NSAttributedString *patchTail;

// Whether the patch applies to the text a view shows: revision `revision`, `length` long. A patch
// starting past the end of that text was made from a render the view missed too.
- (BOOL)patchFitsRevision:(uint64_t)revision length:(NSUInteger)length;
@end

#ifdef __cplusplus
extern "C" {
#endif

ENRMRenderResult *ENRMRenderASTNodes(NSArray<MarkdownASTNode *> *nodes, StyleConfig *config, BOOL allowTrailingMargin,
                                     BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                     NSLineBreakStrategy lineBreakStrategy);

// Renders a blockquote's own text content: like ENRMRenderASTNodes but with a blockquote baseline
// (tight paragraphs, quote font/color) and the quote's line height applied over the result. Draws
// no box - the ENRMBlockquoteContainerView draws the border/background/padding. Mirrors Android's
// BlockquoteTextRenderer.
ENRMRenderResult *ENRMRenderBlockquoteContentNodes(NSArray<MarkdownASTNode *> *nodes, StyleConfig *config,
                                                   BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                                   NSLineBreakStrategy lineBreakStrategy);

// Renders nodes[from...] after `previous`, a render of the nodes whose first `from` are the
// same: its text up to node `from` stays, and the rest is rendered and given the writing
// direction. The result is only a patch to `previous` (patchStart, patchTail), with no
// attributedText. Nil when it could differ from rendering all the nodes, and the caller renders
// them in full.
ENRMRenderResult *_Nullable ENRMRenderASTNodesResuming(NSArray<MarkdownASTNode *> *nodes, NSUInteger from,
                                                       ENRMRenderResult *previous, StyleConfig *config,
                                                       BOOL allowTrailingMargin, BOOL allowFontScaling,
                                                       CGFloat maxFontSizeMultiplier,
                                                       NSLineBreakStrategy lineBreakStrategy,
                                                       ENRMWritingDirectionMode writingDirectionMode,
                                                       NSWritingDirection layoutDirection);

// blockSeeds for `text`, whose blocks start at `blockStarts`.
NSArray *ENRMBlockSeeds(NSAttributedString *text, NSArray<NSNumber *> *blockStarts);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
