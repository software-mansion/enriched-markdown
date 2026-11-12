#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * What an image that could not be loaded shows instead: a tinted box with a picture
 * glyph and the alt text. Block images fill their box; inline images are a chip.
 */
@interface ENRMImageFailurePlaceholder : NSObject

- (instancetype)initWithAltText:(NSString *)altText
                          color:(RCTUIColor *)color
                       fontSize:(CGFloat)fontSize
                   borderRadius:(CGFloat)borderRadius;

/// The chip's width: square without alt text, otherwise as wide as the alt text
/// needs, up to the chip cap and `maxWidth` (ignored when 0).
- (CGFloat)chipWidthForHeight:(CGFloat)height maxWidth:(CGFloat)maxWidth;

- (RCTUIImage *)imageForSize:(CGSize)size isInline:(BOOL)isInline;

@end

NS_ASSUME_NONNULL_END
