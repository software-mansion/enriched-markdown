#pragma once
#import "ENRMStreamingEffects.h"
#import "ENRMUIKit.h"

#if !TARGET_OS_OSX
NS_ASSUME_NONNULL_BEGIN

/// Draws a text view's text in tiles covering only the rect it is asked to draw: UIKit's own canvas
/// is the size of the frame, so a long text holds a bitmap for all of it. That canvas is found by
/// class name and kept 0 high; without it, or with EnrichedMarkdownDisableTextTiles in Info.plist,
/// the text view draws itself. Captures still get the whole text (renderInContext:, ENRMCapture).
@interface ENRMTextTiles : NSObject

- (instancetype)initWithTextView:(UITextView *)textView NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Draws only the text in `rect` (the text view's space); an empty rect draws nothing.
- (void)setDrawnRect:(CGRect)rect;
/// Redraws from the line holding the glyph at `glyphIndex` on, when the text view lays out next.
- (void)setNeedsDisplayFromGlyphIndex:(NSUInteger)glyphIndex;
- (void)setNeedsDisplayFromCharacterIndex:(NSUInteger)characterIndex;
/// Called from the text view's layoutSubviews.
- (void)layout;

/// How the streaming text's newest characters look; the tiles draw them so.
@property (nonatomic, readonly) ENRMStreamingEffects *streamingEffects;
/// Redraws the characters the effects animate, every frame while they do.
- (void)streamingEffectsChanged;

@end

NS_ASSUME_NONNULL_END
#endif
