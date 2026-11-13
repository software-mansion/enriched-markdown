#pragma once

#import "ENRMTextRenderer.h"
#import "ENRMUIKit.h"
#import "RenderedMarkdownSegment.h"
#import <Foundation/Foundation.h>
#include <memory>

NS_ASSUME_NONNULL_BEGIN

/// What a render depends on: the props object it was rendered from (props are
/// immutable, so the same object means the same markdown, style and flags;
/// only its identity is compared) and the inputs outside the props.
struct ENRMPreparedRenderKey {
  std::shared_ptr<const void> props;
  CGFloat fontScale;
  NSWritingDirection layoutDirection;
  NSSet<NSString *> *_Nullable slotIds;
};

/**
 * Hands content that Yoga's measurement rendered on the layout thread to the
 * view's first render, so a newly mounted view applies it in the mount
 * transaction without parsing the markdown again (#1131).
 *
 * Only views that have not mounted yet prepare a render. Each is taken once,
 * on mount, and its props then count as handled until they are freed.
 */
@interface ENRMPreparedRenderStore : NSObject

/// Renders with `render` and keeps the result, unless one is already kept or
/// was taken for these props. Returns the new render, or nil.
+ (nullable id)prepareForKey:(const ENRMPreparedRenderKey &)key render:(id _Nullable (^)(void))render;

/// The render prepared for these props, once, if every input matches.
+ (nullable id)takeForKey:(const ENRMPreparedRenderKey &)key;

@end

static inline NSArray<ENRMRenderedSegment *> *_Nullable ENRMTakePreparedSegments(const ENRMPreparedRenderKey &key)
{
  id result = [ENRMPreparedRenderStore takeForKey:key];
  return [result isKindOfClass:[NSArray class]] ? result : nil;
}

static inline ENRMRenderResult *_Nullable ENRMTakePreparedText(const ENRMPreparedRenderKey &key)
{
  id result = [ENRMPreparedRenderStore takeForKey:key];
  return [result isKindOfClass:[ENRMRenderResult class]] ? result : nil;
}

NS_ASSUME_NONNULL_END
