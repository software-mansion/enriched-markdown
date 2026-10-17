#pragma once

#import "ENRMUIKit.h"
#import <React/RCTViewComponentView.h>

NS_ASSUME_NONNULL_BEGIN

/// Fabric child of the GFM host carrying one React replacement for a block. The
/// host's shadow node measures it at the block's width and places it where the
/// native block would have been; this view only mounts the React subtree.
@interface EnrichedMarkdownBlockSlot : RCTViewComponentView

@property (nonatomic, copy, readonly) NSString *slotId;

@end

NS_ASSUME_NONNULL_END
