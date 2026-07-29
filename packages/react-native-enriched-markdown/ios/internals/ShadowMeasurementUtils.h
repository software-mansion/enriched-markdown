#pragma once

#include "MeasurementCache.h"
#import <Foundation/Foundation.h>
#import <React/RCTUtils.h>
#include <TargetConditionals.h>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <mutex>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/utils/ManagedObjectWrapper.h>

namespace facebook::react {

// measureContent runs on Yoga's background layout thread and uses
// dispatch_sync to main for UIKit reads. Safe because RN never
// synchronously joins the layout queue from main. A synchronous
// layout flush from main would deadlock.

inline CGFloat ENRMFontScaleForMeasurement(bool allowFontScaling)
{
  if (!allowFontScaling) {
    return 1.0;
  }

  static std::atomic<double> cachedScale{0.0};
  static std::once_flag flag;

  std::call_once(flag, [] {
    __block CGFloat scale = 1.0;
    void (^readScale)(void) = ^{ scale = RCTFontSizeMultiplier(); };

    if ([NSThread isMainThread]) {
      readScale();
    } else {
      dispatch_sync(dispatch_get_main_queue(), readScale);
    }
    cachedScale.store(scale, std::memory_order_relaxed);

#if !TARGET_OS_OSX
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter]
          addObserverForName:UIContentSizeCategoryDidChangeNotification
                      object:nil
                       queue:[NSOperationQueue mainQueue]
                  usingBlock:^(NSNotification *) {
                    cachedScale.store(RCTFontSizeMultiplier(), std::memory_order_relaxed);
                  }];
    });
#endif
  });

  return cachedScale.load(std::memory_order_relaxed);
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

template <typename PropsT>
static inline bool ENRMPropsNeedExactStreamingMeasurement(const PropsT &oldProps, const PropsT &newProps)
{
  return oldProps.streamingAnimation != newProps.streamingAnimation ||
         oldProps.allowFontScaling != newProps.allowFontScaling ||
         oldProps.maxFontSizeMultiplier != newProps.maxFontSizeMultiplier ||
         oldProps.allowTrailingMargin != newProps.allowTrailingMargin ||
         oldProps.md4cFlags.underline != newProps.md4cFlags.underline ||
         oldProps.md4cFlags.superscript != newProps.md4cFlags.superscript ||
         oldProps.md4cFlags.subscript != newProps.md4cFlags.subscript ||
         oldProps.md4cFlags.latexMath != newProps.md4cFlags.latexMath ||
         computeStyleFingerprint(oldProps.markdownStyle) != computeStyleFingerprint(newProps.markdownStyle);
}

template <typename PropsT, typename ViewT>
static inline Size ENRMMeasureMarkdownContent(const PropsT &typedProps, const std::shared_ptr<void> &componentViewRef,
                                              int receivedCounter, int &lastExactMeasurementCounter,
                                              MarkdownFlavor flavor, const LayoutConstraints &layoutConstraints,
                                              ViewT * (^createMockView)(CGFloat width))
{
  CGFloat maxWidth = layoutConstraints.maximumSize.width;

  RCTInternalGenericWeakWrapper *weakWrapper = (RCTInternalGenericWeakWrapper *)unwrapManagedObject(componentViewRef);
  ViewT *view = weakWrapper ? (ViewT *)weakWrapper.object : nil;

  if (typedProps.streamingAnimation && view && receivedCounter <= lastExactMeasurementCounter) {
    __block CGSize currentSize = CGSizeZero;
    void (^readCurrentSize)(void) = ^{
      if (view.bounds.size.width > 0 && view.bounds.size.height > 0) {
        currentSize = view.bounds.size;
      }
    };

    if ([NSThread isMainThread]) {
      readCurrentSize();
    } else {
      dispatch_sync(dispatch_get_main_queue(), readCurrentSize);
    }

    if (currentSize.height > 0) {
      return ENRMClampMeasuredSize(currentSize, layoutConstraints);
    }
  }

  const bool shouldUseMeasurementCache = !typedProps.streamingAnimation;
  CGFloat fontScale = shouldUseMeasurementCache ? ENRMFontScaleForMeasurement(typedProps.allowFontScaling) : 1.0;

  if (shouldUseMeasurementCache && !typedProps.markdown.empty()) {
    auto cacheKey = buildMeasurementCacheKey(typedProps, maxWidth, fontScale, flavor);
    CachedSize cached;
    if (MeasurementCache::shared().get(cacheKey, cached)) {
      return ENRMClampMeasuredSize(CGSizeMake(cached.width, cached.height), layoutConstraints);
    }
  }

  __block CGSize size;
  NSString *currentMarkdown = typedProps.markdown.empty() ? nil : @(typedProps.markdown.c_str());
  size_t styleFingerprint =
      computeStyleFingerprint(typedProps.markdownStyle) ^ std::hash<bool>{}(typedProps.allowTrailingMargin);

  void (^measureBlock)(void) = ^{
    if (view && (typedProps.streamingAnimation || ([view hasRenderedMarkdown:currentMarkdown] &&
                                                   [view hasRenderedWithStyleFingerprint:styleFingerprint]))) {
      size = [view measureSize:maxWidth];
    } else {
      ViewT *mockView = createMockView(maxWidth);
      size = [mockView measureSize:maxWidth];
    }
  };

  if ([NSThread isMainThread]) {
    measureBlock();
  } else {
    dispatch_sync(dispatch_get_main_queue(), measureBlock);
  }

  if (shouldUseMeasurementCache && !typedProps.markdown.empty()) {
    auto cacheKey = buildMeasurementCacheKey(typedProps, maxWidth, fontScale, flavor);
    MeasurementCache::shared().set(cacheKey, {size.width, size.height});
  }

  if (typedProps.streamingAnimation) {
    lastExactMeasurementCounter = receivedCounter;
  }

  return ENRMClampMeasuredSize(size, layoutConstraints);
}

} // namespace facebook::react
