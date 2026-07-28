#import "ENRMCodeBlockContainerView.h"
#import "ENRMCodeBlockHighlighter.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "PasteboardUtils.h"
#if TARGET_OS_OSX
#import "ENRMMenuAction.h"
#endif

// Block segment view for fenced code blocks, rendered as a sibling view next
// to text segments the same way TableContainerView is (see SegmentRenderer.m).
//
// The block consists of a header bar (language display name on the left, a
// copy-code button on the right) and the code text below it. Background,
// border, header label, and code are drawn in a single drawRect: pass,
// mirroring the approach of ENRMTableIOSGridView; only the copy button is a
// real subview so it can receive taps. Long lines wrap, matching the previous
// attribute-based rendering; horizontal scrolling can be added later as a
// style option. Syntax coloring is delegated to the shared C++ highlighting
// seam through the ENRMCodeBlockHighlighter adapter; when the highlighting
// module is compiled out the code is drawn uncolored.
//
// Measurement parity: measureHeight: computes the bounding rect of the same
// attributed string drawRect: draws and derives the header height from the
// same label font metrics, so the height reported during segment layout
// matches the drawn height.

static const CGFloat kENRMHeaderLabelScale = 0.85;
static const CGFloat kENRMHeaderSecondaryAlpha = 0.6;
static const CGFloat kENRMHeaderDividerAlpha = 0.2;

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
#if !TARGET_OS_OSX
  UIButton *_copyButton;
#else
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
    self.backgroundColor = [RCTUIColor clearColor];

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

#if !TARGET_OS_OSX
- (UIFont *)headerFont
{
  return [UIFont systemFontOfSize:[_config codeBlockFont].pointSize * kENRMHeaderLabelScale weight:UIFontWeightMedium];
}
#else
- (NSFont *)headerFont
{
  return [NSFont systemFontOfSize:[_config codeBlockFont].pointSize * kENRMHeaderLabelScale weight:NSFontWeightMedium];
}
#endif

- (CGFloat)headerLabelLineHeight
{
#if !TARGET_OS_OSX
  return ceil([self headerFont].lineHeight);
#else
  NSFont *font = [self headerFont];
  return ceil(font.ascender - font.descender);
#endif
}

// Header is the top content inset plus one label line; the code text's own
// top inset then forms the single gap below the label.
- (CGFloat)headerHeight
{
  return [self contentInset] + [self headerLabelLineHeight];
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
  CGFloat labelCenterY = headerH - [self headerLabelLineHeight] / 2;
  CGFloat buttonTop = MAX(labelCenterY - headerH / 2, 0);
  _copyButton.frame = CGRectMake(buttonLeft, buttonTop, headerH, headerH);
}

#if !TARGET_OS_OSX
- (void)layoutSubviews
{
  [super layoutSubviews];
  [self layoutHeaderButton];
}
#else
- (void)layout
{
  [super layout];
  [self layoutHeaderButton];
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

static void ENRMAppendNodeContent(MarkdownASTNode *node, NSMutableString *output)
{
  if (node.content.length > 0) {
    [output appendString:node.content];
  }
  for (MarkdownASTNode *child in node.children) {
    ENRMAppendNodeContent(child, output);
  }
}

static NSString *ENRMExtractCode(MarkdownASTNode *node)
{
  NSMutableString *code = [NSMutableString string];
  ENRMAppendNodeContent(node, code);
  NSUInteger end = code.length;
  while (end > 0 && [code characterAtIndex:end - 1] == '\n') {
    end--;
  }
  return [code substringToIndex:end];
}

// Keep the entries in sync with languageNames in the Android
// CodeBlockContainerView so both platforms label fences identically.
static NSString *ENRMDisplayLanguageName(NSString *language)
{
  if (language.length == 0) {
    return @"";
  }

  static NSDictionary<NSString *, NSString *> *names;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    names = @{
      @"bash" : @"Bash",
      @"c" : @"C",
      @"cc" : @"C++",
      @"cpp" : @"C++",
      @"cs" : @"C#",
      @"csharp" : @"C#",
      @"css" : @"CSS",
      @"cxx" : @"C++",
      @"dockerfile" : @"Dockerfile",
      @"go" : @"Go",
      @"golang" : @"Go",
      @"graphql" : @"GraphQL",
      @"html" : @"HTML",
      @"java" : @"Java",
      @"javascript" : @"JavaScript",
      @"js" : @"JavaScript",
      @"json" : @"JSON",
      @"jsx" : @"JSX",
      @"kotlin" : @"Kotlin",
      @"kt" : @"Kotlin",
      @"markdown" : @"Markdown",
      @"md" : @"Markdown",
      @"objc" : @"Objective-C",
      @"objectivec" : @"Objective-C",
      @"php" : @"PHP",
      @"py" : @"Python",
      @"python" : @"Python",
      @"rb" : @"Ruby",
      @"ruby" : @"Ruby",
      @"rs" : @"Rust",
      @"rust" : @"Rust",
      @"scss" : @"SCSS",
      @"sh" : @"Shell",
      @"shell" : @"Shell",
      @"sql" : @"SQL",
      @"swift" : @"Swift",
      @"toml" : @"TOML",
      @"ts" : @"TypeScript",
      @"tsx" : @"TSX",
      @"typescript" : @"TypeScript",
      @"xml" : @"XML",
      @"yaml" : @"YAML",
      @"yml" : @"YAML",
      @"zsh" : @"Zsh",
    };
  });

  NSString *lower = language.lowercaseString;
  NSString *mapped = names[lower];
  if (mapped) {
    return mapped;
  }
  return [[[lower substringToIndex:1] uppercaseString] stringByAppendingString:[lower substringFromIndex:1]];
}

- (void)applyCodeBlockNode:(MarkdownASTNode *)node
{
  _cachedCode = ENRMExtractCode(node);

  NSString *language = node.attributes[@"language"];
  _cachedLanguage = language.length > 0 ? language : nil;
  _displayLanguage = ENRMDisplayLanguageName(_cachedLanguage);
  NSString *fenceChar = node.attributes[@"fenceChar"];
  _fenceChar = fenceChar.length > 0 ? fenceChar : @"`";

  NSAttributedString *plainCode = [self plainAttributedCode];
  NSAttributedString *highlighted = ENRMHighlightedAttributedCode(plainCode, _cachedCode, _cachedLanguage);
  _attributedCode = highlighted ?: plainCode;

#if !TARGET_OS_OSX
  [self setNeedsDisplay];
#else
  [self setNeedsDisplay:YES];
#endif
}

- (NSAttributedString *)plainAttributedCode
{
  if (_cachedCode.length == 0) {
    return [[NSAttributedString alloc] initWithString:@""];
  }

  NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
  paragraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;
  paragraphStyle.alignment = NSTextAlignmentLeft;

  NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
  attributes[NSFontAttributeName] = [_config codeBlockFont];
  attributes[NSParagraphStyleAttributeName] = paragraphStyle;
  RCTUIColor *color = [_config codeBlockColor];
  if (color) {
    attributes[NSForegroundColorAttributeName] = color;
  }

  NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:_cachedCode
                                                                                 attributes:attributes];
  CGFloat lineHeight = [_config codeBlockLineHeight];
  if (lineHeight > 0) {
    applyLineHeight(attributed, NSMakeRange(0, attributed.length), lineHeight);
  }
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
  CGFloat available = MAX(maxWidth - inset * 2, 1);
  CGRect bounds = [_attributedCode boundingRectWithSize:CGSizeMake(available, CGFLOAT_MAX)
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                                context:nil];
  return ceil(bounds.size.height) + inset * 2 + headerH;
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

  if (_displayLanguage.length > 0) {
    NSMutableDictionary *labelAttributes = [NSMutableDictionary dictionary];
    labelAttributes[NSFontAttributeName] = [self headerFont];
    RCTUIColor *labelColor = [[_config codeBlockColor] colorWithAlphaComponent:kENRMHeaderSecondaryAlpha];
    if (labelColor) {
      labelAttributes[NSForegroundColorAttributeName] = labelColor;
    }
    CGSize labelSize = [_displayLanguage sizeWithAttributes:labelAttributes];
    [_displayLanguage drawAtPoint:CGPointMake(inset, headerH - labelSize.height) withAttributes:labelAttributes];
  }

  if (_attributedCode.length > 0) {
    CGRect textRect = CGRectInset(self.bounds, inset, inset);
    textRect.origin.y += headerH;
    textRect.size.height = MAX(textRect.size.height - headerH, 0);
    [_attributedCode drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin context:nil];
  }
}

- (NSString *)fencedMarkdown
{
  NSString *fence = [@"" stringByPaddingToLength:3 withString:_fenceChar startingAtIndex:0];
  return [NSString stringWithFormat:@"%@%@\n%@\n%@", fence, _cachedLanguage ?: @"", _cachedCode, fence];
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
- (NSMenu *)menuForEvent:(NSEvent *)event
{
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
  [menu addItem:ENRMCreateMenuItem(self.copyLabel, ^{ [self copyCodeToPasteboard]; })];
  [menu addItem:ENRMCreateMenuItem(self.copyAsMarkdownLabel, ^{ [self copyMarkdownToPasteboard]; })];
  return menu;
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
