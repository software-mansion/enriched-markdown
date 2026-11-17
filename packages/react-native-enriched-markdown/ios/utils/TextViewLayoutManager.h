#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@class StyleConfig;
@class ENRMStreamingEffects;

@interface TextViewLayoutManager : NSLayoutManager

@property (nonatomic, strong) StyleConfig *config;
/// Set while a streaming text draws: what is drawn behind characters fades with them.
@property (nonatomic, weak, nullable) ENRMStreamingEffects *drawingEffects;
@property (nonatomic) CFTimeInterval drawingTime;

/// How much of the characters in `range` shows, on average: 1 unless they are animating.
- (CGFloat)visibilityOfCharactersInRange:(NSRange)range;

#if !TARGET_OS_OSX
/// Draws the glyphs in `color` instead of their own (a streaming effect).
- (void)drawGlyphsForGlyphRange:(NSRange)glyphRange atPoint:(CGPoint)origin color:(UIColor *)color;
#endif

@end

NS_ASSUME_NONNULL_END
