#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@class StyleConfig;

@interface TextViewLayoutManager : NSLayoutManager

@property (nonatomic, strong) StyleConfig *config;

#if !TARGET_OS_OSX
/// Draws the glyphs in `color` instead of their own (a streaming effect).
- (void)drawGlyphsForGlyphRange:(NSRange)glyphRange atPoint:(CGPoint)origin color:(UIColor *)color;
#endif

@end

NS_ASSUME_NONNULL_END
