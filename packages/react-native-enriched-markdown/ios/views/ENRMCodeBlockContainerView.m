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
// The whole block (background, border, code text) is drawn in a single
// drawRect: pass, mirroring the approach of ENRMTableIOSGridView. Long lines
// wrap, matching the previous attribute-based rendering; horizontal scrolling
// can be added later as a style option. Syntax coloring is delegated to the
// shared C++ highlighting seam through the ENRMCodeBlockHighlighter adapter;
// when the highlighting module is compiled out the code is drawn uncolored,
// visually equivalent to the old CodeBlockAttributeName path.
//
// Measurement parity: measureHeight: computes the bounding rect of the same
// attributed string drawRect: draws, so the height reported during segment
// layout matches the drawn height.

#if !TARGET_OS_OSX
@interface ENRMCodeBlockContainerView () <UIContextMenuInteractionDelegate>
@end
#endif

@implementation ENRMCodeBlockContainerView {
  NSAttributedString *_attributedCode;
  NSString *_cachedCode;
  NSString *_cachedLanguage;
  NSString *_fenceChar;
}

@synthesize copyLabel = _copyLabel;
@synthesize copyAsMarkdownLabel = _copyAsMarkdownLabel;

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
#endif
  }
  return self;
}

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

- (void)applyCodeBlockNode:(MarkdownASTNode *)node
{
  _cachedCode = ENRMExtractCode(node);

  NSString *language = node.attributes[@"language"];
  _cachedLanguage = language.length > 0 ? language : nil;
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
  if (_attributedCode.length == 0) {
    return inset * 2;
  }
  CGFloat available = MAX(maxWidth - inset * 2, 1);
  CGRect bounds = [_attributedCode boundingRectWithSize:CGSizeMake(available, CGFLOAT_MAX)
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                                context:nil];
  return ceil(bounds.size.height) + inset * 2;
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

  if (_attributedCode.length > 0) {
    CGFloat inset = [self contentInset];
    CGRect textRect = CGRectInset(self.bounds, inset, inset);
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
#endif

@end
