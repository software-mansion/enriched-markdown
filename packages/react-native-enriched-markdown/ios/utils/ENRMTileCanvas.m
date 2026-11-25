#import "ENRMTileCanvas.h"
#import "ENRMCapture.h"
#import <QuartzCore/QuartzCore.h>

#if !TARGET_OS_OSX
// A square tile: one tall enough to amortize its fixed cost, small enough that a block a little wider
// or taller than the screen holds little beyond it, and that an edit at the end redraws little.
static const CGFloat kENRMTileSize = 256;

/// One tile: draws the canvas's content in its rect.
@interface ENRMCanvasTileView : UIView
@property (nonatomic, weak) ENRMTileCanvas *canvas;
@end

@implementation ENRMCanvasTileView

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    self.accessibilityElementsHidden = YES;
    self.contentMode = UIViewContentModeTopLeft;
  }
  return self;
}

- (void)drawRect:(CGRect)rect
{
  ENRMTileCanvas *canvas = self.canvas;
  id<ENRMTileCanvasDrawing> drawer = canvas.drawer;
  if (drawer == nil) {
    return;
  }
  // The drawer draws in the canvas's space.
  CGPoint origin = self.frame.origin;
  CGContextTranslateCTM(UIGraphicsGetCurrentContext(), -origin.x, -origin.y);
  [drawer drawTileCanvasContentInRect:CGRectOffset(rect, origin.x, origin.y)];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];
  if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
    [self setNeedsDisplay];
  }
}

@end

/// A capture that renders the layer tree as it is (renderInContext:) would find only the tiles near
/// the screen: the canvas's layer draws the whole content into it instead.
@interface ENRMTileCanvasLayer : CALayer
@end

@implementation ENRMTileCanvasLayer

- (void)renderInContext:(CGContextRef)context
{
  ENRMTileCanvas *canvas = (ENRMTileCanvas *)self.delegate;
  id<ENRMTileCanvasDrawing> drawer = [canvas isKindOfClass:[ENRMTileCanvas class]] ? canvas.drawer : nil;
  // The drawers use TextKit, which is main thread only: elsewhere the capture gets the tiles as they are.
  if (drawer == nil || !NSThread.isMainThread) {
    [super renderInContext:context];
    return;
  }
  CGRect rect = CGRectIntersection(self.bounds, CGContextGetClipBoundingBox(context));
  if (self.hidden || CGRectIsNull(rect) || CGRectIsEmpty(rect)) {
    return;
  }
  // In the canvas's appearance, as the tiles draw, not the caller's.
  [canvas.traitCollection performAsCurrentTraitCollection:^{
    UIGraphicsPushContext(context);
    [drawer drawTileCanvasContentInRect:rect];
    UIGraphicsPopContext();
  }];
}

@end

@interface ENRMTileCanvas () <ENRMCaptureParticipant>
@end

@implementation ENRMTileCanvas {
  // Keyed by ENRMTileKey(column, row).
  NSMutableDictionary<NSNumber *, ENRMCanvasTileView *> *_tiles;
  // The part a capture in progress shows (ENRMCapture), CGRectNull when none: tiles cover it as well.
  CGRect _capturedRect;
  NSInteger _captures;
}

static NSNumber *ENRMTileKey(NSInteger column, NSInteger row)
{
  return @(((int64_t)row << 32) | (uint32_t)column);
}

+ (Class)layerClass
{
  return [ENRMTileCanvasLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    self.accessibilityElementsHidden = YES;
    _tiles = [NSMutableDictionary dictionary];
    _drawnRect = CGRectNull;
    _capturedRect = CGRectNull;
    // From the start: a canvas made off screen has no tiles, and a capture must add them.
    ENRMCaptureAddParticipant(self);
  }
  return self;
}

- (void)setDrawnRect:(CGRect)drawnRect
{
  if (CGRectEqualToRect(drawnRect, _drawnRect)) {
    return;
  }
  _drawnRect = drawnRect;
  [self layoutTiles];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  [self layoutTiles];
}

// Tiles for the drawn rect (and a capture's), on a fixed grid: kept while it moves, made as it reaches
// them, dropped as it leaves them. Returns whether a tile was made or resized.
- (BOOL)layoutTiles
{
  CGSize size = self.bounds.size;
  CGRect drawn = CGRectIsEmpty(_drawnRect) ? CGRectNull : _drawnRect;
  CGRect rect = CGRectIntersection(CGRectUnion(drawn, _capturedRect), CGRectMake(0, 0, size.width, size.height));
  NSInteger firstColumn = 0, endColumn = 0, firstRow = 0, endRow = 0;
  if (!CGRectIsNull(rect) && !CGRectIsEmpty(rect)) {
    firstColumn = (NSInteger)floor(CGRectGetMinX(rect) / kENRMTileSize);
    endColumn = (NSInteger)ceil(CGRectGetMaxX(rect) / kENRMTileSize);
    firstRow = (NSInteger)floor(CGRectGetMinY(rect) / kENRMTileSize);
    endRow = (NSInteger)ceil(CGRectGetMaxY(rect) / kENRMTileSize);
  }
  for (NSNumber *key in _tiles.allKeys) {
    int64_t value = key.longLongValue;
    NSInteger row = (NSInteger)(value >> 32);
    NSInteger column = (NSInteger)(int32_t)(value & 0xFFFFFFFF);
    if (column < firstColumn || column >= endColumn || row < firstRow || row >= endRow) {
      [_tiles[key] removeFromSuperview];
      [_tiles removeObjectForKey:key];
    }
  }
  BOOL changed = NO;
  for (NSInteger row = firstRow; row < endRow; row++) {
    for (NSInteger column = firstColumn; column < endColumn; column++) {
      // The last row and column end with the canvas, and grow with it.
      CGFloat x = column * kENRMTileSize;
      CGFloat y = row * kENRMTileSize;
      CGRect frame = CGRectMake(x, y, MIN(kENRMTileSize, size.width - x), MIN(kENRMTileSize, size.height - y));
      NSNumber *key = ENRMTileKey(column, row);
      ENRMCanvasTileView *tile = _tiles[key];
      if (tile == nil) {
        tile = [[ENRMCanvasTileView alloc] initWithFrame:frame];
        tile.canvas = self;
        [self addSubview:tile];
        _tiles[key] = tile;
        changed = YES;
      } else if (!CGRectEqualToRect(tile.frame, frame)) {
        tile.frame = frame;
        [tile setNeedsDisplay];
        changed = YES;
      }
    }
  }
  return changed;
}

- (void)setTilesNeedDisplay
{
  for (ENRMCanvasTileView *tile in _tiles.allValues) {
    [tile setNeedsDisplay];
  }
}

- (void)setTilesNeedDisplayFromY:(CGFloat)y
{
  for (ENRMCanvasTileView *tile in _tiles.allValues) {
    if (CGRectGetMaxY(tile.frame) > y) {
      [tile setNeedsDisplay];
    }
  }
}

- (ENRMCaptureCoverage)beginCaptureOfView:(UIView *)view
{
  if (self.window == nil || self.window != view.window || ![self isDescendantOfView:view]) {
    return ENRMCaptureCoverageNone;
  }
  CGRect shown = CGRectIntersection([view convertRect:view.bounds toView:self], self.bounds);
  if (CGRectIsNull(shown) || CGRectIsEmpty(shown)) {
    return ENRMCaptureCoverageNone;
  }
  _captures++;
  _capturedRect = CGRectUnion(_capturedRect, shown);
  return [self layoutTiles] ? ENRMCaptureCoverageAdded : ENRMCaptureCoverageDrawn;
}

// A capture inside another one (a view capturing itself as it draws) ends with the outer one.
- (void)endCapture
{
  if (--_captures == 0) {
    _capturedRect = CGRectNull;
    [self layoutTiles];
  }
}

@end
#endif
