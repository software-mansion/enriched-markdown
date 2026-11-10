#pragma once
#import "ENRMStreamingEffects.h"
#import "ENRMUIKit.h"

#if !TARGET_OS_OSX
NS_ASSUME_NONNULL_BEGIN

/// Draws a text view's text in tiles that cover only the rect it is asked to draw.
///
/// UIKit draws a non-scrolling text view's text into one canvas the size of its frame, about 7.5 MB
/// per screen of a long text. The canvas is kept 0 high and the tiles draw the text instead. When
/// UIKit has no such canvas (it is found by class name), the text view draws the whole text itself.
@interface ENRMTextTiles : NSObject

- (instancetype)initWithTextView:(UITextView *)textView NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Draws only the text in `rect` (the text view's space); an empty rect draws nothing.
- (void)setDrawnRect:(CGRect)rect;
/// Redraws from the line holding the glyph at `glyphIndex` on, when the text view lays out next.
- (void)setNeedsDisplayFromGlyphIndex:(NSUInteger)glyphIndex;
/// Called from the text view's layoutSubviews.
- (void)layout;

/// How the streaming text's newest characters look; the tiles draw them so.
@property (nonatomic, readonly) ENRMStreamingEffects *streamingEffects;
/// Redraws the characters the effects animate, every frame while they do.
- (void)streamingEffectsChanged;

@end

NS_ASSUME_NONNULL_END
#endif
