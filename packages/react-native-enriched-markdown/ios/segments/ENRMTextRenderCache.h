#pragma once
#import "ParagraphStyleUtils.h"
#import <Foundation/Foundation.h>

@class ENRMRenderResult;
@class ENRMRenderedSegment;
@class MarkdownASTNode;
@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * What a view's previous render produced for its text segments, so the next one reuses it while
 * the document streams. Confined to the queue the view renders on. Android's TextRenderCache.
 *
 * - A text segment whose signature is unchanged comes back under the same signature and revision,
 *   without its text: the reconciler keeps its view as it is.
 * - The last text segment, the one a stream grows, also keeps its node signatures. When the new
 *   segment starts with the same nodes, only the nodes from the first changed one on render
 *   (ENRMRenderASTNodesResuming), and the view patches its text from there. Rendering starts at
 *   the old last node at the latest, whose trailing spacing was trimmed, and at the new last node
 *   at the latest, which still ends in the spacing before the nodes that are gone (a link
 *   reference definition that completes renders nothing).
 *
 * Clear it whenever views are recreated.
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
