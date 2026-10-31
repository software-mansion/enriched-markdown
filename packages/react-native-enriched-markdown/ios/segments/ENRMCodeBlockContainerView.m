#import "ENRMCodeBlockContainerView.h"
#import "ENRMAccessibilityLabels.h"
#import "ENRMCodeBlockContent.h"
#import "ENRMCodeBlockHighlighter.h"
#import "ENRMHorizontalScrollView.h"
#import "MarkdownASTNode.h"
#import "PasteboardUtils.h"
#if TARGET_OS_OSX
#import "ENRMMenuAction.h"
#endif

// Block segment view for fenced code blocks (see SegmentRenderer.m):
// a fixed header bar (language name, copy button) above a horizontally
// scrolling, non-wrapping code pane. The container's drawRect: draws
// background, border, label, and divider; only the copy button and the
// scroll view are subviews. Syntax coloring comes from the
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
static NSString *const kENRMCopySymbolName = @"doc.on.doc";
static NSString *const kENRMCopiedSymbolName = @"checkmark";
static const NSTimeInterval kENRMCopyFeedbackDuration = 1.5;

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

static NSImage *ENRMCodeBlockHeaderSymbol(NSString *symbolName, StyleConfig *config)
{
  NSImageSymbolConfiguration *symbolConfig =
      [NSImageSymbolConfiguration configurationWithPointSize:[config codeBlockFont].pointSize * kENRMHeaderIconScale
                                                      weight:NSFontWeightRegular];
  return [[NSImage imageWithSystemSymbolName:symbolName
                    accessibilityDescription:nil] imageWithSymbolConfiguration:symbolConfig];
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
// once, when attributedCode is set, then cached: drawRect: only paints the
// already-computed glyphs, so scrolling and redraws never re-lay-out. This is
// the same rendering path drawAtPoint used internally, so output is identical,
// but the layout is no longer thrown away on every draw. The container is
// unbounded (lines never wrap) with zero line-fragment padding and font leading
// disabled, matching the NSStringDrawing origin the block used before. A
// positive wrapWidth bounds it instead, so lines wrap at that width.
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

@implementation ENRMCodeBlockContentView {
  NSTextStorage *_textStorage;
  NSLayoutManager *_layoutManager;
  NSTextContainer *_textContainer;
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
#endif

- (void)setAttributedCode:(nullable NSAttributedString *)attributedCode
{
  _attributedCode = attributedCode;
  if (attributedCode.length == 0) {
    _textStorage = nil;
    _layoutManager = nil;
    _textContainer = nil;
    return;
  }
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
  [self setNeedsDisplay];
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

- (void)drawRect:(CGRect)rect
{
  if (!_layoutManager) {
    return;
  }
  // Only paint the glyphs intersecting the dirty rect; tall blocks skip their
  // off-screen lines. The rect is in view space, the layout in container space.
  CGRect boundingRect = CGRectOffset(rect, -self.textOrigin.x, -self.textOrigin.y);
  NSRange glyphRange = [_layoutManager glyphRangeForBoundingRect:boundingRect inTextContainer:_textContainer];
  [_layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:self.textOrigin];
}

@end

#if !TARGET_OS_OSX
@interface ENRMCodeBlockContainerView () <UIContextMenuInteractionDelegate, UIGestureRecognizerDelegate>
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
#else
  NSFont *_headerFont;
  NSButton *_copyButton;
#endif
  BOOL _showingCopyFeedback;
  // Bumped on every show and reset so a stale restore timer does nothing.
  NSUInteger _copyFeedbackGeneration;
}

- (void)setPending:(BOOL)pending
{
  if (_pending == pending) {
    return;
  }
  _pending = pending;
  // Header stays visible while streaming; only copying is held back.
  _copyButton.enabled = !pending;
  if (pending) {
    [self resetCopyFeedback];
  }
  // The reconciler can reuse an unchanged block without re-applying the node, so
  // re-derive here to pick up highlighting once the block closes.
  [self rebuildAttributedCode];
#if !TARGET_OS_OSX
  [self setNeedsLayout];
  [self setNeedsDisplay];
  [_codeContentView setNeedsDisplay];
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
    self.contentMode = UIViewContentModeRedraw;
    self.isAccessibilityElement = YES;

    UIContextMenuInteraction *contextMenu = [[UIContextMenuInteraction alloc] initWithDelegate:self];
    [self addInteraction:contextMenu];

    _copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self setCopyButtonSymbol:kENRMCopySymbolName];
    _copyButton.tintColor = [[config codeBlockColor] colorWithAlphaComponent:kENRMHeaderSecondaryAlpha];
    [_copyButton addTarget:self action:@selector(copyCodeToPasteboard) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_copyButton];

    _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleCodeBlockTap:)];
    _tapRecognizer.delegate = self;
    [self addGestureRecognizer:_tapRecognizer];
#else
    _copyButton = [NSButton buttonWithImage:ENRMCodeBlockHeaderSymbol(kENRMCopySymbolName, config)
                                     target:self
                                     action:@selector(copyCodeToPasteboard)];
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
  _codeContentView.contentMode = UIViewContentModeRedraw;
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
  [self setNeedsLayout];
  // The language label's room shrinks by one button.
  [self setNeedsDisplay];
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
  [self updateWrapButtonAppearance];
  [self setNeedsLayout];
  [_codeContentView setNeedsDisplay];
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
  NSString *newCode = ENRMCodeBlockExtractCode(node);
  NSString *newLanguage = ENRMCodeBlockLanguage(node);
  BOOL languageChanged = newLanguage != _cachedLanguage && ![newLanguage isEqualToString:_cachedLanguage];
  if (languageChanged || ![newCode isEqualToString:_cachedCode]) {
    [self resetCopyFeedback];
  }
  _cachedCode = newCode;
  _fenceChar = ENRMCodeBlockFenceChar(node);

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
  [self setNeedsLayout];
  [self setNeedsDisplay];
  [_codeContentView setNeedsDisplay];
#else
  self.needsLayout = YES;
  [self setNeedsDisplay:YES];
  [_codeContentView setNeedsDisplay:YES];
#endif
}

- (void)rebuildLanguageLabel
{
  if (_displayLanguage.length == 0) {
    _languageLabel = nil;
    _languageLabelSize = CGSizeZero;
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

- (void)drawRect:(CGRect)rect
{
  CGFloat borderWidth = [_config codeBlockBorderWidth];
  CGFloat radius = [_config codeBlockBorderRadius];
  CGRect borderRect = CGRectInset(self.bounds, borderWidth / 2, borderWidth / 2);

#if !TARGET_OS_OSX
  UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:borderRect cornerRadius:radius];
#else
  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:borderRect xRadius:radius yRadius:radius];
#endif

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
#if !TARGET_OS_OSX
    [[UIBezierPath bezierPathWithRect:dividerRect] fill];
#else
    [[NSBezierPath bezierPathWithRect:dividerRect] fill];
#endif
  }

  if (_languageLabel.length > 0) {
    // Keep clear of the header buttons, as Android caps its label view; a long
    // name is cut short with an ellipsis.
    CGFloat headerButtonsWidth = _showsWrapButton ? headerH * 2 : headerH;
    CGFloat labelMaxWidth = MAX(self.bounds.size.width - inset * 2 - headerButtonsWidth, 0);
    CGRect labelRect = CGRectMake(inset, [self headerCenterY] - _languageLabelSize.height / 2,
                                  MIN(_languageLabelSize.width, labelMaxWidth), _languageLabelSize.height);
    [_languageLabel drawWithRect:labelRect
                         options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine
                         context:nil];
  }
}

- (NSString *)fencedMarkdown
{
  return ENRMCodeBlockFencedMarkdown(_cachedCode, _cachedLanguage, _fenceChar);
}

- (void)copyCodeToPasteboard
{
  copyStringToPasteboard(_cachedCode);
  [self showCopyFeedback];
  if (self.onCopyPress) {
    self.onCopyPress(_cachedCode ?: @"", _cachedLanguage ?: @"");
  }
}

- (void)setCopyButtonSymbol:(NSString *)symbolName
{
#if !TARGET_OS_OSX
  [_copyButton setImage:[UIImage systemImageNamed:symbolName
                                withConfiguration:ENRMCodeBlockHeaderSymbolConfiguration(_config)]
               forState:UIControlStateNormal];
#else
  _copyButton.image = ENRMCodeBlockHeaderSymbol(symbolName, _config);
#endif
}

- (void)showCopyFeedback
{
  _showingCopyFeedback = YES;
  NSUInteger generation = ++_copyFeedbackGeneration;
  [self setCopyButtonSymbol:kENRMCopiedSymbolName];
  __weak ENRMCodeBlockContainerView *weakSelf = self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kENRMCopyFeedbackDuration * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{ [weakSelf endCopyFeedback:generation]; });
}

- (void)endCopyFeedback:(NSUInteger)generation
{
  if (generation == _copyFeedbackGeneration) {
    [self resetCopyFeedback];
  }
}

- (void)resetCopyFeedback
{
  if (!_showingCopyFeedback) {
    return;
  }
  _showingCopyFeedback = NO;
  _copyFeedbackGeneration++;
  [self setCopyButtonSymbol:kENRMCopySymbolName];
}

#if !TARGET_OS_OSX
- (void)willMoveToWindow:(UIWindow *)newWindow
{
  [super willMoveToWindow:newWindow];
  if (newWindow == nil) {
    [self resetCopyFeedback];
  }
}
#else
- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
  [super viewWillMoveToWindow:newWindow];
  if (newWindow == nil) {
    [self resetCopyFeedback];
  }
}
#endif

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
