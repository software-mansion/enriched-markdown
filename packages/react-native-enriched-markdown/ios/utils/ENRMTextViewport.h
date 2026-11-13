#pragma once
#import "ENRMUIKit.h"

@class ENRMVisibleArea;

NS_ASSUME_NONNULL_BEGIN

/// Draws a long text view only around the part of it on screen.
///
/// A non-scrolling TextKit 1 text view keeps one bitmap of its whole frame (see ENRMTextTiles). The
/// text view keeps its whole frame, so UIKit's selection, menus, hit testing and accessibility work
/// on it as before, but it draws only the part of its text near the visible part of the enclosing
/// scroll views (plus a margin): see ENRMTextViewportView. A text off screen draws nothing.
///
/// On macOS the text view keeps covering the whole text.
@interface ENRMTextViewport : NSObject

- (instancetype)initWithTextView:(ENRMPlatformTextView *)textView NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// The text view's frame in its superview, set through the viewport.
@property (nonatomic, assign) CGRect contentFrame;

/// The area of the document the text is in, shared by its texts (EnrichedMarkdown's); its owner
/// calls `update` when it changes. Without one the viewport follows the scroll views itself.
@property (nonatomic, weak, nullable) ENRMVisibleArea *visibleArea;

/// Lays out the whole text at `width`: the used rect and the extra line fragment, as
/// `ENRMMeasureTextLayout` gives them. At another width than the frame's, the next `update` lays the
/// text out at the frame's width again.
- (ENRMTextLayoutResult)measureLayoutAtWidth:(CGFloat)width;

/// Moves the drawn rect to where the enclosing scroll views show the text now. Cheap when it has
/// not moved: call it whenever the text may have moved on screen.
- (void)update;

/// Lays the whole text out again and redraws the part on screen (after the text view joined a
/// window: a text laid out before it may have had no width).
- (void)refreshLayout;

@end

#if !TARGET_OS_OSX
/// A text view that can draw only part of its text.
@protocol ENRMTextViewportView <NSObject>
/// Draws only the text in `rect` (the text view's space); an empty rect draws nothing.
- (void)setDrawnRect:(CGRect)rect;
/// Redraws the text from the line holding the glyph at `glyphIndex` on: what the layout manager asks
/// its text view to redraw. Safe while the text storage is editing: the tiles are found later.
- (void)setNeedsDisplayFromGlyphIndex:(NSUInteger)glyphIndex;
/// The same from the character at `characterIndex`: TextKit doesn't pass every character range it is
/// asked to redraw on as a glyph range.
- (void)setNeedsDisplayFromCharacterIndex:(NSUInteger)characterIndex;
@end

/// The text container of a text view with a viewport. UIKit sizes a text view's container to the
/// view's frame on every frame change: a growing text's container shrinks to its frame and opens
/// again on each update (measurement), and TextKit drops its layout and lays it all out again. While
/// the size is held, only the viewport sets it.
@interface ENRMTextViewportContainer : NSTextContainer
@property (nonatomic, assign) BOOL sizeHeld;
- (void)setHeldSize:(CGSize)size;
@end
#endif

NS_ASSUME_NONNULL_END
