#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/// A view in a block segment that draws its own bitmap (drawRect:). EnrichedMarkdown drops the bitmap
/// while the block is far off screen and draws it again when it comes near.
@protocol ENRMDroppableContent <NSObject>
@optional
// Layout can invalidate a dropped bitmap before scrolling or capture restores it.
- (void)setBitmapDrawingEnabled:(BOOL)enabled;
@end

NS_ASSUME_NONNULL_END
