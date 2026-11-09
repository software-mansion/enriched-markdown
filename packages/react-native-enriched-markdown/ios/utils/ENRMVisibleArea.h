#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/// Text and blocks are drawn this far beyond the visible area on each side, so a scroll shows
/// content drawn ahead of it; anything farther off screen draws nothing.
FOUNDATION_EXTERN const CGFloat ENRMVisibleAreaMargin;

/// Follows the part of a view that its window shows: it observes the scroll views above the view,
/// and the transforms of the views between them, and calls `onChange` when one of them changes.
@interface ENRMVisibleArea : NSObject

- (instancetype)initWithView:(RCTUIView *)view onChange:(void (^)(void))onChange NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// The part of the view the scroll views above it show, in the view's coordinates: their vertical
/// extent, across the whole width. Empty when they show none of it, CGRectInfinite when no scroll
/// view is above it, CGRectNull when the view is not in a window. Starts observing the scroll views
/// once the view is in a window.
- (CGRect)visibleRect;

@end

NS_ASSUME_NONNULL_END
