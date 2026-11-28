#pragma once
#import "ENRMUIKit.h"

#if !TARGET_OS_OSX
NS_ASSUME_NONNULL_BEGIN

/// What an ENRMTileCanvas draws.
@protocol ENRMTileCanvasDrawing <NSObject>
/// Draws the content in `rect` (the canvas's space) into the current context. Main thread only.
- (void)drawTileCanvasContentInRect:(CGRect)rect;
@end

/// Draws a large view's content in tiles covering only the rect it is asked to draw. A view that
/// draws itself (drawRect:) holds one bitmap for its whole bounds, however little of it is on screen:
/// a tall code block with long lines holds hundreds of megabytes. The tiles draw on the main thread
/// as Core Animation commits, as ENRMTextTiles does for text, so a tile shows the moment it is made.
/// Captures still get the whole content (renderInContext:, ENRMCapture).
///
/// ENRMTextTiles does the same for a UITextView, but takes over UIKit's private text canvas and draws
/// the streaming effects; this one draws any content and has neither.
@interface ENRMTileCanvas : UIView

@property (nonatomic, weak, nullable) id<ENRMTileCanvasDrawing> drawer;

/// The part of the canvas to draw, in its space; CGRectNull or an empty rect draws nothing.
@property (nonatomic, assign) CGRect drawnRect;

/// Redraws every tile.
- (void)setTilesNeedDisplay;
/// Redraws the tiles reaching below `y` (the canvas's space): an edit moves the content below it.
- (void)setTilesNeedDisplayFromY:(CGFloat)y;

@end

NS_ASSUME_NONNULL_END
#endif
