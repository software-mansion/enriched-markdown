#import "ENRMBlockquoteContainerView.h"
#import "ENRMAdmonitionIcons.h"
#import "ENRMCodeBlockContainerView.h"
#import "ENRMFeatureFlags.h"
#import "ENRMSegmentHeightMeasurer.h"
#import "ENRMTextInteractionUtils.h"
#import "ENRMTextRenderer.h"
#import "EnrichedMarkdownInternalText.h"
#import "MarkdownASTNode.h"
#import "SegmentRenderer.h"
#import "TableContainerView.h"
#if ENRICHED_MARKDOWN_MATH
#import "ENRMMathContainerView.h"
#endif

// Inner content is rendered with trailing margins disabled; the quote's own
// vertical inset provides the bottom gap, and per-segment margins between children
// still apply (allowTrailingMargin only gates the last child's bottom margin). The
// consumer's allowFontScaling / lineBreakStrategy are threaded through so the
// quote's content honors them the same way the root document path does.
static NSArray<ENRMRenderedSegment *> *ENRMRenderBlockquoteChildren(MarkdownASTNode *node, StyleConfig *config,
                                                                    BOOL allowFontScaling,
                                                                    NSLineBreakStrategy lineBreakStrategy)
{
  return ENRMRenderSegmentsFromAST(node, config, /*allowTrailingMargin*/ NO, allowFontScaling,
                                   config.maxFontSizeMultiplier, lineBreakStrategy, /*blockquoteContent*/ YES);
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

static UIEdgeInsets ENRMBlockquoteContentInsetsForNode(StyleConfig *config, BOOL isAdmonition)
{
  CGFloat padding = config.blockquotePadding;
  CGFloat left = ceil(config.blockquoteBorderWidth + config.blockquoteGapWidth + padding);
  CGFloat top = ceil(padding + ENRMAdmonitionHeaderReservedHeight(config, isAdmonition));
  CGFloat vertical = ceil(padding);
  CGFloat right = ceil(padding);
  return UIEdgeInsetsMake(top, left, vertical, right);
}

static UIEdgeInsets ENRMBlockquoteContentInsets(StyleConfig *config)
{
  return ENRMBlockquoteContentInsetsForNode(config, NO);
}

@interface ENRMBlockquoteContainerView ()
// nil for a plain blockquote; the admonition type string otherwise.
@property (nonatomic, copy, nullable) NSString *admonitionType;
@end

@implementation ENRMBlockquoteContainerView

- (instancetype)initWithConfig:(StyleConfig *)config
{
  self = [super initWithFrame:CGRectZero];
  if (self) {
    self.config = config;
    self.contentInsets = ENRMBlockquoteContentInsets(config);
    self.allowTrailingMargin = NO;
    // Preserved prior defaults until the host overrides them at creation.
    _allowFontScaling = YES;
    _lineBreakStrategy = NSLineBreakStrategyNone;
#if !TARGET_OS_OSX
    self.contentMode = UIViewContentModeRedraw;
#endif
    self.segmentViewRegistry = [self buildChildRegistry];
  }
  return self;
}

- (void)applyBlockquoteNode:(MarkdownASTNode *)node
{
  self.admonitionType = ENRMAdmonitionTypeForNode(node);
  self.contentInsets = ENRMBlockquoteContentInsetsForNode(self.config, self.admonitionType != nil);
  NSArray<ENRMRenderedSegment *> *rendered =
      ENRMRenderBlockquoteChildren(node, self.config, self.allowFontScaling, self.lineBreakStrategy);
  [self applySegments:rendered reset:NO];
#if !TARGET_OS_OSX
  [self setNeedsDisplay];
#else
  self.needsDisplay = YES;
#endif
}

- (void)pushCopyLabelsToChildren
{
  for (RCTUIView *child in self.subviews) {
    if ([child isKindOfClass:[ENRMCodeBlockContainerView class]]) {
      ((ENRMCodeBlockContainerView *)child).copyLabel = self.copyLabel;
      ((ENRMCodeBlockContainerView *)child).copyAsMarkdownLabel = self.copyAsMarkdownLabel;
    } else if ([child isKindOfClass:[TableContainerView class]]) {
      ((TableContainerView *)child).copyLabel = self.copyLabel;
      ((TableContainerView *)child).copyAsMarkdownLabel = self.copyAsMarkdownLabel;
    } else if ([child isKindOfClass:[ENRMBlockquoteContainerView class]]) {
      ENRMBlockquoteContainerView *quote = (ENRMBlockquoteContainerView *)child;
      quote.copyLabel = self.copyLabel;
      quote.copyAsMarkdownLabel = self.copyAsMarkdownLabel;
      [quote pushCopyLabelsToChildren];
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([child isKindOfClass:[ENRMMathContainerView class]]) {
      ((ENRMMathContainerView *)child).copyLabel = self.copyLabel;
      ((ENRMMathContainerView *)child).copyAsMarkdownLabel = self.copyAsMarkdownLabel;
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
  StyleConfig *config = self.config;
  __weak ENRMBlockquoteContainerView *weakSelf = self;
  NSMutableArray<ENRMSegmentViewHandler *> *handlers = [NSMutableArray array];

  [handlers
      addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindText
                    matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                      return [view isKindOfClass:[EnrichedMarkdownInternalText class]];
                    }
                    createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                      ENRMBlockquoteContainerView *strongSelf = weakSelf;
                      EnrichedMarkdownInternalText *view = [[EnrichedMarkdownInternalText alloc] initWithConfig:config];
                      view.lastElementMarginBottom = segment.textResult.lastElementMarginBottom;
                      view.accessibilityInfo = segment.textResult.accessibilityInfo;
                      [view applyAttributedText:segment.textResult.attributedText context:segment.textResult.context];
                      if (strongSelf) {
                        [strongSelf attachLinkTapToTextView:view];
                      }
                      return view;
                    }
                    updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                      EnrichedMarkdownInternalText *textView = (EnrichedMarkdownInternalText *)view;
                      textView.lastElementMarginBottom = segment.textResult.lastElementMarginBottom;
                      textView.accessibilityInfo = segment.textResult.accessibilityInfo;
                      [textView applyAttributedText:segment.textResult.attributedText
                                            context:segment.textResult.context];
                    }]];

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindTable
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[TableContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            TableContainerView *view = [[TableContainerView alloc] initWithConfig:config];
                            ENRMBlockquoteContainerView *strongSelf = weakSelf;
                            if (strongSelf) {
                              view.copyLabel = strongSelf.menuCopyLabel;
                              view.copyAsMarkdownLabel = strongSelf.menuCopyAsMarkdownLabel;
                              view.onLinkPress = ^(NSString *url) {
                                ENRMBlockquoteContainerView *s = weakSelf;
                                if (s.onLinkPress && url)
                                  s.onLinkPress(url);
                              };
                              view.onLinkLongPress = ^(NSString *url) {
                                ENRMBlockquoteContainerView *s = weakSelf;
                                if (s.onLinkLongPress && url)
                                  s.onLinkLongPress(url);
                              };
                            }
                            [view applyTableNode:segment.tableSegment.tableNode];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            [(TableContainerView *)view applyTableNode:segment.tableSegment.tableNode];
                          }]];

  [handlers
      addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindCodeBlock
                    matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                      return [view isKindOfClass:[ENRMCodeBlockContainerView class]];
                    }
                    createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                      ENRMCodeBlockContainerView *view = [[ENRMCodeBlockContainerView alloc] initWithConfig:config];
                      ENRMBlockquoteContainerView *strongSelf = weakSelf;
                      view.copyLabel = strongSelf.menuCopyLabel;
                      view.copyAsMarkdownLabel = strongSelf.menuCopyAsMarkdownLabel;
                      view.onCopyPress = ^(NSString *code, NSString *language) {
                        ENRMBlockquoteContainerView *s = weakSelf;
                        if (s.onCopyPress)
                          s.onCopyPress(code, language);
                      };
                      [view applyCodeBlockNode:segment.codeBlockSegment.codeBlockNode];
                      return view;
                    }
                    updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                      [(ENRMCodeBlockContainerView *)view applyCodeBlockNode:segment.codeBlockSegment.codeBlockNode];
                    }]];

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindBlockquote
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMBlockquoteContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            ENRMBlockquoteContainerView *view =
                                [[ENRMBlockquoteContainerView alloc] initWithConfig:config];
                            view.nested = YES;
                            ENRMBlockquoteContainerView *strongSelf = weakSelf;
                            if (strongSelf) {
                              view.allowFontScaling = strongSelf.allowFontScaling;
                              view.lineBreakStrategy = strongSelf.lineBreakStrategy;
                              view.copyLabel = strongSelf.menuCopyLabel;
                              view.copyAsMarkdownLabel = strongSelf.menuCopyAsMarkdownLabel;
                              view.onCopyPress = strongSelf.onCopyPress;
                              view.onLinkPress = ^(NSString *url) {
                                ENRMBlockquoteContainerView *s = weakSelf;
                                if (s.onLinkPress && url)
                                  s.onLinkPress(url);
                              };
                              view.onLinkLongPress = ^(NSString *url) {
                                ENRMBlockquoteContainerView *s = weakSelf;
                                if (s.onLinkLongPress && url)
                                  s.onLinkLongPress(url);
                              };
                            }
                            [view applyBlockquoteNode:segment.blockquoteSegment.blockquoteNode];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            [(ENRMBlockquoteContainerView *)view
                                applyBlockquoteNode:segment.blockquoteSegment.blockquoteNode];
                          }]];

#if ENRICHED_MARKDOWN_MATH
#if !TARGET_OS_OSX
  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindMath
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMMathContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            ENRMMathContainerView *view = [[ENRMMathContainerView alloc] initWithConfig:config];
                            ENRMBlockquoteContainerView *strongSelf = weakSelf;
                            view.copyLabel = strongSelf.menuCopyLabel;
                            view.copyAsMarkdownLabel = strongSelf.menuCopyAsMarkdownLabel;
                            [view applyLatex:segment.mathSegment.latex];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            [(ENRMMathContainerView *)view applyLatex:segment.mathSegment.latex];
                          }]];
#endif
#endif

  return [[ENRMSegmentViewRegistry alloc] initWithHandlers:handlers];
}

- (void)attachLinkTapToTextView:(EnrichedMarkdownInternalText *)view
{
  ENRMTapRecognizer *tap = [[ENRMTapRecognizer alloc] initWithTarget:self action:@selector(handleTextTap:)];
  [view.textView addGestureRecognizer:tap];
}

- (void)handleTextTap:(ENRMTapRecognizer *)recognizer
{
  ENRMPlatformTextView *textView = (ENRMPlatformTextView *)recognizer.view;
  __weak ENRMBlockquoteContainerView *weakSelf = self;
  ENRMHandleTapOnTextView(textView, recognizer, ^(NSString *url) {
    ENRMBlockquoteContainerView *strongSelf = weakSelf;
    if (strongSelf.onLinkPress && url)
      strongSelf.onLinkPress(url);
  });
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
{
  UIEdgeInsets insets = ENRMBlockquoteContentInsetsForNode(config, ENRMAdmonitionTypeForNode(node) != nil);
  CGFloat innerWidth = MAX(maxWidth - insets.left - insets.right, 1);

  NSArray<ENRMRenderedSegment *> *rendered =
      ENRMRenderBlockquoteChildren(node, config, allowFontScaling, lineBreakStrategy);
  CGFloat childrenHeight = ENRMMeasureSegmentsHeightViewFree(
      rendered, config, innerWidth, /*allowTrailingMargin*/ NO, pointScaleFactor, ENRMWritingDirectionModeFirstStrong,
      NSWritingDirectionNatural, allowFontScaling, lineBreakStrategy);

  return childrenHeight + insets.top + insets.bottom;
}

- (void)drawRect:(CGRect)rect
{
  StyleConfig *config = self.config;
  CGFloat borderWidth = config.blockquoteBorderWidth;
  CGFloat radius = config.blockquoteBorderRadius;
  CGRect bounds = self.bounds;

  // The rounded (or plain) box outline, shared by the background fill and the accent
  // bar's clip so the bar's left corners follow the border radius.
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
      CGRect barRect = CGRectMake(0, 0, borderWidth, bounds.size.height);
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

// Draws the admonition header (tinted octicon + capitalized title) in the band
// reserved at the top by the enlarged content inset. The view is flipped on
// macOS, so the y-down icon path and text draw identically on both platforms.
- (void)drawAdmonitionHeaderForType:(NSString *)type config:(StyleConfig *)config
{
  RCTUIColor *tint = [config admonitionColorForType:type];
  CGFloat padding = config.blockquotePadding;
  CGFloat leftInset = ceil(config.blockquoteBorderWidth + config.blockquoteGapWidth + padding);
  CGFloat iconSize = ENRMAdmonitionIconSize(config);
  CGFloat headerHeight = ENRMAdmonitionHeaderContentHeight(config);
  CGFloat headerTop = ceil(padding);
  CGFloat titleX = leftInset;

  CGPathRef iconPath = ENRMAdmonitionIconPath(type);
  if (iconPath) {
#if !TARGET_OS_OSX
    CGContextRef ctx = UIGraphicsGetCurrentContext();
#else
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
#endif
    if (ctx) {
      CGFloat scale = iconSize / ENRMAdmonitionIconViewBox;
      CGFloat iconY = headerTop + (headerHeight - iconSize) / 2.0;
      CGContextSaveGState(ctx);
      CGContextTranslateCTM(ctx, leftInset, iconY);
      CGContextScaleCTM(ctx, scale, scale);
      CGContextAddPath(ctx, iconPath);
      [tint setFill];
      CGContextFillPath(ctx);
      CGContextRestoreGState(ctx);
    }
    titleX = leftInset + iconSize + round(iconSize * 0.4);
  }

  NSString *title = ENRMAdmonitionTitle(type);
  UIFont *titleFont = ENRMAdmonitionTitleFont(config);
  NSDictionary<NSAttributedStringKey, id> *attributes =
      @{NSFontAttributeName : titleFont, NSForegroundColorAttributeName : tint};
  NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:title attributes:attributes];
  CGSize titleSize = [attributed size];
  CGFloat titleY = headerTop + (headerHeight - titleSize.height) / 2.0;
  [attributed drawAtPoint:CGPointMake(titleX, titleY)];
}

@end
