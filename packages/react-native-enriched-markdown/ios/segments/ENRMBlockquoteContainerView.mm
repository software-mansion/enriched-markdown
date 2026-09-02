#import "ENRMBlockquoteContainerView.h"
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

static UIEdgeInsets ENRMBlockquoteContentInsets(StyleConfig *config)
{
  CGFloat padding = config.blockquotePadding;
  CGFloat left = ceil(config.blockquoteBorderWidth + config.blockquoteGapWidth + padding);
  CGFloat vertical = ceil(padding);
  CGFloat right = ceil(padding);
  return UIEdgeInsetsMake(vertical, left, vertical, right);
}

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
  NSArray<ENRMRenderedSegment *> *rendered =
      ENRMRenderBlockquoteChildren(node, self.config, self.allowFontScaling, self.lineBreakStrategy);
  [self applySegments:rendered reset:NO];
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
  UIEdgeInsets insets = ENRMBlockquoteContentInsets(config);
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

  RCTUIColor *backgroundColor = config.blockquoteBackgroundColor;
  if (backgroundColor && backgroundColor != [RCTUIColor clearColor]) {
    [backgroundColor setFill];
    [boxPath fill];
  }

  if (borderWidth > 0) {
    RCTUIColor *borderColor = config.blockquoteBorderColor;
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
}

@end
