#import "ENRMCodeBlockContainerView.h"
#import "ENRMCodeBlockContent.h"
#import "ENRMCodeBlockHighlighter.h"
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
// header metrics, so the reported height matches the drawn height. Since
// lines never wrap, the height is independent of the available width.

static const CGFloat kENRMHeaderLabelScale = 0.85;
static const CGFloat kENRMHeaderSecondaryAlpha = 0.6;
static const CGFloat kENRMHeaderDividerAlpha = 0.2;

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
@interface ENRMCodeBlockContentView : RCTUIView
@property (nonatomic, strong, nullable) NSAttributedString *attributedCode;
@property (nonatomic, assign) CGPoint textOrigin;
#if TARGET_OS_OSX
@property (nonatomic, copy, nullable) NSMenu * (^menuProvider)(void);
#endif
@end

@implementation ENRMCodeBlockContentView

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

- (void)drawRect:(CGRect)rect
{
  if (self.attributedCode.length > 0) {
    [self.attributedCode drawAtPoint:self.textOrigin];
  }
}

@end

#if !TARGET_OS_OSX
@interface ENRMCodeBlockContainerView () <UIContextMenuInteractionDelegate>
@end
#endif

@implementation ENRMCodeBlockContainerView {
  NSAttributedString *_attributedCode;
  NSString *_cachedCode;
  NSString *_cachedLanguage;
  NSString *_displayLanguage;
  NSString *_fenceChar;
  RCTUIScrollView *_scrollView;
  ENRMCodeBlockContentView *_codeContentView;
  CGSize _codeSize;
  CGFloat _headerLabelLineHeight;
  NSAttributedString *_languageLabel;
  CGSize _languageLabelSize;
#if !TARGET_OS_OSX
  UIFont *_headerFont;
  UIButton *_copyButton;
#else
  NSFont *_headerFont;
  NSButton *_copyButton;
#endif
}

@synthesize copyLabel = _copyLabel;
@synthesize copyAsMarkdownLabel = _copyAsMarkdownLabel;

- (void)setCopyLabel:(NSString *)copyLabel
{
  _copyLabel = [copyLabel copy];
  _copyButton.accessibilityLabel = _copyLabel;
}

- (instancetype)initWithConfig:(StyleConfig *)config
{
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _config = config;
    _cachedCode = @"";
    _fenceChar = @"`";
#if !TARGET_OS_OSX
    _headerFont = [UIFont systemFontOfSize:[config codeBlockFont].pointSize * kENRMHeaderLabelScale
                                    weight:UIFontWeightMedium];
    _headerLabelLineHeight = ceil(_headerFont.lineHeight);
#else
    _headerFont = [NSFont systemFontOfSize:[config codeBlockFont].pointSize * kENRMHeaderLabelScale
                                    weight:NSFontWeightMedium];
    _headerLabelLineHeight = ceil(_headerFont.ascender - _headerFont.descender);
#endif
    self.backgroundColor = [RCTUIColor clearColor];
    [self setupScrollView];

#if !TARGET_OS_OSX
    self.contentMode = UIViewContentModeRedraw;
    self.isAccessibilityElement = YES;

    UIContextMenuInteraction *contextMenu = [[UIContextMenuInteraction alloc] initWithDelegate:self];
    [self addInteraction:contextMenu];

    _copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *symbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:[config codeBlockFont].pointSize * kENRMHeaderLabelScale
                                                        weight:UIImageSymbolWeightMedium];
    [_copyButton setImage:[UIImage systemImageNamed:@"doc.on.doc" withConfiguration:symbolConfig]
                 forState:UIControlStateNormal];
    _copyButton.tintColor = [[config codeBlockColor] colorWithAlphaComponent:kENRMHeaderSecondaryAlpha];
    [_copyButton addTarget:self action:@selector(copyCodeToPasteboard) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_copyButton];
#else
    NSImage *copyImage = [NSImage imageWithSystemSymbolName:@"doc.on.doc" accessibilityDescription:nil];
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
  _scrollView = [[RCTUIScrollView alloc] init];
  _scrollView.showsVerticalScrollIndicator = NO;
  _scrollView.showsHorizontalScrollIndicator = YES;
  _codeContentView = [[ENRMCodeBlockContentView alloc] initWithFrame:CGRectZero];
  BOOL darkBackground = ENRMColorIsDark([_config codeBlockBackgroundColor]);
#if !TARGET_OS_OSX
  _scrollView.bounces = YES;
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
  CGFloat contentWidth = MAX(_codeSize.width + horizontalPad * 2, frame.size.width);
  _codeContentView.textOrigin = CGPointMake(horizontalPad, inset);
  _codeContentView.frame = CGRectMake(0, 0, contentWidth, frame.size.height);
#if !TARGET_OS_OSX
  _scrollView.contentSize = CGSizeMake(contentWidth, frame.size.height);
  _scrollView.scrollEnabled = contentWidth > frame.size.width;
#endif
}

// Header is the top content inset plus one label line; the code text's own
// top inset then forms the single gap below the label.
- (CGFloat)headerHeight
{
  return [self contentInset] + _headerLabelLineHeight;
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
  CGFloat labelCenterY = headerH - _headerLabelLineHeight / 2;
  CGFloat buttonTop = MAX(labelCenterY - headerH / 2, 0);
  _copyButton.frame = CGRectMake(buttonLeft, buttonTop, headerH, headerH);
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

  NSAttributedString *plainCode = [self plainAttributedCode];
  NSAttributedString *highlighted = ENRMHighlightedAttributedCode(plainCode, _cachedCode, _cachedLanguage);
  _attributedCode = highlighted ?: plainCode;

  if (_attributedCode.length > 0) {
    CGRect codeBounds = [_attributedCode boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                                      options:NSStringDrawingUsesLineFragmentOrigin
                                                      context:nil];
    _codeSize = CGSizeMake(ceil(codeBounds.size.width), ceil(codeBounds.size.height));
  } else {
    _codeSize = CGSizeZero;
  }
  _codeContentView.attributedCode = _attributedCode;

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
  if (_cachedCode.length == 0) {
    return [[NSAttributedString alloc] initWithString:@""];
  }

  NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:_cachedCode];
  ENRMApplyCodeBlockTextAttributes(attributed, NSMakeRange(0, attributed.length), _config);
  return attributed;
}

- (CGFloat)contentInset
{
  return [_config codeBlockPadding] + [_config codeBlockBorderWidth];
}

- (CGFloat)measureHeight:(CGFloat)maxWidth
{
  CGFloat inset = [self contentInset];
  CGFloat headerH = [self headerHeight];
  if (_attributedCode.length == 0) {
    return headerH + inset * 2;
  }
  return _codeSize.height + inset * 2 + headerH;
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
    [_languageLabel drawAtPoint:CGPointMake(inset, headerH - _languageLabelSize.height)];
  }
}

- (NSString *)fencedMarkdown
{
  return ENRMCodeBlockFencedMarkdown(_cachedCode, _cachedLanguage, _fenceChar);
}

- (void)copyCodeToPasteboard
{
  copyStringToPasteboard(_cachedCode);
}

- (void)copyMarkdownToPasteboard
{
  copyStringToPasteboard([self fencedMarkdown]);
}

#if !TARGET_OS_OSX
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        configurationForMenuAtLocation:(CGPoint)location
{
  return [UIContextMenuConfiguration
      configurationWithIdentifier:nil
                  previewProvider:nil
                   actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
                     UIAction *copyCode =
                         [UIAction actionWithTitle:self.copyLabel
                                             image:[RCTUIImage systemImageNamed:@"doc.on.doc"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *action) { [self copyCodeToPasteboard]; }];

                     UIAction *copyMarkdown =
                         [UIAction actionWithTitle:self.copyAsMarkdownLabel
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
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
  [menu addItem:ENRMCreateMenuItem(self.copyLabel, ^{ [self copyCodeToPasteboard]; })];
  [menu addItem:ENRMCreateMenuItem(self.copyAsMarkdownLabel, ^{ [self copyMarkdownToPasteboard]; })];
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

// The container is a single accessibility element, which hides the copy
// button subview from VoiceOver; expose the copy action explicitly instead.
- (NSArray<UIAccessibilityCustomAction *> *)accessibilityCustomActions
{
  if (self.copyLabel.length == 0) {
    return @[];
  }
  UIAccessibilityCustomAction *copyAction =
      [[UIAccessibilityCustomAction alloc] initWithName:self.copyLabel
                                                 target:self
                                               selector:@selector(performCopyAccessibilityAction:)];
  return @[ copyAction ];
}

- (BOOL)performCopyAccessibilityAction:(UIAccessibilityCustomAction *)action
{
  [self copyCodeToPasteboard];
  return YES;
}
#endif

@end
