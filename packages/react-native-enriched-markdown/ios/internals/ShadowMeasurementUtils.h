#pragma once

#import "ENRMPreparedRenderStore.h"
#include "MeasurementCache.h"
#import <Foundation/Foundation.h>
#import <React/RCTUtils.h>
#include <algorithm>
#include <cmath>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>
#include <react/utils/ManagedObjectWrapper.h>

namespace facebook::react {

// Threading contract (issue #550): measureContent may run on any thread while
// RN holds commit locks that main-thread committers (e.g. Reanimated) also
// acquire — with `preventShadowTreeCommitExhaustion`, the JS thread re-runs
// layout under `revisionMutexRecursive_` after 3 failed optimistic commits.
// Any dispatch_sync to main from this path can therefore deadlock: JS waits
// for main, main waits for the mutex JS holds (watchdog kill 0x8BADF00D).
// Nothing in the measurement path may wait on the main thread.
// EnrichedMarkdownText and EnrichedMarkdown both measure view-free
// (ENRMViewFreeMeasurement.h) and comply fully. The one known remaining
// violation is the text input's own measureContent
// (EnrichedMarkdownTextInputShadowNode.mm), which measures live editable
// UITextView state and needs its own strategy.

/**
 * Font scale (Dynamic Type multiplier) for measurement, without touching the
 * main thread.
 *
 * Reads `LayoutContext::fontSizeMultiplier` instead of calling
 * `RCTFontSizeMultiplier()` (a UIKit read that previously forced a
 * dispatch_sync to main on every measure — a deadlock window under the locked
 * commit fallback, see the contract above). RN maintains the multiplier for
 * us: `RCTFabricSurface::_updateLayoutContext` sets it on main from
 * `RCTFontSizeMultiplier()` and re-runs `constraintLayout` whenever
 * `UIContentSizeCategoryDidChangeNotification` fires, so every Dynamic Type
 * change re-measures with the fresh value. This is the same source
 * `ParagraphShadowNode` uses for core text. A measure racing a Dynamic Type
 * change at worst caches under the outgoing scale, which is never read again
 * once the re-layout lands.
 */
static inline CGFloat ENRMFontScaleForMeasurement(bool allowFontScaling, const LayoutContext &layoutContext)
{
  return allowFontScaling ? layoutContext.fontSizeMultiplier : 1.0;
}

static inline Size ENRMClampMeasuredSize(CGSize size, const LayoutConstraints &layoutConstraints)
{
  Float clampedWidth = std::max((Float)size.width, layoutConstraints.minimumSize.width);
  clampedWidth = std::min(clampedWidth, layoutConstraints.maximumSize.width);
  Float clampedHeight = std::max((Float)size.height, layoutConstraints.minimumSize.height);
  if (std::isfinite(layoutConstraints.maximumSize.height)) {
    clampedHeight = std::min(clampedHeight, layoutConstraints.maximumSize.height);
  }
  return {clampedWidth, clampedHeight};
}

/// Whether the streaming flag and modes, which decide what the view renders but
/// stay out of the cache key, are the same in both.
template <typename PropsT> static inline bool ENRMStreamingRenderEqual(const PropsT &a, const PropsT &b)
{
  return a.streamingAnimation == b.streamingAnimation && a.streamingConfig.tableMode == b.streamingConfig.tableMode &&
         a.streamingConfig.codeBlockMode == b.streamingConfig.codeBlockMode &&
         a.streamingConfig.mediaMode == b.streamingConfig.mediaMode;
}

/**
 * Renders the content of a view that has not mounted yet (and is not
 * streaming) for its first apply to take (ENRMPreparedRenderStore), so a newly
 * mounted view never parses on main. Returns the new render for the caller to
 * measure, or nil when the view mounted, streams, or a render is already kept.
 */
static inline id ENRMPrepareFirstRender(bool mounted, bool streaming, const ENRMPreparedRenderKey &key,
                                        id _Nullable (^render)(void))
{
  if (mounted || streaming) {
    return nil;
  }
  return [ENRMPreparedRenderStore prepareForKey:key render:render];
}

/**
 * Shared measureContent implementation for the markdown component views.
 *
 * Owns the thread-safe layers — the size the view laid a stream out at
 * (`laidOutSizeForWidth:`, see below), the LRU measurement cache, and the
 * `layoutContext`-sourced font scale — then
 * delegates cache misses to `measureUncached`, through which both components
 * plug their view-free pipeline (`ENRMMeasureMarkdownViewFree` /
 * `ENRMMeasureSegmentedMarkdownViewFree`); the resolved view is still handed
 * to the block for strategies that can use it. `fontScale` handed to the
 * block is the real multiplier even when streaming skips the cache —
 * rendering must always use it. `wrappedCodeBlocksFingerprint` folds view
 * state outside the props that changes the size (code blocks the user wrapped)
 * into the cache key. For a view that has not mounted yet, `render` renders
 * the content once for its first apply (ENRMPrepareFirstRender), even on a
 * cache hit; a cache miss measures that render instead of rendering again.
 */
template <typename PropsT, typename ViewT>
static inline Size ENRMMeasureMarkdownContent(
    const std::shared_ptr<const PropsT> &props, const std::shared_ptr<void> &componentViewRef, int heightCounter,
    ENRMPreviousMeasurement<PropsT> &previous, MarkdownFlavor flavor, const LayoutContext &layoutContext,
    const LayoutConstraints &layoutConstraints, NSWritingDirection resolvedLayoutDirection,
    id _Nullable (^render)(CGFloat fontScale),
    CGSize (^measureUncached)(ViewT *view, CGFloat maxWidth, CGFloat fontScale, id _Nullable rendered),
    size_t wrappedCodeBlocksFingerprint = 0)
{
  const PropsT &typedProps = *props;
  CGFloat maxWidth = layoutConstraints.maximumSize.width;

  RCTInternalGenericWeakWrapper *weakWrapper = (RCTInternalGenericWeakWrapper *)unwrapManagedObject(componentViewRef);
  ViewT *view = weakWrapper ? (ViewT *)weakWrapper.object : nil;

  const bool shouldUseMeasurementCache = !typedProps.streamingAnimation;
  CGFloat fontScale = ENRMFontScaleForMeasurement(typedProps.allowFontScaling, layoutContext);

  // A stream's update: the markdown kept all of the previous and nothing else that
  // sizes the content changed. The view lays out every render it applies and asks
  // for a new layout when its height changes, so the size it laid out at spares
  // measuring the whole document again on every update (ENRMChooseMeasurement).
  // New content, another width or a view that hasn't laid anything out measure in full.
  MeasurementCacheKey layoutKey =
      buildMeasurementCacheKey(typedProps, 0, fontScale, flavor, wrappedCodeBlocksFingerprint, false);
  const bool streamUpdate = previous.props && previous.layoutKey == layoutKey &&
                            previous.layoutDirection == static_cast<int>(resolvedLayoutDirection) &&
                            ENRMStreamingRenderEqual(*previous.props, typedProps) &&
                            ENRMMarkdownExtends(previous.props->markdown, typedProps.markdown);
  const CGSize laidOut = streamUpdate && view ? [view laidOutSizeForWidth:maxWidth
                                                         pointScaleFactor:layoutContext.pointScaleFactor
                                                                 markdown:typedProps.markdown]
                                              : CGSizeZero;
  const ENRMMeasurementSource source =
      ENRMChooseMeasurement(streamUpdate, streamUpdate && typedProps.markdown.size() > previous.props->markdown.size(),
                            previous.heightCounter != heightCounter, view != nil, laidOut.height > 0,
                            std::abs(previous.maxWidth - maxWidth) * layoutContext.pointScaleFactor < 1);

  previous.props = props;
  previous.layoutKey = std::move(layoutKey);
  previous.layoutDirection = static_cast<int>(resolvedLayoutDirection);
  previous.heightCounter = heightCounter;
  previous.maxWidth = maxWidth;
  if (source == ENRMMeasurementSource::Previous) {
    return ENRMClampMeasuredSize(CGSizeMake(previous.width, previous.height), layoutConstraints);
  }
  if (source == ENRMMeasurementSource::LaidOut) {
    previous.width = laidOut.width;
    previous.height = laidOut.height;
    return ENRMClampMeasuredSize(laidOut, layoutConstraints);
  }

  id rendered =
      ENRMPrepareFirstRender(view != nil, typedProps.streamingAnimation,
                             {props, fontScale, resolvedLayoutDirection, nil}, ^id { return render(fontScale); });

  if (shouldUseMeasurementCache && !typedProps.markdown.empty()) {
    auto cacheKey = buildMeasurementCacheKey(typedProps, maxWidth, fontScale, flavor, wrappedCodeBlocksFingerprint);
    CachedSize cached;
    if (MeasurementCache::shared().get(cacheKey, cached)) {
      previous.width = cached.width;
      previous.height = cached.height;
      return ENRMClampMeasuredSize(CGSizeMake(cached.width, cached.height), layoutConstraints);
    }
  }

  CGSize size = measureUncached(view, maxWidth, fontScale, rendered);

  if (shouldUseMeasurementCache && !typedProps.markdown.empty()) {
    auto cacheKey = buildMeasurementCacheKey(typedProps, maxWidth, fontScale, flavor, wrappedCodeBlocksFingerprint);
    MeasurementCache::shared().set(cacheKey, {size.width, size.height});
  }

  previous.width = size.width;
  previous.height = size.height;
  return ENRMClampMeasuredSize(size, layoutConstraints);
}

} // namespace facebook::react
