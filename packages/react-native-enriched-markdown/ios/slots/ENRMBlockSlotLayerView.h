#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/// Holds the GFM host's Fabric children above the segment views. It is as
/// large as the host, so it only answers hit tests for its children and lets
/// every other touch fall through to the text and block views beneath.
@interface ENRMBlockSlotLayerView : RCTUIView
@end

NS_ASSUME_NONNULL_END
