#pragma once
#import "ENRMBackgroundFills.h"
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@class StyleConfig;

/// A view that draws the background fills itself, beneath the selection highlight
/// (see ENRMBackgroundFillMode).
@protocol ENRMBackgroundFillsHost <NSObject>
/// The fills' geometry or colors may have changed.
- (void)setNeedsBackgroundFillsUpdate;
@end

@interface TextViewLayoutManager : NSLayoutManager

@property (nonatomic, strong) StyleConfig *config;

/// When set, the text pass draws only the blockquote stripes and the host draws the code and
/// quote boxes from `enumerateBackgroundFillsAtPoint:usingBlock:`. Held weakly.
@property (nonatomic, weak, nullable) id<ENRMBackgroundFillsHost> backgroundFillsHost;

/// Lays out the whole text container and reports every code block, inline code and blockquote
/// box piece in painting order, offset by `origin`.
- (void)enumerateBackgroundFillsAtPoint:(CGPoint)origin usingBlock:(ENRMBackgroundFillSink)block;

@end

NS_ASSUME_NONNULL_END
