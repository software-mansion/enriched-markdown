#pragma once
#import "ParagraphStyleUtils.h"
#import <Foundation/Foundation.h>

@class ENRMRenderResult;
@class ENRMRenderedSegment;
@class MarkdownASTNode;
@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * A view's previous text render, reused while the document streams (Android's TextRenderCache).
 * Confined to the queue the view renders on; clear it whenever views are recreated.
 *
 * An unchanged text segment comes back under the same signature and revision, without its text, so
 * the reconciler keeps its view. The last one re-renders from its first changed node as a patch
 * (ENRMRenderASTNodesResuming), starting no later than the old last node, whose trailing spacing
 * was trimmed, and the new last node, which still ends in the spacing before nodes that are gone
 * (a completed link reference definition renders nothing).
 */
@interface ENRMTextRenderCache : NSObject

// Starts a render; `key` holds everything besides the nodes that shapes the text.
- (void)beginRenderWithKey:(NSArray *)key;
- (void)endRender;
- (void)clear;

// The text segment for `nodes`, whose signature `signature` makes from the nodes' own. `isLast`
// marks the segment a stream grows. `render` renders the nodes in full; `resume` renders the
// nodes from the first changed one after `previous`, or returns nil to render them in full.
- (ENRMRenderedSegment *)segmentForNodes:(NSArray<MarkdownASTNode *> *)nodes
                                  isLast:(BOOL)isLast
                               signature:(uint64_t (^)(uint64_t nodesSignature))signature
                                  render:(ENRMRenderResult * (^)(void))render
                                  resume:(ENRMRenderResult *_Nullable (^)(NSUInteger from,
                                                                          ENRMRenderResult *previous))resume;

@end

#ifdef __cplusplus
extern "C" {
#endif

// The key a host renders with: everything besides the nodes that shapes its text. `epoch` changes
// when the host drops what the cache holds (a recycled view, a render the cache didn't see).
NSArray *ENRMTextRenderKey(StyleConfig *config, size_t styleFingerprint, BOOL allowFontScaling,
                           CGFloat maxFontSizeMultiplier, NSLineBreakStrategy lineBreakStrategy,
                           ENRMWritingDirectionMode writingDirectionMode, NSWritingDirection layoutDirection,
                           NSUInteger epoch);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
