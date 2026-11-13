#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/// A view in a block segment that draws its own bitmap (drawRect:). EnrichedMarkdown drops the bitmap
/// while the block is far off screen and draws it again when it comes near.
@protocol ENRMDroppableContent <NSObject>
@end

NS_ASSUME_NONNULL_END
