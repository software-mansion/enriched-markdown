#import "ENRMCodeBlockContainerView.h"
#import "ENRMAccessibilityLabels.h"
#import "ENRMCodeBlockContent.h"
#import "ENRMCodeBlockHighlighter.h"
#import "ENRMDroppableContent.h"
#import "ENRMHorizontalScrollView.h"
#import "ENRMTileCanvas.h"
#import "ENRMVisibleArea.h"
#import "MarkdownASTNode.h"
#import "PasteboardUtils.h"
#if TARGET_OS_OSX
#import "ENRMMenuAction.h"
#endif

// Block segment view for fenced code blocks (see SegmentRenderer.m):
// a fixed header bar (language name, copy button) above a horizontally
// scrolling, non-wrapping code pane. On iOS the container's layer draws the
// background and border, and small subviews the label and divider, so a tall
// block holds no bitmap of its own size; the code pane draws in tiles near the
// screen (ENRMCodeBlockContentView). On macOS the container's drawRect: draws
// background, border, label, and divider. Syntax coloring comes from the
// ENRMCodeBlockHighlighter seam and falls back to plain text. The box
// visuals must stay in sync with the commonmark flavor's CodeBlockBackground.
//
// measureHeight: must stay in sync with the drawn content: it uses the
// unconstrained bounding rect of the same attributed string and the same
// header metrics, so the reported height matches the drawn height. Unless the
// block is wrapped (the optional header wrap toggle), lines never wrap and the
// height is independent of the available width.

static const CGFloat kENRMHeaderLabelScale = 0.85;
// The copy glyph reads cleaner a touch smaller than the language label and at a
// regular (not medium) weight; sized independently so the two never couple.
static const CGFloat kENRMHeaderIconScale = 0.72;
static const CGFloat kENRMHeaderSecondaryAlpha = 0.6;
static const CGFloat kENRMHeaderDividerAlpha = 0.2;

// Height geometry and code-run construction shared by the instance layout path
// and the view-free measureHeightForCodeBlockNode:, so the two cannot drift.

static CGFloat ENRMCodeBlockContentInset(StyleConfig *config)
{
  return [config codeBlockPadding] + [config codeBlockBorderWidth];
}

#if !TARGET_OS_OSX
static UIFont *ENRMCodeBlockHeaderFont(StyleConfig *config)
{
  return [UIFont systemFontOfSize:[config codeBlockFont].pointSize * kENRMHeaderLabelScale weight:UIFontWeightMedium];
}

static UIImageSymbolConfiguration *ENRMCodeBlockHeaderSymbolConfiguration(StyleConfig *config)
{
  return [UIImageSymbolConfiguration configurationWithPointSize:[config codeBlockFont].pointSize * kENRMHeaderIconScale
                                                         weight:UIImageSymbolWeightRegular];
}

static CGFloat ENRMCodeBlockHeaderLabelLineHeight(UIFont *headerFont)
{
  return ceil(UIFontLineHeight(headerFont));
}
#else
static NSFont *ENRMCodeBlockHeaderFont(StyleConfig *config)
{
  return [NSFont systemFontOfSize:[config codeBlockFont].pointSize * kENRMHeaderLabelScale weight:NSFontWeightMedium];
}

static CGFloat ENRMCodeBlockHeaderLabelLineHeight(NSFont *headerFont)
{
  return ceil(UIFontLineHeight(headerFont));
}
#endif

static NSAttributedString *ENRMCodeBlockPlainAttributedCode(NSString *code, StyleConfig *config)
{
  if (code.length == 0) {
    return [[NSAttributedString alloc] initWithString:@""];
  }
  NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:code];
  ENRMApplyCodeBlockTextAttributes(attributed, NSMakeRange(0, attributed.length), config);
  return attributed;
}

// Per-line height applied to the code text (see ENRMApplyCodeBlockTextAttributes):
// when a code block line height is configured every line fragment is exactly that
// tall; otherwise the font's natural line height is used.
static CGFloat ENRMCodeBlockPerLineHeight(StyleConfig *config)
{
  CGFloat lineHeight = [config codeBlockLineHeight];
  return lineHeight > 0 ? lineHeight : ceil(UIFontLineHeight([config codeBlockFont]));
}

// Analytic code height: lines never wrap and each fragment is a fixed height, so
// the laid-out height is simply lineCount * perLineHeight. No text layout needed,
// which is what boundingRectWithSize used to do on the whole block.
static CGFloat ENRMCodeBlockCodeHeight(NSString *code, StyleConfig *config)
{
  if (code.length == 0) {
    return 0;
  }
  __block NSUInteger lineCount = 0;
  [code enumerateSubstringsInRange:NSMakeRange(0, code.length)
                           options:NSStringEnumerationByLines | NSStringEnumerationSubstringNotRequired
                        usingBlock:^(NSString *_Nullable substring, NSRange substringRange, NSRange enclosingRange,
                                     BOOL *stop) { lineCount++; }];
  if (lineCount == 0) {
    lineCount = 1;
  }
  return ceil(lineCount * ENRMCodeBlockPerLineHeight(config));
}

// Width the code text gets when wrapped: the block width minus the border and
// the code pane's horizontal padding, exactly as layoutScrollArea insets it.
static CGFloat ENRMCodeBlockWrapWidth(CGFloat blockWidth, StyleConfig *config)
{
  CGFloat borderW = ceil([config codeBlockBorderWidth]);
  CGFloat horizontalPad = MAX(ENRMCodeBlockContentInset(config) - borderW, 0);
  return MAX(blockWidth - borderW * 2, 0) - horizontalPad * 2;
}

// Wrapped code height: the same per-line-height arithmetic as the analytic
// height, over visual lines from a call-confined TextKit layout at the wrap width.
static CGFloat ENRMCodeBlockWrappedCodeHeight(NSAttributedString *code, CGFloat wrapWidth, StyleConfig *config)
{
  if (code.length == 0) {
    return 0;
  }
  NSTextStorage *storage = [[NSTextStorage alloc] initWithAttributedString:code];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  layoutManager.usesFontLeading = ENRMLayoutManagerUsesFontLeading;
  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(wrapWidth, CGFLOAT_MAX)];
  container.lineFragmentPadding = 0;
  [layoutManager addTextContainer:container];
  [storage addLayoutManager:layoutManager];
  [layoutManager ensureLayoutForTextContainer:container];
  __block NSUInteger lineCount = 0;
  [layoutManager enumerateLineFragmentsForGlyphRange:NSMakeRange(0, layoutManager.numberOfGlyphs)
                                          usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *textContainer,
                                                       NSRange glyphRange, BOOL *stop) { lineCount++; }];
  return ceil(MAX(lineCount, 1) * ENRMCodeBlockPerLineHeight(config));
}

// Used only to pick the scroll indicator style for the code pane, so the
// indicator stays visible on dark code block backgrounds without affecting
// any other scroll view.
static BOOL ENRMColorIsDark(RCTUIColor *color)
{
  if (!color) {
    return NO;
  }
  CGFloat r = 0, g = 0, b = 0, a = 0;
#if !TARGET_OS_OSX
  if (![color getRed:&r green:&g blue:&b alpha:&a]) {
    CGFloat white = 0;
    if (![color getWhite:&white alpha:&a]) {
      return NO;
    }
    r = g = b = white;
  }
#else
  NSColor *rgb = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
  if (!rgb) {
    return NO;
  }
  [rgb getRed:&r green:&g blue:&b alpha:&a];
#endif
  return (0.299 * r + 0.587 * g + 0.114 * b) < 0.5;
}

// Scrollable code pane content. Draws the attributed code unwrapped at a
// fixed origin; the hosting ENRMCodeBlockContainerView draws everything else.
//
// The TextKit stack (storage/layout manager/container) is built and laid out
// once, when attributedCode is set, then cached: drawing only paints the
// already-computed glyphs, so scrolling and redraws never re-lay-out. This is
// the same rendering path drawAtPoint used internally, so output is identical,
// but the layout is no longer thrown away on every draw. The container is
// unbounded (lines never wrap) with zero line-fragment padding and font leading
// disabled, matching the NSStringDrawing origin the block used before. A
// positive wrapWidth bounds it instead, so lines wrap at that width.
//
// On iOS the view does not draw itself: one bitmap for its bounds would be as
// wide as the longest line and as tall as the whole block. An ENRMTileCanvas
// draws only the part near the screen: vertically near the document's visible
// area (ENRMVisibleAreaFollower), horizontally near what the pane's scroll view
// shows. macOS draws in the view itself.
@interface ENRMCodeBlockContentView : RCTUIView
@property (nonatomic, strong, nullable) NSAttributedString *attributedCode;
@property (nonatomic, assign) CGPoint textOrigin;
@property (nonatomic, assign) CGFloat wrapWidth;
// Laid-out content width, for the horizontal scroll extent. Free once the
// cached stack exists; no separate measurement pass.
@property (nonatomic, readonly) CGFloat usedWidth;
#if TARGET_OS_OSX
@property (nonatomic, copy, nullable) NSMenu * (^menuProvider)(void);
#endif
@end

#if !TARGET_OS_OSX
@interface ENRMCodeBlockContentView () <ENRMVisibleAreaFollower, ENRMTileCanvasDrawing>
@end

// A horizontal fling reaches tiles beyond the pane; drawn ahead of it, they draw over several frames.
static const CGFloat kENRMCodePaneHorizontalMargin = 128;
#endif

// Glyphs can reach past their line (a tight codeBlockLineHeight, an emoji): a
// tile looks this far beyond its rect for the lines to draw, and an edit
// redraws from this far above it, as ENRMTextTiles does.
static const CGFloat kENRMCodeOverdraw = 64;

@implementation ENRMCodeBlockContentView {
  NSTextStorage *_textStorage;
  NSLayoutManager *_layoutManager;
  NSTextContainer *_textContainer;
#if !TARGET_OS_OSX
  ENRMTileCanvas *_canvas;
  // Followed without a document's area.
  ENRMVisibleArea *_ownArea;
#endif
}

#if TARGET_OS_OSX
- (BOOL)isFlipped
{
  return YES;
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
  return self.menuProvider ? self.menuProvider() : [super menuForEvent:event];
}
#else
@synthesize visibleArea = _visibleArea;

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    _canvas = [[ENRMTileCanvas alloc] initWithFrame:self.bounds];
    _canvas.drawer = self;
    [self addSubview:_canvas];
  }
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _canvas.frame = self.bounds;
  [self updateViewport];
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];
  // Off a window nothing is drawn; back on one, the part on screen is drawn again.
  [self updateViewport];
}

// The part of this view the scroll views above it show, vertically (ENRMVisibleArea).
- (CGRect)visibleRectInSelf
{
  ENRMVisibleArea *area = _visibleArea;
  if (area != nil) {
    _ownArea = nil;
    return [area visibleRectInView:self];
  }
  if (_ownArea == nil) {
    // Its scroll views include the pane's own, which shows the pane's whole
    // height and moves with a horizontal scroll: both are what this follows.
    __weak ENRMCodeBlockContentView *weakSelf = self;
    _ownArea = [[ENRMVisibleArea alloc] initWithView:self onChange:^{ [weakSelf updateViewport]; }];
  }
  return [_ownArea visibleRect];
}

- (void)updateViewport
{
  // Read first: it stops observing the scroll views once this view left the window.
  CGRect visible = [self visibleRectInSelf];
  CGRect bounds = self.bounds;
  UIWindow *window = self.window;
  if (window == nil || CGRectIsNull(visible) || CGRectIsEmpty(visible) || CGRectIsEmpty(bounds)) {
    _canvas.drawnRect = CGRectNull;
    return;
  }
  // No scroll view above (infinite): nothing says when another part comes
  // into view, so all of it is drawn, as a text's viewport does.
  CGFloat top = CGRectIsInfinite(visible) ? 0 : CGRectGetMinY(visible) - ENRMVisibleAreaMargin;
  CGFloat bottom = CGRectIsInfinite(visible) ? bounds.size.height : CGRectGetMaxY(visible) + ENRMVisibleAreaMargin;
  // Horizontally, what the pane's own scroll view shows.
  UIView *scrollView = self.superview;
  CGRect shown = scrollView != nil ? [self convertRect:scrollView.bounds fromView:scrollView] : bounds;
  CGFloat left = CGRectGetMinX(shown) - kENRMCodePaneHorizontalMargin;
  CGFloat right = CGRectGetMaxX(shown) + kENRMCodePaneHorizontalMargin;
  _canvas.drawnRect = CGRectIntersection(CGRectMake(left, top, right - left, bottom - top), bounds);
}
#endif

- (void)setAttributedCode:(nullable NSAttributedString *)attributedCode
{
#if !TARGET_OS_OSX
  NSAttributedString *previous = _attributedCode;
  CGFloat previousLastLineY = [self lastLineY];
#endif
  _attributedCode = attributedCode;
  if (attributedCode.length == 0) {
    _textStorage = nil;
    _layoutManager = nil;
    _textContainer = nil;
  } else {
    _textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedCode];
    _layoutManager = [[NSLayoutManager alloc] init];
    _layoutManager.usesFontLeading = ENRMLayoutManagerUsesFontLeading;
    _textContainer = [[NSTextContainer alloc] initWithSize:[self containerSize]];
    _textContainer.lineFragmentPadding = 0;
    _textContainer.maximumNumberOfLines = 0;
    [_layoutManager addTextContainer:_textContainer];
    [_textStorage addLayoutManager:_layoutManager];
    [_layoutManager ensureLayoutForTextContainer:_textContainer];
  }
#if !TARGET_OS_OSX
  [self setCodeNeedsDisplayAfterChangeFrom:previous lastLineY:previousLastLineY];
#endif
}

#if !TARGET_OS_OSX
// Where the last line starts, in the container's space; -1 with no code.
- (CGFloat)lastLineY
{
  NSUInteger length = _textStorage.length;
  if (_layoutManager == nil || length == 0) {
    return -1;
  }
  NSUInteger glyph = [_layoutManager glyphIndexForCharacterAtIndex:length - 1];
  return CGRectGetMinY([_layoutManager lineFragmentRectForGlyphAtIndex:glyph effectiveRange:NULL]);
}

// A streaming block grows at its end: only the tiles from the previous last
// line down change. That line is found in the previous layout: wrapped, the
// appended text can move its unfinished last word to a new line. Anything else
// (highlighting once the block closes, a different block) redraws every tile.
- (void)setCodeNeedsDisplayAfterChangeFrom:(nullable NSAttributedString *)previous lastLineY:(CGFloat)lastLineY
{
  NSAttributedString *code = _attributedCode;
  NSUInteger kept = previous.length;
  BOOL appended = kept > 0 && lastLineY >= 0 && code.length >= kept &&
                  [[code attributedSubstringFromRange:NSMakeRange(0, kept)] isEqualToAttributedString:previous];
  if (!appended) {
    [_canvas setTilesNeedDisplay];
    return;
  }
  if (code.length > kept) {
    [_canvas setTilesNeedDisplayFromY:lastLineY + _textOrigin.y - kENRMCodeOverdraw];
  }
}

- (void)setTextOrigin:(CGPoint)textOrigin
{
  if (CGPointEqualToPoint(_textOrigin, textOrigin)) {
    return;
  }
  _textOrigin = textOrigin;
  [_canvas setTilesNeedDisplay];
}
#endif

- (CGSize)containerSize
{
  return CGSizeMake(_wrapWidth > 0 ? _wrapWidth : CGFLOAT_MAX, CGFLOAT_MAX);
}

- (void)setWrapWidth:(CGFloat)wrapWidth
{
  if (_wrapWidth == wrapWidth) {
    return;
  }
  _wrapWidth = wrapWidth;
  if (_textContainer) {
    _textContainer.size = [self containerSize];
    [_layoutManager ensureLayoutForTextContainer:_textContainer];
  }
#if !TARGET_OS_OSX
  [_canvas setTilesNeedDisplay];
#else
  [self setNeedsDisplay:YES];
#endif
}

- (CGFloat)usedWidth
{
  if (!_layoutManager) {
    return 0;
  }
  return ceil([_layoutManager usedRectForTextContainer:_textContainer].size.width);
}

// Paints only the glyphs intersecting `rect`; tall blocks skip their
// off-screen lines. The rect is in view space, the layout in container space.
- (void)drawCodeInRect:(CGRect)rect
{
  if (!_layoutManager) {
    return;
  }
  CGRect boundingRect = CGRectOffset(CGRectInset(rect, 0, -kENRMCodeOverdraw), -self.textOrigin.x, -self.textOrigin.y);
  NSRange glyphRange = [_layoutManager glyphRangeForBoundingRect:boundingRect inTextContainer:_textContainer];
  [_layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:self.textOrigin];
}

#if TARGET_OS_OSX
- (void)drawRect:(CGRect)rect
{
  [self drawCodeInRect:rect];
}
#else
- (void)drawTileCanvasContentInRect:(CGRect)rect
{
  [self drawCodeInRect:rect];
}
#endif

@end

#if !TARGET_OS_OSX
// The language name in the header. Its own small view, so the container needs
// no bitmap: the box is drawn by the container's layer.
@interface ENRMCodeBlockHeaderLabelView : UIView <ENRMDroppableContent>
@property (nonatomic, strong, nullable) NSAttributedString *label;
@end

@implementation ENRMCodeBlockHeaderLabelView

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}

- (void)setLabel:(nullable NSAttributedString *)label
{
  _label = label;
  [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
  // A long name is cut short with an ellipsis.
  [_label drawWithRect:self.bounds
               options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine
               context:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];
  if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
    [self setNeedsDisplay];
  }
}

@end
#endif

#if !TARGET_OS_OSX
@interface ENRMCodeBlockContainerView () <UIContextMenuInteractionDelegate, UIGestureRecognizerDelegate,
                                          UIScrollViewDelegate>
@end
#endif

@implementation ENRMCodeBlockContainerView {
  NSAttributedString *_attributedCode;
  NSString *_cachedCode;
  NSString *_cachedLanguage;
  NSString *_displayLanguage;
  NSString *_fenceChar;
  ENRMHorizontalScrollView *_scrollView;
  ENRMCodeBlockContentView *_codeContentView;
  CGSize _codeSize;
  CGFloat _headerLabelLineHeight;
  NSAttributedString *_languageLabel;
  CGSize _languageLabelSize;
  // Wrapped code height, valid for _wrappedHeightWidth until the code changes.
  CGFloat _wrappedHeight;
  CGFloat _wrappedHeightWidth;
#if !TARGET_OS_OSX
  UIFont *_headerFont;
  UIButton *_copyButton;
  UIButton *_wrapButton;
  UITapGestureRecognizer *_tapRecognizer;
  UIView *_fillView;
  ENRMCodeBlockHeaderLabelView *_labelView;
  UIView *_dividerView;
#else
  NSFont *_headerFont;
  NSButton *_copyButton;
#endif
}

- (void)setPending:(BOOL)pending
{
  if (_pending == pending) {
    return;
  }
  _pending = pending;
  // Header stays visible while streaming; only copying is held back.
  _copyButton.enabled = !pending;
  // The reconciler can reuse an unchanged block without re-applying the node, so
  // re-derive here to pick up highlighting once the block closes.
  [self rebuildAttributedCode];
#if !TARGET_OS_OSX
  // The code pane redraws what the new code changed itself.
  [self setNeedsLayout];
#else
  self.needsLayout = YES;
  [self setNeedsDisplay:YES];
  [_codeContentView setNeedsDisplay:YES];
#endif
}

- (instancetype)initWithConfig:(StyleConfig *)config
{
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _config = config;
    _cachedCode = @"";
    _fenceChar = @"`";
    _wrappedHeightWidth = -1;
    _dynamicProps = [[ENRMDynamicBlockProps alloc] init];
    _headerFont = ENRMCodeBlockHeaderFont(config);
    _headerLabelLineHeight = ENRMCodeBlockHeaderLabelLineHeight(_headerFont);
    self.backgroundColor = [RCTUIColor clearColor];
    [self setupScrollView];

#if !TARGET_OS_OSX
    self.isAccessibilityElement = YES;
    [self setupBox];

    UIContextMenuInteraction *contextMenu = [[UIContextMenuInteraction alloc] initWithDelegate:self];
    [self addInteraction:contextMenu];

    _copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *symbolConfig = ENRMCodeBlockHeaderSymbolConfiguration(config);
    [_copyButton setImage:[UIImage systemImageNamed:@"doc.on.doc" withConfiguration:symbolConfig]
                 forState:UIControlStateNormal];
    _copyButton.tintColor = [[config codeBlockColor] colorWithAlphaComponent:kENRMHeaderSecondaryAlpha];
    [_copyButton addTarget:self action:@selector(copyCodeToPasteboard) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_copyButton];

    _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleCodeBlockTap:)];
    _tapRecognizer.delegate = self;
    [self addGestureRecognizer:_tapRecognizer];
#else
    NSImageSymbolConfiguration *symbolConfig =
        [NSImageSymbolConfiguration configurationWithPointSize:[config codeBlockFont].pointSize * kENRMHeaderIconScale
                                                        weight:NSFontWeightRegular];
    NSImage *copyImage = [[NSImage imageWithSystemSymbolName:@"doc.on.doc"
                                    accessibilityDescription:nil] imageWithSymbolConfiguration:symbolConfig];
    _copyButton = [NSButton buttonWithImage:copyImage target:self action:@selector(copyCodeToPasteboard)];
    _copyButton.bordered = NO;
    _copyButton.contentTintColor = [[config codeBlockColor] colorWithAlphaComponent:kENRMHeaderSecondaryAlpha];
    [self addSubview:_copyButton];
#endif
  }
  return self;
}

- (void)setupScrollView
{
  _scrollView = [[ENRMHorizontalScrollView alloc] init];
  _scrollView.showsVerticalScrollIndicator = NO;
  _scrollView.showsHorizontalScrollIndicator = YES;
  _codeContentView = [[ENRMCodeBlockContentView alloc] initWithFrame:CGRectZero];
  BOOL darkBackground = ENRMColorIsDark([_config codeBlockBackgroundColor]);
#if !TARGET_OS_OSX
  _scrollView.alwaysBounceHorizontal = NO;
  _scrollView.backgroundColor = [UIColor clearColor];
  _scrollView.isAccessibilityElement = NO;
  _scrollView.accessibilityElementsHidden = YES;
  _scrollView.indicatorStyle = darkBackground ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleDefault;
  _codeContentView.backgroundColor = [UIColor clearColor];
  // A horizontal scroll moves the drawn part of the code.
  _scrollView.delegate = self;
  [_scrollView addSubview:_codeContentView];
  [_codeContentView addInteraction:[[UIContextMenuInteraction alloc] initWithDelegate:self]];
#else
  ((NSScrollView *)_scrollView).drawsBackground = NO;
  ((NSScrollView *)_scrollView).scrollerKnobStyle =
      darkBackground ? NSScrollerKnobStyleLight : NSScrollerKnobStyleDefault;
  __weak ENRMCodeBlockContainerView *weakSelf = self;
  NSMenu * (^menuProvider)(void) = ^{ return [weakSelf buildContextMenu]; };
  _codeContentView.menuProvider = menuProvider;
  [(NSScrollView *)_scrollView setDocumentView:_codeContentView];
#endif
  [self addSubview:_scrollView];
}

#if !TARGET_OS_OSX
// The box as the macOS drawRect: draws it, with no bitmap. drawRect: fills a
// rounded rect inset by half the border width, then strokes its outline with
// the border width: the fill is a view of that rect, and the stroke a layer
// border inside the bounds whose outer corner radius is half the border width
// larger.
- (void)setupBox
{
  _fillView = [[UIView alloc] init];
  _fillView.userInteractionEnabled = NO;
  [self insertSubview:_fillView atIndex:0];

  _dividerView = [[UIView alloc] init];
  _dividerView.userInteractionEnabled = NO;
  // Under the code, as drawRect: draws them.
  [self insertSubview:_dividerView belowSubview:_scrollView];

  _labelView = [[ENRMCodeBlockHeaderLabelView alloc] init];
  [self insertSubview:_labelView belowSubview:_scrollView];
  [self applyBoxAppearance];
}

// From _config at every layout, as drawRect: drew it: the document reuses this block when new
// markdown comes with a markdownStyle change, which updates the config it shares in place.
// UIBezierPath's rounded rect, which drawRect: used, has continuous corners.
- (void)applyBoxAppearance
{
  CGFloat borderWidth = [_config codeBlockBorderWidth];
  CGFloat radius = [_config codeBlockBorderRadius];
  self.layer.cornerRadius = radius > 0 ? radius + borderWidth / 2 : 0;
  self.layer.cornerCurve = kCACornerCurveContinuous;
  self.layer.borderWidth = [_config codeBlockBorderColor] ? borderWidth : 0;
  [self applyBorderColor];
  _fillView.backgroundColor = [_config codeBlockBackgroundColor];
  _fillView.layer.cornerRadius = radius;
  _fillView.layer.cornerCurve = kCACornerCurveContinuous;
  _dividerView.backgroundColor = [[_config codeBlockColor] colorWithAlphaComponent:kENRMHeaderDividerAlpha];
}

// A layer takes a resolved color: resolved again when the appearance changes.
- (void)applyBorderColor
{
  self.layer.borderColor =
      [[_config codeBlockBorderColor] resolvedColorWithTraitCollection:self.traitCollection].CGColor;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];
  if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
    [self applyBorderColor];
  }
}

- (void)layoutBox
{
  [self applyBoxAppearance];
  CGFloat borderWidth = [_config codeBlockBorderWidth];
  CGFloat inset = [self contentInset];
  CGFloat headerH = [self headerHeight];
  _fillView.frame = CGRectInset(self.bounds, borderWidth / 2, borderWidth / 2);
  // Divider between the header and the code, centered in the gap the code
  // text's top inset creates, so it adds no height of its own.
  _dividerView.frame =
      CGRectMake(borderWidth, headerH + inset / 2, MAX(self.bounds.size.width - borderWidth * 2, 0), 1);
  _labelView.hidden = _languageLabel.length == 0;
  _labelView.frame = [self languageLabelRect];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  [_codeContentView updateViewport];
}

- (void)updateViewportInVisibleArea:(ENRMVisibleArea *)area
{
  _codeContentView.visibleArea = area;
  [_codeContentView updateViewport];
}
#endif

// Where the language label draws. Keeps clear of the header buttons, as
// Android caps its label view; a long name is cut short with an ellipsis.
- (CGRect)languageLabelRect
{
  CGFloat inset = [self contentInset];
  CGFloat headerH = [self headerHeight];
  CGFloat headerButtonsWidth = _showsWrapButton ? headerH * 2 : headerH;
  CGFloat labelMaxWidth = MAX(self.bounds.size.width - inset * 2 - headerButtonsWidth, 0);
  return CGRectMake(inset, [self headerCenterY] - _languageLabelSize.height / 2,
                    MIN(_languageLabelSize.width, labelMaxWidth), _languageLabelSize.height);
}

- (void)layoutScrollArea
{
  CGFloat borderW = ceil([_config codeBlockBorderWidth]);
  CGFloat headerH = [self headerHeight];
  CGFloat inset = [self contentInset];
  CGRect frame = CGRectMake(borderW, headerH, MAX(self.bounds.size.width - borderW * 2, 0),
                            MAX(self.bounds.size.height - headerH - borderW, 0));
  _scrollView.frame = frame;

  CGFloat horizontalPad = MAX(inset - borderW, 0);
  _codeContentView.wrapWidth = _wrapped ? MAX(ENRMCodeBlockWrapWidth(self.bounds.size.width, _config), 1) : 0;
  CGFloat codeWidth = _wrapped ? 0 : _codeSize.width;
  CGFloat contentWidth = MAX(codeWidth + horizontalPad * 2, frame.size.width);
  _codeContentView.textOrigin = CGPointMake(horizontalPad, inset);
  _codeContentView.frame = CGRectMake(0, 0, contentWidth, frame.size.height);
#if !TARGET_OS_OSX
  _scrollView.contentSize = CGSizeMake(contentWidth, frame.size.height);
  _scrollView.scrollEnabled = contentWidth > frame.size.width;
  if (_wrapped) {
    _scrollView.contentOffset = CGPointZero;
  }
  // The pane may have changed width alone (a rotation), which lays out
  // nothing in it.
  [_codeContentView updateViewport];
#endif
}

// The code pane starts after the content inset and one header-label line.
- (CGFloat)headerHeight
{
  return [self contentInset] + _headerLabelLineHeight;
}

- (CGFloat)headerCenterY
{
  // The divider sits halfway into the code pane's top inset.
  return ([self headerHeight] + [self contentInset] / 2) / 2;
}

- (void)layoutHeaderButton
{
  CGFloat headerH = [self headerHeight];
  CGFloat iconWidth = _copyButton.intrinsicContentSize.width;
  if (iconWidth <= 0 || iconWidth > headerH) {
    iconWidth = headerH;
  }
  CGFloat iconSlack = (headerH - iconWidth) / 2;
  CGFloat buttonLeft = MAX(self.bounds.size.width - [self contentInset] - headerH + iconSlack, 0);
  CGFloat buttonTop = MAX([self headerCenterY] - headerH / 2, 0);
  _copyButton.frame = CGRectMake(buttonLeft, buttonTop, headerH, headerH);
#if !TARGET_OS_OSX
  _wrapButton.frame = CGRectMake(MAX(buttonLeft - headerH, 0), buttonTop, headerH, headerH);
#endif
}

#if !TARGET_OS_OSX
- (void)setShowsWrapButton:(BOOL)showsWrapButton
{
  if (_showsWrapButton == showsWrapButton) {
    return;
  }
  _showsWrapButton = showsWrapButton;
  if (showsWrapButton && !_wrapButton) {
    _wrapButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_wrapButton setImage:[UIImage systemImageNamed:@"text.alignleft"
                                  withConfiguration:ENRMCodeBlockHeaderSymbolConfiguration(_config)]
                 forState:UIControlStateNormal];
    [_wrapButton addTarget:self action:@selector(toggleWrap) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_wrapButton];
    [self updateWrapButtonAppearance];
  }
  _wrapButton.hidden = !showsWrapButton;
  // The language label's room shrinks by one button.
  [self setNeedsLayout];
}

- (void)updateWrapButtonAppearance
{
  // Full-strength tint marks the toggle as on; off matches the copy button.
  CGFloat alpha = _wrapped ? 1 : kENRMHeaderSecondaryAlpha;
  _wrapButton.tintColor = [[_config codeBlockColor] colorWithAlphaComponent:alpha];
  _wrapButton.accessibilityLabel = [self wrapActionLabel];
}
#endif

- (NSString *)wrapActionLabel
{
  return _wrapped ? _accessibilityLabels.codeBlockUnwrap : _accessibilityLabels.codeBlockWrap;
}

- (void)setAccessibilityLabels:(ENRMAccessibilityLabels *)labels
{
  if (_accessibilityLabels == labels) {
    return;
  }
  _accessibilityLabels = labels;
#if !TARGET_OS_OSX
  [self updateWrapButtonAppearance];
#endif
}

- (void)setWrapped:(BOOL)wrapped
{
  if (_wrapped == wrapped) {
    return;
  }
  _wrapped = wrapped;
  if (!wrapped) {
    // Restore the unwrapped width for the scroll extent; a rebuild while
    // wrapped measured at the wrap width.
    _codeContentView.wrapWidth = 0;
    _codeSize.width = _codeContentView.usedWidth;
  }
#if !TARGET_OS_OSX
  // Laying out sets the pane's wrap width, which redraws it.
  [self updateWrapButtonAppearance];
  [self setNeedsLayout];
#else
  self.needsLayout = YES;
  [_codeContentView setNeedsDisplay:YES];
#endif
}

- (void)toggleWrap
{
  if (self.onWrapToggle) {
    self.onWrapToggle(self);
  }
}

#if !TARGET_OS_OSX
- (void)layoutSubviews
{
  [super layoutSubviews];
  [self layoutHeaderButton];
  [self layoutBox];
  [self layoutScrollArea];
}
#else
- (void)layout
{
  [super layout];
  [self layoutHeaderButton];
  [self layoutScrollArea];
}
#endif

#if TARGET_OS_OSX
- (BOOL)isFlipped
{
  return YES;
}

- (void)setFrameSize:(NSSize)newSize
{
  [super setFrameSize:newSize];
  [self setNeedsDisplay:YES];
}
#endif

// Highlighting is deferred while pending, applied once the block closes.
- (void)rebuildAttributedCode
{
  NSAttributedString *plainCode = [self plainAttributedCode];
  NSAttributedString *highlighted =
      _pending ? nil : ENRMHighlightedAttributedCode(plainCode, _cachedCode, _cachedLanguage, _config);
  _attributedCode = highlighted ?: plainCode;
  // Setting attributedCode builds and lays out the cached TextKit stack once;
  // width then reads out of that layout, and height stays analytic.
  _codeContentView.attributedCode = _attributedCode;
  _codeSize = CGSizeMake(_codeContentView.usedWidth, ENRMCodeBlockCodeHeight(_cachedCode, _config));
  _wrappedHeightWidth = -1;
}

- (void)applyCodeBlockNode:(MarkdownASTNode *)node
{
  _cachedCode = ENRMCodeBlockExtractCode(node);
  _fenceChar = ENRMCodeBlockFenceChar(node);

  NSString *newLanguage = ENRMCodeBlockLanguage(node);
  BOOL languageChanged = newLanguage != _cachedLanguage && ![newLanguage isEqualToString:_cachedLanguage];
  if (languageChanged) {
    _cachedLanguage = newLanguage;
    _displayLanguage = ENRMCodeBlockDisplayLanguageName(newLanguage);
    [self rebuildLanguageLabel];
  }

  [self rebuildAttributedCode];

  // iOS VoiceOver reads the copy label live via accessibilityCustomActions and the
  // button is hidden behind the container's single a11y element, so its own label
  // is consumed only on macOS; refresh it there on each content update.
#if TARGET_OS_OSX
  _copyButton.accessibilityLabel = self.dynamicProps.menuCopyLabel;
#endif

#if !TARGET_OS_OSX
  // The code pane redraws what the new code changed itself.
  [self setNeedsLayout];
#else
  self.needsLayout = YES;
  [self setNeedsDisplay:YES];
  [_codeContentView setNeedsDisplay:YES];
#endif
}

- (void)rebuildLanguageLabel
{
#if !TARGET_OS_OSX
  // Laid out with the header.
  [self setNeedsLayout];
#endif
  if (_displayLanguage.length == 0) {
    _languageLabel = nil;
    _languageLabelSize = CGSizeZero;
#if !TARGET_OS_OSX
    _labelView.label = nil;
#endif
    return;
  }
  NSMutableDictionary *labelAttributes = [NSMutableDictionary dictionary];
  labelAttributes[NSFontAttributeName] = _headerFont;
  RCTUIColor *labelColor = [[_config codeBlockColor] colorWithAlphaComponent:kENRMHeaderSecondaryAlpha];
  if (labelColor) {
    labelAttributes[NSForegroundColorAttributeName] = labelColor;
  }
  _languageLabel = [[NSAttributedString alloc] initWithString:_displayLanguage attributes:labelAttributes];
  _languageLabelSize = _languageLabel.size;
#if !TARGET_OS_OSX
  _labelView.label = _languageLabel;
#endif
}

- (NSAttributedString *)plainAttributedCode
{
  return ENRMCodeBlockPlainAttributedCode(_cachedCode, _config);
}

- (CGFloat)contentInset
{
  return ENRMCodeBlockContentInset(_config);
}

- (CGFloat)measureHeight:(CGFloat)maxWidth
{
  CGFloat inset = [self contentInset];
  CGFloat codeHeight = _codeSize.height;
  if (_wrapped) {
    if (_wrappedHeightWidth != maxWidth) {
      _wrappedHeight = ENRMCodeBlockWrappedCodeHeight([self plainAttributedCode],
                                                      MAX(ENRMCodeBlockWrapWidth(maxWidth, _config), 1), _config);
      _wrappedHeightWidth = maxWidth;
    }
    codeHeight = _wrappedHeight;
  }
  return codeHeight + inset * 2 + [self headerHeight];
}

+ (CGFloat)measureHeightForCodeBlockNode:(MarkdownASTNode *)node config:(StyleConfig *)config
{
  CGFloat inset = ENRMCodeBlockContentInset(config);
  CGFloat headerH = inset + ENRMCodeBlockHeaderLabelLineHeight(ENRMCodeBlockHeaderFont(config));
  CGFloat codeHeight = ENRMCodeBlockCodeHeight(ENRMCodeBlockExtractCode(node), config);
  return codeHeight + inset * 2 + headerH;
}

+ (CGFloat)measureWrappedHeightForCodeBlockNode:(MarkdownASTNode *)node
                                         config:(StyleConfig *)config
                                       maxWidth:(CGFloat)maxWidth
{
  CGFloat inset = ENRMCodeBlockContentInset(config);
  CGFloat headerH = inset + ENRMCodeBlockHeaderLabelLineHeight(ENRMCodeBlockHeaderFont(config));
  NSAttributedString *code = ENRMCodeBlockPlainAttributedCode(ENRMCodeBlockExtractCode(node), config);
  CGFloat codeHeight = ENRMCodeBlockWrappedCodeHeight(code, MAX(ENRMCodeBlockWrapWidth(maxWidth, config), 1), config);
  return codeHeight + inset * 2 + headerH;
}

#if TARGET_OS_OSX
- (void)drawRect:(CGRect)rect
{
  CGFloat borderWidth = [_config codeBlockBorderWidth];
  CGFloat radius = [_config codeBlockBorderRadius];
  CGRect borderRect = CGRectInset(self.bounds, borderWidth / 2, borderWidth / 2);
  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:borderRect xRadius:radius yRadius:radius];

  RCTUIColor *backgroundColor = [_config codeBlockBackgroundColor];
  if (backgroundColor) {
    [backgroundColor setFill];
    [path fill];
  }
  if (borderWidth > 0) {
    RCTUIColor *borderColor = [_config codeBlockBorderColor];
    if (borderColor) {
      path.lineWidth = borderWidth;
      [borderColor setStroke];
      [path stroke];
    }
  }

  CGFloat inset = [self contentInset];
  CGFloat headerH = [self headerHeight];

  // Divider between the header and the code, centered in the gap the code
  // text's top inset creates, so it adds no height of its own.
  RCTUIColor *dividerColor = [[_config codeBlockColor] colorWithAlphaComponent:kENRMHeaderDividerAlpha];
  if (dividerColor) {
    CGRect dividerRect = CGRectMake(borderWidth, headerH + inset / 2, self.bounds.size.width - borderWidth * 2, 1);
    [dividerColor setFill];
    [[NSBezierPath bezierPathWithRect:dividerRect] fill];
  }

  if (_languageLabel.length > 0) {
    [_languageLabel drawWithRect:[self languageLabelRect]
                         options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine
                         context:nil];
  }
}
#endif

- (NSString *)fencedMarkdown
{
  return ENRMCodeBlockFencedMarkdown(_cachedCode, _cachedLanguage, _fenceChar);
}

- (void)copyCodeToPasteboard
{
  copyStringToPasteboard(_cachedCode);
  if (self.onCopyPress) {
    self.onCopyPress(_cachedCode ?: @"", _cachedLanguage ?: @"");
  }
}

- (void)copyMarkdownToPasteboard
{
  copyStringToPasteboard([self fencedMarkdown]);
}

#if !TARGET_OS_OSX
- (void)handleCodeBlockTap:(UITapGestureRecognizer *)recognizer
{
  if (!self.dynamicProps.enableCodeBlockPress || _pending) {
    return;
  }
  if (self.onCodeBlockPress) {
    self.onCodeBlockPress(_cachedCode ?: @"", _cachedLanguage ?: @"");
  }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer == _tapRecognizer) {
    return self.dynamicProps.enableCodeBlockPress && !_pending;
  }
  return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
  // Let the header buttons handle their own taps.
  for (UIView *hit = touch.view; hit != nil; hit = hit.superview) {
    if (hit == _copyButton || (_wrapButton != nil && hit == _wrapButton)) {
      return NO;
    }
  }
  return YES;
}
#endif

#if !TARGET_OS_OSX
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        configurationForMenuAtLocation:(CGPoint)location
{
  if (!self.dynamicProps.enableBlockContextMenu || _pending) {
    return nil;
  }
  return [UIContextMenuConfiguration
      configurationWithIdentifier:nil
                  previewProvider:nil
                   actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
                     UIAction *copyCode =
                         [UIAction actionWithTitle:self.dynamicProps.menuCopyLabel
                                             image:[RCTUIImage systemImageNamed:@"doc.on.doc"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *action) { [self copyCodeToPasteboard]; }];

                     UIAction *copyMarkdown =
                         [UIAction actionWithTitle:self.dynamicProps.menuCopyAsMarkdownLabel
                                             image:[RCTUIImage systemImageNamed:@"doc.text"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *action) { [self copyMarkdownToPasteboard]; }];

                     return [UIMenu menuWithTitle:@"" children:@[ copyCode, copyMarkdown ]];
                   }];
}
#endif

#if TARGET_OS_OSX
- (NSMenu *)buildContextMenu
{
  if (!self.dynamicProps.enableBlockContextMenu || _pending) {
    return nil;
  }
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
  [menu addItem:ENRMCreateMenuItem(self.dynamicProps.menuCopyLabel, ^{ [self copyCodeToPasteboard]; })];
  [menu addItem:ENRMCreateMenuItem(self.dynamicProps.menuCopyAsMarkdownLabel, ^{ [self copyMarkdownToPasteboard]; })];
  return menu;
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
  return [self buildContextMenu];
}
#endif

- (NSString *)accessibilityLabel
{
  return _cachedCode;
}

#if !TARGET_OS_OSX
- (UIAccessibilityTraits)accessibilityTraits
{
  return UIAccessibilityTraitStaticText;
}

// The container is a single accessibility element, which hides the header
// button subviews from VoiceOver; expose their actions explicitly instead.
- (NSArray<UIAccessibilityCustomAction *> *)accessibilityCustomActions
{
  NSMutableArray<UIAccessibilityCustomAction *> *actions = [NSMutableArray array];
  if (!_pending && self.dynamicProps.menuCopyLabel.length > 0) {
    [actions addObject:[[UIAccessibilityCustomAction alloc] initWithName:self.dynamicProps.menuCopyLabel
                                                                  target:self
                                                                selector:@selector(performCopyAccessibilityAction:)]];
  }
  if (_showsWrapButton && [self wrapActionLabel].length > 0) {
    [actions addObject:[[UIAccessibilityCustomAction alloc] initWithName:[self wrapActionLabel]
                                                                  target:self
                                                                selector:@selector(performWrapAccessibilityAction:)]];
  }
  return actions;
}

- (BOOL)performCopyAccessibilityAction:(UIAccessibilityCustomAction *)action
{
  [self copyCodeToPasteboard];
  return YES;
}

- (BOOL)performWrapAccessibilityAction:(UIAccessibilityCustomAction *)action
{
  [self toggleWrap];
  return YES;
}
#endif

@end
