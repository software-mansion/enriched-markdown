#pragma once

#import "ENRMCodeBlockContainerView.h"
#import "ENRMUIKit.h"

#ifdef __cplusplus
#include <string>
#endif

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
// Code block wrap state is keyed by block position, so it only stays meaningful
// while the document grows in place. Streaming may rewrite its unfinished last
// line (an HTML tag closing, a link relabeled); anything earlier changing - a
// recycled cell, an edited message, a block inserted above - starts unwrapped.
// Compares in place: this runs on every streamed chunk while a block is wrapped.
inline bool ENRMKeepsCodeBlockWrapState(const std::string &previous, const std::string &next)
{
  const auto cut = previous.rfind('\n');
  return cut == std::string::npos || next.compare(0, cut, previous, 0, cut) == 0;
}
#endif

// Appends the code block views among `segmentViews` in document order,
// descending into nested blockquotes: the order ENRMCodeBlockWrapState indexes
// them in.
void ENRMCollectCodeBlockViews(NSArray<RCTUIView *> *segmentViews,
                               NSMutableArray<ENRMCodeBlockContainerView *> *codeBlockViews);

/**
 * Hands out the wrapped flag of each code block in the order a view-free
 * measure pass reaches them: pre-order, descending into blockquotes, the same
 * order ENRMCodeBlockWrapState indexes the views in.
 */
@interface ENRMCodeBlockWrapCursor : NSObject

- (instancetype)initWithWrapped:(nullable NSSet<NSNumber *> *)wrapped;

- (BOOL)nextIsWrapped;

@end

/**
 * Which code blocks of one EnrichedMarkdown the user wrapped with the header
 * toggle, and the only writer of that choice; mirrors Android's
 * CodeBlockWrapState.
 *
 * Blocks are identified by document-order index, counted pre-order across
 * nesting (a block inside a blockquote takes the next index, like a top-level
 * one). The set lives here rather than on the views, which are rebuilt on style,
 * font-scale and pill-content changes, and the shadow node's view-free measure
 * pass reads it through EnrichedMarkdown.wrappedCodeBlockIndices.
 */
@interface ENRMCodeBlockWrapState : NSObject

// `codeBlockViews` returns the host's current code block views (see
// ENRMCollectCodeBlockViews); `onHeightChanged` re-lays out and re-measures it
// after a toggle.
- (instancetype)initWithCodeBlockViews:(NSArray<ENRMCodeBlockContainerView *> * (^)(void))codeBlockViews
                       onHeightChanged:(void (^)(void))onHeightChanged;

@property (nonatomic, readonly) BOOL enabled;

// Written on main, read by the shadow-node measure pass on any thread.
@property (atomic, copy, readonly) NSSet<NSNumber *> *indices;

// Returns whether the wrapped set was cleared, so the height must be recomputed.
- (BOOL)updateEnabled:(BOOL)enabled;

#ifdef __cplusplus
// Applies the reset rule to a new markdown prop; `rendered` is the document on
// screen, which includes local task toggles. The prop is compared with the
// previous prop, so an app that ignores a checkbox tap and keeps streaming its
// own copy keeps the wrapped blocks; a prop equal to what's rendered is the app
// echoing a task toggle back and keeps them too. Returns whether the wrapped set
// was cleared.
- (BOOL)markdownPropDidChangeFrom:(const std::string &)previous
                               to:(const std::string &)next
                         rendered:(nullable NSString *)rendered;
#endif

// Pushes the wrapped set and the toggle onto the current code block views.
- (void)sync;

// Back to the initial state (toggle off, nothing wrapped) for a recycled view.
- (void)reset;

@end

NS_ASSUME_NONNULL_END
