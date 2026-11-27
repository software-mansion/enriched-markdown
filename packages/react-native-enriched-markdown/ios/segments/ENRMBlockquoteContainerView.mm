#import "ENRMBlockquoteContainerView.h"
#import "ENRMAdmonitionIcons.h"
#import "ENRMBlockSlotSegmentView.h"
#import "ENRMCodeBlockContainerView.h"
#import "ENRMDroppableContent.h"
#import "ENRMFeatureFlags.h"
#import "ENRMLinkContextMenus.h"
#import "ENRMListContainerView.h"
#import "ENRMNestedSegmentViewRegistry.h"
#import "ENRMSegmentHeightMeasurer.h"
#import "ENRMTableIOSGridView.h"
#import "ENRMTextInteractionUtils.h"
#import "ENRMTextRenderer.h"
#import "EnrichedMarkdownInternalText.h"
#import "LinkTapUtils.h"
#import "MarkdownASTNode.h"
#import "MarkdownASTSerializer.h"
#import "PasteboardUtils.h"
#import "SegmentRenderer.h"
#import "TableContainerView.h"
#import <React/RCTI18nUtil.h>
#if ENRICHED_MARKDOWN_MATH
#import "ENRMMathContainerView.h"
#endif
#if ENRICHED_MARKDOWN_VIDEO
#import "ENRMVideoContainerView.h"
#endif
#if TARGET_OS_OSX
#import "ENRMMenuAction.h"
#endif

// Inner content is rendered with trailing margins disabled; the quote's own
// vertical inset provides the bottom gap, and per-segment margins between children
// still apply (allowTrailingMargin only gates the last child's bottom margin). The
// consumer's allowFontScaling / lineBreakStrategy are threaded through so the
// quote's content honors them the same way the root document path does.
static NSArray<ENRMRenderedSegment *> *ENRMRenderBlockquoteChildren(MarkdownASTNode *node, StyleConfig *config,
                                                                    BOOL allowFontScaling,
                                                                    NSLineBreakStrategy lineBreakStrategy,
                                                                    NSInteger taskIndexOffset,
                                                                    ENRMListSegment *listContext)
{
  if (listContext)
    return ENRMRenderSegmentsWithListContext(node, config, NO, allowFontScaling, config.maxFontSizeMultiplier,
                                             lineBreakStrategy, YES, listContext);
  return ENRMRenderSegmentsFromAST(node, config, NO, allowFontScaling, config.maxFontSizeMultiplier, lineBreakStrategy,
                                   YES, taskIndexOffset);
}

// The admonition type ("note"/"tip"/…) for a node, or nil for a plain quote.
static NSString *ENRMAdmonitionTypeForNode(MarkdownASTNode *node)
{
  if (node.type != MarkdownNodeTypeAdmonition) {
    return nil;
  }
  NSString *type = node.attributes[@"admonitionType"];
  return type.length > 0 ? type : @"note";
}

static CGFloat ENRMAdmonitionIconSize(StyleConfig *config)
{
  return ceil(config.blockquoteFontSize);
}

// Bold variant of the blockquote font for the header title, respecting the
// configured family where the platform supports trait derivation.
static UIFont *ENRMAdmonitionTitleFont(StyleConfig *config)
{
  UIFont *base = config.blockquoteFont;
#if !TARGET_OS_OSX
  UIFontDescriptor *descriptor = [base.fontDescriptor
      fontDescriptorWithSymbolicTraits:(base.fontDescriptor.symbolicTraits | UIFontDescriptorTraitBold)];
  UIFont *bold = descriptor ? [UIFont fontWithDescriptor:descriptor size:base.pointSize] : nil;
  return bold ?: [UIFont boldSystemFontOfSize:base.pointSize];
#else
  NSFontDescriptor *descriptor = [base.fontDescriptor fontDescriptorWithSymbolicTraits:NSFontDescriptorTraitBold];
  NSFont *bold = descriptor ? [NSFont fontWithDescriptor:descriptor size:base.pointSize] : nil;
  return bold ?: [NSFont boldSystemFontOfSize:base.pointSize];
#endif
}

// Height of the header band (icon + title row); body sits a gap below it.
static CGFloat ENRMAdmonitionHeaderContentHeight(StyleConfig *config)
{
  return ceil(MAX(ENRMAdmonitionIconSize(config), config.blockquoteFontSize * 1.35));
}

static CGFloat ENRMAdmonitionHeaderToBodyGap(StyleConfig *config)
{
  return round(config.blockquoteFontSize * 0.4);
}

// Vertical space reserved above the body for the header (0 for a plain quote).
static CGFloat ENRMAdmonitionHeaderReservedHeight(StyleConfig *config, BOOL isAdmonition)
{
  if (!isAdmonition) {
    return 0;
  }
  return ENRMAdmonitionHeaderContentHeight(config) + ENRMAdmonitionHeaderToBodyGap(config);
}

static CGFloat ENRMBlockquoteLeadingInset(StyleConfig *config)
{
  return ceil(config.blockquoteBorderWidth + config.blockquoteGapWidth + config.blockquotePadding);
}

static UIEdgeInsets ENRMBlockquoteContentInsetsForNode(StyleConfig *config, BOOL isAdmonition, BOOL isRTL)
{
  CGFloat padding = config.blockquotePadding;
  CGFloat leading = ENRMBlockquoteLeadingInset(config);
  CGFloat top = ceil(padding + ENRMAdmonitionHeaderReservedHeight(config, isAdmonition));
  CGFloat vertical = ceil(padding);
  CGFloat trailing = ceil(padding);
  return isRTL ? UIEdgeInsetsMake(top, trailing, vertical, leading)
               : UIEdgeInsetsMake(top, leading, vertical, trailing);
}

// The first strong character in the node, as web's dir="auto" finds it: nested
// quotes and tables count, code blocks, images and math do not.
static NSWritingDirection ENRMFirstStrongDirectionInNode(MarkdownASTNode *node)
{
  switch (node.type) {
    case MarkdownNodeTypeCodeBlock:
    case MarkdownNodeTypeImage:
    case MarkdownNodeTypeVideo:
    case MarkdownNodeTypeLatexMathInline:
    case MarkdownNodeTypeLatexMathDisplay:
      return NSWritingDirectionNatural;
    default:
      break;
  }
  NSWritingDirection direction = ENRMFirstStrongDirection(node.content);
  for (MarkdownASTNode *child in node.children) {
    if (direction != NSWritingDirectionNatural) {
      break;
    }
    direction = ENRMFirstStrongDirectionInNode(child);
  }
  return direction;
}

// A nested quote takes the side of the quote around it, as web's dir="auto"
// resolves only the outermost block. Otherwise the first strong character in
// the quote, unless the mode forces a side; without one, the layout and then
// the app decide.
static BOOL ENRMBlockquoteIsRTL(MarkdownASTNode *node, ENRMWritingDirectionMode mode,
                                NSWritingDirection layoutDirection, NSWritingDirection outerDirection)
{
  if (outerDirection != NSWritingDirectionNatural) {
    return outerDirection == NSWritingDirectionRightToLeft;
  }
  NSWritingDirection direction = NSWritingDirectionNatural;
  if (mode == ENRMWritingDirectionModeLTR) {
    direction = NSWritingDirectionLeftToRight;
  } else if (mode == ENRMWritingDirectionModeRTL) {
    direction = NSWritingDirectionRightToLeft;
  } else if (mode == ENRMWritingDirectionModeFirstStrong) {
    direction = ENRMFirstStrongDirectionInNode(node);
    if (direction == NSWritingDirectionNatural) {
      direction = layoutDirection;
    }
  }
  if (direction == NSWritingDirectionNatural) {
    return [[RCTI18nUtil sharedInstance] isRTL];
  }
  return direction == NSWritingDirectionRightToLeft;
}

@interface ENRMBlockquoteContainerView ()
#if !TARGET_OS_OSX
    <UIContextMenuInteractionDelegate>
#endif
// nil for a plain blockquote; the admonition type string otherwise.
@property (nonatomic, copy, nullable) NSString *admonitionType;
@property (nonatomic, assign) BOOL rightToLeft;
@property (nonatomic, copy) NSString *cachedMarkdown;
@property (nonatomic, copy) NSString *cachedPlainText;
// cachedPlainText with links as `[label](url)`, for `copyLinksAs: 'markdown'`.
@property (nonatomic, copy) NSString *cachedLinkedPlainText;
@end

#if !TARGET_OS_OSX
@interface ENRMBlockquoteContainerView () <UITextViewDelegate, ENRMLinkContextMenuSource, ENRMDroppableContent>
@end
#endif

@implementation ENRMBlockquoteContainerView

- (instancetype)initWithConfig:(StyleConfig *)config
{
  self = [super initWithFrame:CGRectZero];
  if (self) {
    self.config = config;
    self.contentInsets = ENRMBlockquoteContentInsetsForNode(config, NO, NO);
    self.allowTrailingMargin = NO;
    _writingDirectionMode = ENRMWritingDirectionModeFirstStrong;
    _resolvedLayoutDirection = NSWritingDirectionNatural;
    _outerDirection = NSWritingDirectionNatural;
    // Preserved prior defaults until the host overrides them at creation.
    _allowFontScaling = YES;
    _lineBreakStrategy = NSLineBreakStrategyNone;
    _dynamicProps = [[ENRMDynamicBlockProps alloc] init];
    _cachedMarkdown = @"";
    _cachedPlainText = @"";
#if !TARGET_OS_OSX
    self.contentMode = UIViewContentModeRedraw;
    UIContextMenuInteraction *contextMenu = [[UIContextMenuInteraction alloc] initWithDelegate:self];
    [self addInteraction:contextMenu];
#endif
    self.segmentViewRegistry = [self buildChildRegistry];
  }
  return self;
}

- (void)applyBlockquoteNode:(MarkdownASTNode *)node
{
  [self applyBlockquoteNode:node taskIndexOffset:self.listContext.taskIndexOffset];
}

- (void)applyBlockquoteNode:(MarkdownASTNode *)node taskIndexOffset:(NSInteger)taskIndexOffset
{
  self.admonitionType = ENRMAdmonitionTypeForNode(node);
  self.cachedMarkdown = markdownFromBlockquoteNode(node);
  self.cachedPlainText = plainTextFromASTNode(node);
  self.cachedLinkedPlainText = plainTextWithMarkdownLinksFromASTNode(node);
  NSArray<ENRMRenderedSegment *> *rendered = ENRMRenderBlockquoteChildren(
      node, self.config, self.allowFontScaling, self.lineBreakStrategy, taskIndexOffset, self.listContext);
  ENRMApplySegmentWritingDirection(rendered, self.writingDirectionMode, self.resolvedLayoutDirection);
  self.rightToLeft =
      ENRMBlockquoteIsRTL(node, self.writingDirectionMode, self.resolvedLayoutDirection, self.outerDirection);
  self.contentInsets = ENRMBlockquoteContentInsetsForNode(self.config, self.admonitionType != nil, self.rightToLeft);
  [self applySegments:rendered reset:NO];
  [self applySide:self.rightToLeft];
#if !TARGET_OS_OSX
  [self setNeedsDisplay];
#else
  self.needsDisplay = YES;
#endif
}

- (void)setOuterDirection:(NSWritingDirection)outerDirection
{
  _outerDirection = outerDirection;
  // Reused quotes can have new child lists even when their own side is unchanged.
  [self applySide:outerDirection == NSWritingDirectionNatural ? self.rightToLeft
                                                              : outerDirection == NSWritingDirectionRightToLeft];
}

// Moves the bar, insets and header to one side, and hands the side to nested
// quotes, which a parent's update can leave untouched.
- (void)applySide:(BOOL)rightToLeft
{
  if (self.rightToLeft != rightToLeft) {
    self.rightToLeft = rightToLeft;
    self.contentInsets = ENRMBlockquoteContentInsetsForNode(self.config, self.admonitionType != nil, rightToLeft);
    [self setNeedsLayout];
#if !TARGET_OS_OSX
    [self setNeedsDisplay];
#else
    self.needsDisplay = YES;
#endif
  }
  NSWritingDirection side = rightToLeft ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;
  for (RCTUIView *view in self.segmentViews) {
    if ([view isKindOfClass:[ENRMBlockquoteContainerView class]]) {
      ((ENRMBlockquoteContainerView *)view).outerDirection = side;
    } else if ([view isKindOfClass:[ENRMListContainerView class]]) {
      ((ENRMListContainerView *)view).outerDirection = side;
    }
  }
}

- (void)setAccessibilityLabels:(ENRMAccessibilityLabels *)accessibilityLabels
{
  if (_accessibilityLabels == accessibilityLabels) {
    return;
  }
  _accessibilityLabels = accessibilityLabels;
  // Children created before this point (or before a labels prop change) still
  // hold the previous labels; nested quotes forward them to their own children.
  for (RCTUIView *child in self.subviews) {
    if ([child isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      ((EnrichedMarkdownInternalText *)child).accessibilityLabels = accessibilityLabels;
    } else if ([child isKindOfClass:[TableContainerView class]]) {
      ((TableContainerView *)child).accessibilityLabels = accessibilityLabels;
    } else if ([child isKindOfClass:[ENRMBlockquoteContainerView class]]) {
      ((ENRMBlockquoteContainerView *)child).accessibilityLabels = accessibilityLabels;
    } else if ([child conformsToProtocol:@protocol(ENRMNestedSegmentHost)]) {
      ((id<ENRMNestedSegmentHost>)child).accessibilityLabels = accessibilityLabels;
    } else if ([child isKindOfClass:[ENRMCodeBlockContainerView class]]) {
      ((ENRMCodeBlockContainerView *)child).accessibilityLabels = accessibilityLabels;
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([child isKindOfClass:[ENRMMathContainerView class]]) {
      ((ENRMMathContainerView *)child).accessibilityLabels = accessibilityLabels;
    }
#endif
  }
}

// Child registry for this quote's own content. It reuses static creators for
// every kind and, for a nested Blockquote, creates another
// ENRMBlockquoteContainerView (the recursion). Streaming is static: no
// animation, no pending-fence sync.
- (ENRMSegmentViewRegistry *)buildChildRegistry
{
  return ENRMCreateNestedSegmentRegistry(self);
}

- (BOOL)childrenInsideBlockquote
{
  return YES;
}

- (void)configureNestedTextView:(EnrichedMarkdownInternalText *)view
{
  [self attachLinkTapToTextView:view];
}

- (void)attachLinkTapToTextView:(EnrichedMarkdownInternalText *)view
{
  ENRMTapRecognizer *tap = [[ENRMTapRecognizer alloc] initWithTarget:self action:@selector(handleTextTap:)];
  [view.textView addGestureRecognizer:tap];
#if !TARGET_OS_OSX
  view.textView.delegate = self;
#endif
}

- (void)handleTextTap:(ENRMTapRecognizer *)recognizer
{
  ENRMPlatformTextView *textView = (ENRMPlatformTextView *)recognizer.view;
  // Read before the link check below clears the selection.
  BOOL hadSelection = textView.selectedRange.length > 0;
  __weak ENRMBlockquoteContainerView *weakSelf = self;
  if (ENRMHandleTapOnTextView(textView, recognizer, ^(NSString *url) {
        ENRMBlockquoteContainerView *strongSelf = weakSelf;
        if (strongSelf.onLinkPress && url)
          strongSelf.onLinkPress(url);
      })) {
    return;
  }

  if (self.onImagePress) {
    NSDictionary<NSString *, NSString *> *image = imageAtTapLocation(textView, recognizer);
    if (image) {
      self.onImagePress(image[@"url"], image[@"altText"]);
      return;
    }
  }

  // Skip while text is selected so the tap only clears the selection.
  if (self.onTextPress && !hadSelection) {
    NSUInteger index = textPressIndexAtTapLocation(textView, recognizer);
    if (index != NSNotFound)
      self.onTextPress(index, ENRMGetAttributedText(textView).string);
  }
}

- (CGFloat)measureHeight:(CGFloat)maxWidth
{
  return [self computeContentHeightForWidth:MAX(maxWidth - self.contentInsets.left - self.contentInsets.right, 0)];
}

+ (CGFloat)measureHeightForBlockquoteNode:(MarkdownASTNode *)node
                                   config:(StyleConfig *)config
                                 maxWidth:(CGFloat)maxWidth
                         pointScaleFactor:(CGFloat)pointScaleFactor
                         allowFontScaling:(BOOL)allowFontScaling
                        lineBreakStrategy:(NSLineBreakStrategy)lineBreakStrategy
                     writingDirectionMode:(ENRMWritingDirectionMode)writingDirectionMode
                  resolvedLayoutDirection:(NSWritingDirection)resolvedLayoutDirection
                           outerDirection:(NSWritingDirection)outerDirection
                               wrapCursor:(ENRMCodeBlockWrapCursor *)wrapCursor
                             slotMeasurer:(ENRMBlockSlotMeasurer *)slotMeasurer
                                   origin:(CGPoint)origin
{
  return [self measureHeightForBlockquoteNode:node
                                       config:config
                                     maxWidth:maxWidth
                             pointScaleFactor:pointScaleFactor
                             allowFontScaling:allowFontScaling
                            lineBreakStrategy:lineBreakStrategy
                         writingDirectionMode:writingDirectionMode
                      resolvedLayoutDirection:resolvedLayoutDirection
                               outerDirection:outerDirection
                                   wrapCursor:wrapCursor
                                 slotMeasurer:slotMeasurer
                                       origin:origin
                                  listContext:nil];
}

+ (CGFloat)measureHeightForBlockquoteNode:(MarkdownASTNode *)node
                                   config:(StyleConfig *)config
                                 maxWidth:(CGFloat)maxWidth
                         pointScaleFactor:(CGFloat)pointScaleFactor
                         allowFontScaling:(BOOL)allowFontScaling
                        lineBreakStrategy:(NSLineBreakStrategy)lineBreakStrategy
                     writingDirectionMode:(ENRMWritingDirectionMode)writingDirectionMode
                  resolvedLayoutDirection:(NSWritingDirection)resolvedLayoutDirection
                           outerDirection:(NSWritingDirection)outerDirection
                               wrapCursor:(ENRMCodeBlockWrapCursor *)wrapCursor
                             slotMeasurer:(ENRMBlockSlotMeasurer *)slotMeasurer
                                   origin:(CGPoint)origin
                              listContext:(ENRMListSegment *)listContext
{
  NSArray<ENRMRenderedSegment *> *rendered = ENRMRenderBlockquoteChildren(
      node, config, allowFontScaling, lineBreakStrategy, /*taskIndexOffset*/ 0, listContext);
  ENRMApplySegmentWritingDirection(rendered, writingDirectionMode, resolvedLayoutDirection);
  BOOL isRTL = ENRMBlockquoteIsRTL(node, writingDirectionMode, resolvedLayoutDirection, outerDirection);
  UIEdgeInsets insets = ENRMBlockquoteContentInsetsForNode(config, ENRMAdmonitionTypeForNode(node) != nil, isRTL);
  CGFloat innerWidth = MAX(maxWidth - insets.left - insets.right, 1);
  CGFloat childrenHeight = ENRMMeasureSegmentsHeightViewFree(
      rendered, config, innerWidth, /*allowTrailingMargin*/ NO, pointScaleFactor, writingDirectionMode,
      resolvedLayoutDirection, isRTL ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight, allowFontScaling,
      lineBreakStrategy, wrapCursor, slotMeasurer, CGPointMake(origin.x + insets.left, origin.y + insets.top));

  return childrenHeight + insets.top + insets.bottom;
}

- (void)drawRect:(CGRect)rect
{
  StyleConfig *config = self.config;
  CGFloat borderWidth = config.blockquoteBorderWidth;
  CGFloat radius = config.blockquoteBorderRadius;
  CGRect bounds = self.bounds;

  // The rounded (or plain) box outline, shared by the background fill and the accent
  // bar's clip so the bar's outer corners follow the border radius.
#if !TARGET_OS_OSX
  UIBezierPath *boxPath = radius > 0 ? [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:radius]
                                     : [UIBezierPath bezierPathWithRect:bounds];
#else
  NSBezierPath *boxPath = radius > 0 ? [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:radius yRadius:radius]
                                     : [NSBezierPath bezierPathWithRect:bounds];
#endif

  // Admonitions theme the box with their per-type color; a plain quote keeps the
  // base blockquote colors.
  NSString *admonitionType = self.admonitionType;
  RCTUIColor *backgroundColor =
      admonitionType ? [config admonitionBackgroundColorForType:admonitionType] : config.blockquoteBackgroundColor;
  if (backgroundColor && backgroundColor != [RCTUIColor clearColor]) {
    [backgroundColor setFill];
    [boxPath fill];
  }

  if (borderWidth > 0) {
    RCTUIColor *borderColor =
        admonitionType ? [config admonitionColorForType:admonitionType] : config.blockquoteBorderColor;
    if (borderColor) {
      CGFloat barX = self.rightToLeft ? bounds.size.width - borderWidth : 0;
      CGRect barRect = CGRectMake(barX, 0, borderWidth, bounds.size.height);
      [borderColor setFill];
#if !TARGET_OS_OSX
      CGContextRef ctx = UIGraphicsGetCurrentContext();
      CGContextSaveGState(ctx);
      [boxPath addClip];
      [[UIBezierPath bezierPathWithRect:barRect] fill];
      CGContextRestoreGState(ctx);
#else
      [NSGraphicsContext saveGraphicsState];
      [boxPath addClip];
      [[NSBezierPath bezierPathWithRect:barRect] fill];
      [NSGraphicsContext restoreGraphicsState];
#endif
    }
  }

  if (admonitionType) {
    [self drawAdmonitionHeaderForType:admonitionType config:config];
  }
}

// Draws the admonition header (tinted octicon + title) in the band
// reserved at the top by the enlarged content inset, on the bar's side. The view
// is flipped on macOS, so the y-down icon path and text draw identically on both
// platforms.
- (void)drawAdmonitionHeaderForType:(NSString *)type config:(StyleConfig *)config
{
  RCTUIColor *tint = [config admonitionColorForType:type];
  BOOL rtl = self.rightToLeft;
  CGFloat width = self.bounds.size.width;
  CGFloat padding = config.blockquotePadding;
  CGFloat leadingInset = ENRMBlockquoteLeadingInset(config);
  CGFloat trailingInset = ceil(padding);
  CGFloat iconSize = ENRMAdmonitionIconSize(config);
  CGFloat headerHeight = ENRMAdmonitionHeaderContentHeight(config);
  CGFloat headerTop = ceil(padding);
  CGFloat titleInset = leadingInset;

  CGPathRef iconPath = ENRMAdmonitionIconPath(type);
  if (iconPath) {
#if !TARGET_OS_OSX
    CGContextRef ctx = UIGraphicsGetCurrentContext();
#else
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
#endif
    if (ctx) {
      CGFloat scale = iconSize / ENRMAdmonitionIconViewBox;
      CGFloat iconX = rtl ? width - leadingInset - iconSize : leadingInset;
      CGFloat iconY = headerTop + (headerHeight - iconSize) / 2.0;
      CGContextSaveGState(ctx);
      CGContextTranslateCTM(ctx, iconX, iconY);
      CGContextScaleCTM(ctx, scale, scale);
      CGContextAddPath(ctx, iconPath);
      [tint setFill];
      CGContextFillPath(ctx);
      CGContextRestoreGState(ctx);
    }
    titleInset = leadingInset + iconSize + round(iconSize * 0.4);
  }

  NSString *title = [config admonitionTitleForType:type];
  CGFloat titleWidth = width - trailingInset - titleInset;
  if (title.length == 0 || titleWidth <= 0) {
    return;
  }
  NSWritingDirection titleDirection = ENRMFirstStrongDirection(title);
  NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
  paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
  paragraph.baseWritingDirection = titleDirection != NSWritingDirectionNatural
                                       ? titleDirection
                                       : (rtl ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight);
  paragraph.alignment = rtl ? NSTextAlignmentRight : NSTextAlignmentLeft;
  NSDictionary<NSAttributedStringKey, id> *attributes = @{
    NSFontAttributeName : ENRMAdmonitionTitleFont(config),
    NSForegroundColorAttributeName : tint,
    NSParagraphStyleAttributeName : paragraph,
  };
  NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:title attributes:attributes];
  CGFloat titleHeight = [attributed size].height;
  CGFloat titleX = rtl ? trailingInset : titleInset;
  CGFloat titleY = headerTop + (headerHeight - titleHeight) / 2.0;
  [attributed drawWithRect:CGRectMake(titleX, titleY, titleWidth, ceil(titleHeight))
                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine
                   context:nil];
}

#pragma mark - Context menu

- (void)copyMarkdownToPasteboard
{
  if (_cachedMarkdown.length > 0) {
    copyStringToPasteboard(_cachedMarkdown);
  }
}

- (void)copyPlainTextToPasteboard
{
  if (_cachedPlainText.length > 0) {
    NSMutableDictionary *items = [NSMutableDictionary dictionary];
    items[kUTIPlainText] = self.config.copyLinksAsMarkdown ? _cachedLinkedPlainText : _cachedPlainText;
    if (_cachedMarkdown.length > 0) {
      items[kUTIMarkdown] = _cachedMarkdown;
    }
    copyItemsToPasteboard(items);
  }
}

#if !TARGET_OS_OSX
- (UITextItemMenuConfiguration *)textView:(UITextView *)textView
             menuConfigurationForTextItem:(UITextItem *)textItem
                              defaultMenu:(UIMenu *)defaultMenu API_AVAILABLE(ios(17.0))
{
  return ENRMLinkMenuConfigurationForTextItem(textView, textItem, defaultMenu, self.dynamicProps.linkContextMenus,
                                              self.dynamicProps.enableLinkPreview, self.onLinkLongPress);
}

- (ENRMLinkContextMenus *)linkContextMenusForTextView:(UITextView *)textView
{
  return self.dynamicProps.linkContextMenus;
}

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        configurationForMenuAtLocation:(CGPoint)location
{
  // Let the leaf interaction present a configured link menu, including nested tables.
  UIView *hit = [interaction.view hitTest:location withEvent:nil];
  while (hit && hit != interaction.view) {
    CGPoint point = [interaction.view convertPoint:location toView:hit];
    NSString *url = nil;
    if ([hit isKindOfClass:[UITextView class]])
      url = linkURLAtPoint((UITextView *)hit, point);
    else if ([hit isKindOfClass:[ENRMTableIOSGridView class]])
      url = [(ENRMTableIOSGridView *)hit linkAtPoint:point].url;
    if ([self.dynamicProps.linkContextMenus hasMenuForURL:url])
      return nil;
    hit = hit.superview;
  }
  if (!self.dynamicProps.enableBlockContextMenu) {
    return nil;
  }
  return [UIContextMenuConfiguration
      configurationWithIdentifier:nil
                  previewProvider:nil
                   actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
                     UIAction *copyPlainText =
                         [UIAction actionWithTitle:self.dynamicProps.menuCopyLabel
                                             image:[RCTUIImage systemImageNamed:@"doc.on.doc"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *action) { [self copyPlainTextToPasteboard]; }];

                     UIAction *copyMarkdown =
                         [UIAction actionWithTitle:self.dynamicProps.menuCopyAsMarkdownLabel
                                             image:[RCTUIImage systemImageNamed:@"doc.text"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *action) { [self copyMarkdownToPasteboard]; }];

                     return [UIMenu menuWithTitle:@"" children:@[ copyPlainText, copyMarkdown ]];
                   }];
}
#endif // !TARGET_OS_OSX

#if TARGET_OS_OSX
- (BOOL)isFlipped
{
  return YES;
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
  if (!self.dynamicProps.enableBlockContextMenu) {
    return [super menuForEvent:event];
  }
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
  [menu addItem:ENRMCreateMenuItem(self.dynamicProps.menuCopyLabel, ^{ [self copyPlainTextToPasteboard]; })];
  [menu addItem:ENRMCreateMenuItem(self.dynamicProps.menuCopyAsMarkdownLabel, ^{ [self copyMarkdownToPasteboard]; })];
  return menu;
}
#endif

@end
