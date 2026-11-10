#import "ENRMTextTiles.h"
#import "TextViewLayoutManager.h"
#import <QuartzCore/QuartzCore.h>

#if !TARGET_OS_OSX
static const CGFloat kENRMTextTileHeight = 512;
// Backgrounds can reach past the lines they belong to (a code block's padding below its last line):
// a tile looks this far beyond its rect for the glyphs to draw, and an edit redraws from this far
// above it.
static const CGFloat kENRMTextTileOverdraw = 64;
static void *kENRMCanvasBoundsContext = &kENRMCanvasBoundsContext;

/// One tile of the text: draws the glyphs in its rect with the text view's layout manager, as the
/// text view's own canvas does.
@interface ENRMTextTileView : UIView
@property (nonatomic, weak) UITextView *textView;
@property (nonatomic, weak) ENRMStreamingEffects *effects;
@end

// The display link's target: it would retain the tiles.
@interface ENRMEffectsTicker : NSObject
@property (nonatomic, weak) ENRMTextTiles *tiles;
@end

@implementation ENRMTextTileView

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
  UITextView *textView = self.textView;
  if (textView == nil) {
    return;
  }
  NSLayoutManager *layoutManager = textView.layoutManager;
  CGPoint tileOrigin = [self convertPoint:CGPointZero toView:textView];
  CGPoint origin =
      CGPointMake(textView.textContainerInset.left - tileOrigin.x, textView.textContainerInset.top - tileOrigin.y);
  CGRect lookup = CGRectInset(rect, 0, -kENRMTextTileOverdraw);
  NSRange glyphs = [layoutManager glyphRangeForBoundingRect:CGRectOffset(lookup, -origin.x, -origin.y)
                                            inTextContainer:textView.textContainer];
  if (glyphs.length == 0) {
    return;
  }
  [layoutManager drawBackgroundForGlyphRange:glyphs atPoint:origin];
  CFTimeInterval now = CACurrentMediaTime();
  NSRange animated = self.effects != nil ? [self.effects animatedRangeAt:now] : NSMakeRange(NSNotFound, 0);
  NSRange shown = animated.location == NSNotFound || ![layoutManager isKindOfClass:[TextViewLayoutManager class]]
                      ? NSMakeRange(NSNotFound, 0)
                      : NSIntersectionRange(glyphs, [layoutManager glyphRangeForCharacterRange:animated
                                                                          actualCharacterRange:NULL]);
  if (shown.location == NSNotFound || shown.length == 0) {
    [layoutManager drawGlyphsForGlyphRange:glyphs atPoint:origin];
    return;
  }
  if (shown.location > glyphs.location) {
    [layoutManager drawGlyphsForGlyphRange:NSMakeRange(glyphs.location, shown.location - glyphs.location)
                                   atPoint:origin];
  }
  if (NSMaxRange(glyphs) > NSMaxRange(shown)) {
    [layoutManager drawGlyphsForGlyphRange:NSMakeRange(NSMaxRange(shown), NSMaxRange(glyphs) - NSMaxRange(shown))
                                   atPoint:origin];
  }
  [self drawAnimatedGlyphs:shown atPoint:origin time:now];
}

// The animated characters in the effects' colors, consecutive ones of one color in one go.
- (void)drawAnimatedGlyphs:(NSRange)glyphs atPoint:(CGPoint)origin time:(CFTimeInterval)time
{
  UITextView *textView = self.textView;
  TextViewLayoutManager *layoutManager = (TextViewLayoutManager *)textView.layoutManager;
  NSTextStorage *storage = textView.textStorage;
  NSString *string = storage.string;
  NSRange characters = [layoutManager characterRangeForGlyphRange:glyphs actualGlyphRange:NULL];
  CGContextRef context = UIGraphicsGetCurrentContext();
  NSUInteger runStart = characters.location;
  UIColor *runColor = nil;
  NSUInteger index = characters.location;
  while (index <= NSMaxRange(characters)) {
    UIColor *color = nil;
    NSRange composed = NSMakeRange(index, 0);
    if (index < NSMaxRange(characters)) {
      composed = [string rangeOfComposedCharacterSequenceAtIndex:index];
      UIColor *own =
          [storage attribute:NSForegroundColorAttributeName atIndex:index effectiveRange:NULL] ?: UIColor.labelColor;
      color = [self.effects colorForCharacterAtIndex:index ownColor:own time:time];
    }
    if (runColor != nil && ![color isEqual:runColor]) {
      CGFloat alpha = 0;
      [runColor getRed:NULL green:NULL blue:NULL alpha:&alpha];
      NSRange runGlyphs = [layoutManager glyphRangeForCharacterRange:NSMakeRange(runStart, index - runStart)
                                                actualCharacterRange:NULL];
      if (alpha > 0 && runGlyphs.length > 0) {
        CGContextSaveGState(context);
        CGContextSetAlpha(context, alpha);
        [layoutManager drawGlyphsForGlyphRange:runGlyphs atPoint:origin color:[runColor colorWithAlphaComponent:1]];
        CGContextRestoreGState(context);
      }
      runColor = nil;
    }
    if (runColor == nil) {
      runStart = index;
      runColor = color;
    }
    if (composed.length == 0) {
      break;
    }
    // A sequence reaching past the range still ends the last run.
    index = MIN(NSMaxRange(composed), NSMaxRange(characters));
  }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  // UIKit redraws its own canvas on a dark mode change, not these.
  [super traitCollectionDidChange:previousTraitCollection];
  if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
    [self setNeedsDisplay];
  }
}

@end

@implementation ENRMEffectsTicker

- (void)tick:(CADisplayLink *)link
{
  [self.tiles streamingEffectsChanged];
}

@end

@implementation ENRMTextTiles {
  ENRMStreamingEffects *_streamingEffects;
  CADisplayLink *_effectsLink;
  // The first character the last frame animated, redrawn once more as it settles.
  NSUInteger _animatedFrom;
  __weak UITextView *_textView;
  // UIKit's text container view, and the canvas in it.
  __weak UIView *_containerView;
  __weak UIView *_canvas;
  CALayer *_observedCanvasLayer;
  // The tiles sit in the container view, above the canvas: where the canvas draws, under UIKit's
  // selection and highlight views.
  UIView *_tileHost;
  NSMutableDictionary<NSNumber *, ENRMTextTileView *> *_tiles;
  CGFloat _tileWidth;
  CGRect _drawnRect;
  // What to redraw from, found once the text storage is done editing (layout).
  NSUInteger _redrawFromCharacter;
  NSUInteger _redrawFromGlyph;
}

- (instancetype)initWithTextView:(UITextView *)textView
{
  if (self = [super init]) {
    _textView = textView;
    _redrawFromCharacter = NSNotFound;
    _redrawFromGlyph = NSNotFound;
    _streamingEffects = [[ENRMStreamingEffects alloc] init];
    _animatedFrom = NSNotFound;
  }
  return self;
}

- (ENRMStreamingEffects *)streamingEffects
{
  return _streamingEffects;
}

- (void)streamingEffectsChanged
{
  UITextView *textView = _textView;
  NSRange animated = [_streamingEffects animatedRangeAt:CACurrentMediaTime()];
  NSUInteger from = MIN(animated.location, _animatedFrom);
  _animatedFrom = animated.location;
  NSUInteger length = textView.textStorage.length;
  if (from != NSNotFound && length > 0) {
    NSUInteger glyph = [textView.layoutManager glyphIndexForCharacterAtIndex:MIN(from, length - 1)];
    // A frame with no edit pending redraws the tiles at once, without laying the text view out.
    BOOL editPending = _redrawFromCharacter != NSNotFound || _redrawFromGlyph != NSNotFound;
    CGFloat y = editPending ? -1 : [self laidOutYForGlyphAtIndex:glyph];
    if (y >= 0) {
      [self setTilesNeedDisplayFromY:y];
    } else {
      [self setNeedsDisplayFromGlyphIndex:glyph];
    }
  }
  if (![_streamingEffects changesOverTimeAt:CACurrentMediaTime()]) {
    [_effectsLink invalidate];
    _effectsLink = nil;
  } else if (_effectsLink == nil && textView.window != nil) {
    ENRMEffectsTicker *ticker = [[ENRMEffectsTicker alloc] init];
    ticker.tiles = self;
    _effectsLink = [CADisplayLink displayLinkWithTarget:ticker selector:@selector(tick:)];
    [_effectsLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
  }
}

- (void)dealloc
{
  [_effectsLink invalidate];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_observedCanvasLayer removeObserver:self forKeyPath:@"bounds" context:kENRMCanvasBoundsContext];
}

// UIKit sizes the canvas to the frame again whenever it lays it out, so its bounds are observed.
// Only the canvas: UIKit maps touches (dragging a selection handle) and places the edit menu through
// the container view around it, and its selection geometry is empty while the container is hidden.
- (void)collapseCanvas
{
  UIView *canvas = _canvas;
  if (canvas != nil && canvas.superview == _containerView && canvas.frame.size.height != 0) {
    CGRect frame = canvas.frame;
    frame.size.height = 0;
    canvas.frame = frame;
  }
}

- (BOOL)prepareTiles
{
  UITextView *textView = _textView;
  if (_canvas != nil && _containerView.superview == textView && _canvas.superview == _containerView) {
    return YES;
  }
  _containerView = nil;
  _canvas = nil;
  Class containerClass = NSClassFromString(@"_UITextContainerView");
  Class canvasClass = NSClassFromString(@"_UITextViewCanvasView");
#if DEBUG
  static dispatch_once_t missingClassOnce;
  dispatch_once(&missingClassOnce, ^{
    if (containerClass == nil || canvasClass == nil) {
      NSLog(@"[EnrichedMarkdown] UIKit has no _UITextContainerView or _UITextViewCanvasView: long texts draw whole.");
    }
  });
#endif
  for (UIView *subview in textView.subviews) {
    if (containerClass != nil && [subview isKindOfClass:containerClass]) {
      _containerView = subview;
      break;
    }
  }
  for (UIView *subview in _containerView.subviews) {
    if (canvasClass != nil && [subview isKindOfClass:canvasClass]) {
      _canvas = subview;
      break;
    }
  }
  if (_canvas == nil) {
    return NO;
  }
  [self collapseCanvas];
  if (_observedCanvasLayer != _canvas.layer) {
    [_observedCanvasLayer removeObserver:self forKeyPath:@"bounds" context:kENRMCanvasBoundsContext];
    _observedCanvasLayer = _canvas.layer;
    [_observedCanvasLayer addObserver:self forKeyPath:@"bounds" options:0 context:kENRMCanvasBoundsContext];
  }
  if (_tiles == nil) {
    _tiles = [NSMutableDictionary dictionary];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textStorageDidProcessEditing:)
                                                 name:NSTextStorageDidProcessEditingNotification
                                               object:textView.textStorage];
  }
  return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{
  if (context != kENRMCanvasBoundsContext) {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    return;
  }
  [self collapseCanvas];
}

- (void)setDrawnRect:(CGRect)rect
{
  _drawnRect = rect;
  [self layoutTiles];
}

- (void)layout
{
  // UIKit may make its canvas only after the first drawn rect, or make a new one.
  [self layoutTiles];
  [self redrawEditedTiles];
  // Effects that began before the text view was in a window animate once it is.
  if (_effectsLink == nil && [_streamingEffects changesOverTimeAt:CACurrentMediaTime()]) {
    [self streamingEffectsChanged];
  }
}

// Tiles for the drawn rect, in tile height steps: kept while it moves, made as it reaches them.
- (void)layoutTiles
{
  if (![self prepareTiles]) {
    return;
  }
  UITextView *textView = _textView;
  if (_tileHost == nil) {
    _tileHost = [[UIView alloc] init];
    _tileHost.userInteractionEnabled = NO;
    _tileHost.accessibilityElementsHidden = YES;
  }
  if (_tileHost.superview != _containerView) {
    [_containerView insertSubview:_tileHost aboveSubview:_canvas];
  }
  _tileHost.frame = _containerView.bounds;
  CGFloat width = textView.bounds.size.width;
  if (width != _tileWidth) {
    for (ENRMTextTileView *tile in _tiles.allValues) {
      [tile removeFromSuperview];
    }
    [_tiles removeAllObjects];
    _tileWidth = width;
  }
  CGFloat height = textView.bounds.size.height;
  CGRect rect = CGRectIntersection(_drawnRect, CGRectMake(0, 0, width, height));
  NSInteger first = 0;
  NSInteger end = 0;
  if (!CGRectIsNull(rect) && rect.size.height > 0 && width > 0) {
    first = (NSInteger)floor(CGRectGetMinY(rect) / kENRMTextTileHeight);
    end = (NSInteger)ceil(CGRectGetMaxY(rect) / kENRMTextTileHeight);
  }
  for (NSNumber *index in _tiles.allKeys) {
    if (index.integerValue < first || index.integerValue >= end) {
      [_tiles[index] removeFromSuperview];
      [_tiles removeObjectForKey:index];
    }
  }
  for (NSInteger index = first; index < end; index++) {
    // In the text view's space; the last tile ends with the text, and a growing text grows it.
    CGFloat tileTop = index * kENRMTextTileHeight;
    CGRect frame = [textView convertRect:CGRectMake(0, tileTop, width, MIN(kENRMTextTileHeight, height - tileTop))
                                  toView:_tileHost];
    ENRMTextTileView *tile = _tiles[@(index)];
    if (tile == nil) {
      tile = [[ENRMTextTileView alloc] initWithFrame:frame];
      tile.textView = textView;
      tile.effects = _streamingEffects;
      [_tileHost addSubview:tile];
      _tiles[@(index)] = tile;
    } else if (!CGRectEqualToRect(tile.frame, frame)) {
      tile.frame = frame;
      [tile setNeedsDisplay];
    }
  }
}

// Redraws the tiles from `y` (the text view's space) down: an edit moves the text below it.
- (void)setTilesNeedDisplayFromY:(CGFloat)y
{
  UITextView *textView = _textView;
  for (ENRMTextTileView *tile in _tiles.allValues) {
    if (CGRectGetMaxY([_tileHost convertRect:tile.frame toView:textView]) > y - kENRMTextTileOverdraw) {
      [tile setNeedsDisplay];
    }
  }
}

// Where the line holding `glyphIndex` starts in the text view, if it is laid out; -1 when it is not.
- (CGFloat)laidOutYForGlyphAtIndex:(NSUInteger)glyphIndex
{
  UITextView *textView = _textView;
  NSLayoutManager *layoutManager = textView.layoutManager;
  if (glyphIndex >= layoutManager.numberOfGlyphs) {
    return -1;
  }
  CGRect line = [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex
                                                effectiveRange:NULL
                                       withoutAdditionalLayout:YES];
  return CGRectIsEmpty(line) ? -1 : CGRectGetMinY(line) + textView.textContainerInset.top;
}

// Called while the text storage edits too: the tiles are found in layout, where glyphs can be made.
- (void)setNeedsDisplayFromGlyphIndex:(NSUInteger)glyphIndex
{
  if (_tiles.count > 0) {
    _redrawFromGlyph = MIN(_redrawFromGlyph, glyphIndex);
    [_textView setNeedsLayout];
  }
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
  if (_tiles.count > 0) {
    _redrawFromCharacter = MIN(_redrawFromCharacter, ((NSTextStorage *)notification.object).editedRange.location);
    [_textView setNeedsLayout];
  }
}

// Redraws what edits and display invalidations touched since the last layout: from the first line
// either touched, or the first one the layout dropped, down.
- (void)redrawEditedTiles
{
  if (_redrawFromCharacter == NSNotFound && _redrawFromGlyph == NSNotFound) {
    return;
  }
  UITextView *textView = _textView;
  NSLayoutManager *layoutManager = textView.layoutManager;
  NSUInteger length = textView.textStorage.length;
  NSUInteger glyph = _redrawFromGlyph;
  if (_redrawFromCharacter != NSNotFound && length > 0) {
    glyph = MIN(glyph, [layoutManager glyphIndexForCharacterAtIndex:MIN(_redrawFromCharacter, length - 1)]);
  }
  _redrawFromCharacter = NSNotFound;
  _redrawFromGlyph = NSNotFound;
  CGFloat y = glyph != NSNotFound ? [self laidOutYForGlyphAtIndex:glyph] : -1;
  NSUInteger firstUnlaid = layoutManager.firstUnlaidGlyphIndex;
  if (firstUnlaid < layoutManager.numberOfGlyphs) {
    CGFloat unlaidY = firstUnlaid > 0 ? [self laidOutYForGlyphAtIndex:firstUnlaid - 1] : 0;
    y = y < 0 ? unlaidY : MIN(y, MAX(unlaidY, 0));
  }
  [self setTilesNeedDisplayFromY:MAX(y, 0)];
}

@end
#endif
