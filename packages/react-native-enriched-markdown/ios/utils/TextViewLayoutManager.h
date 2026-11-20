#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@class StyleConfig;
@class ENRMStreamingEffects;
@class ENRMTextHighlight;

@interface TextViewLayoutManager : NSLayoutManager

@property (nonatomic, strong) StyleConfig *config;
/// Draws the backgrounds with what sits behind characters (inline code boxes, list markers) fading
/// with `effects` at `time`. No ivars: this class is set onto layout managers UIKit already made.
- (void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow
                            atPoint:(CGPoint)origin
                            effects:(nullable ENRMStreamingEffects *)effects
                               time:(CFTimeInterval)time;

/// How much of the characters in `range` shows, on average: 1 unless they are animating.
- (CGFloat)visibilityOfCharactersInRange:(NSRange)range;

#if !TARGET_OS_OSX
/// Draws the glyphs in `color` instead of their own (a streaming effect).
- (void)drawGlyphsForGlyphRange:(NSRange)glyphRange atPoint:(CGPoint)origin color:(UIColor *)color;
#endif

/// Drawn behind the glyphs, after the code backgrounds. Setting it redraws
/// only the ranges that change.
@property (nonatomic, copy) NSArray<ENRMTextHighlight *> *textHighlights;

@end

NS_ASSUME_NONNULL_END
