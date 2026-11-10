#import "EnrichedMarkdown.h"
#import "ContextMenuUtils.h"
#import "ENRMAccessibilityLabels.h"
#import "ENRMAsyncRenderCoordinator.h"
#import "ENRMImageAttachment.h"
#import "ENRMLaidOutSize.h"
#import "ENRMLatexErrorCoordinator.h"
#import "ENRMLinkContextMenus.h"
#import "ENRMLinkRegexProps.h"
#import "ENRMMarkdownParser.h"
#import "ENRMPreparedRenderStore.h"
#import "ENRMStreamingEffectsProps.h"
#import "ENRMStreamingPacer.h"
#import "ENRMTextInteractionUtils.h"
#import "ENRMTextRenderCache.h"
#import "ENRMTextRenderer.h"
#import "ENRMTextViewSetup.h"
#import "ENRMUIKit.h"
#import "EditMenuUtils.h"
#import "ImageRequestHeaderUtils.h"
#import "LinkContextMenuUtils.h"
#import "LinkPillContentUtils.h"

#import "ENRMFeatureFlags.h"

#if ENRICHED_MARKDOWN_MATH
#import "ENRMMathContainerView.h"
#endif
#if ENRICHED_MARKDOWN_VIDEO
#import "ENRMVideoContainerView.h"
#endif
#import "ENRMBlockSlotLayerView.h"
#import "ENRMBlockSlotRevealController.h"
#import "ENRMBlockSlotSegmentView.h"
#import "ENRMBlockquoteContainerView.h"
#import "ENRMCodeBlockContainerView.h"
#import "ENRMCodeBlockWrapState.h"
#import "ENRMDynamicBlockProps.h"
#import "ENRMMarkdownTextView.h"
#import "ENRMSpoilerCapable.h"
#import "ENRMSpoilerOverlayView.h"
#import "ENRMSpoilerTapUtils.h"
#import "ENRMUTF8.h"
#import "ENRMViewFreeMeasurement.h"
#import "ENRMVisibleArea.h"
#import "EnrichedMarkdownBlockSlot.h"
#import "EnrichedMarkdownInternalText.h"
#import "FontScaleObserver.h"
#import "FontUtils.h"
#import "HeightUpdateUtils.h"
#import "LastElementUtils.h"
#import "LinkTapUtils.h"
#import "MarkdownASTNode.h"
#import "MarkdownAccessibilityElementBuilder.h"
#import "MarkdownExtractor.h"
#import "MeasurementCache.h"
#import "ParagraphStyleUtils.h"
#import "RenderContext.h"
#import "RenderedMarkdownSegment.h"
#import "RuntimeKeys.h"
#import "SegmentReconciler.h"
#import "SegmentRenderer.h"
#import "SegmentViewRegistry.h"
#import "SelectionColorUtils.h"
#import "StreamingMarkdownFilter.h"
#import "StyleConfig.h"
#import "StylePropsUtils.h"
#import "TableContainerView.h"
#import "TaskListTapUtils.h"
#import "TextViewLayoutManager.h"
#import <React/RCTUtils.h>
#import <objc/runtime.h>

#import <ReactNativeEnrichedMarkdown/EnrichedMarkdownComponentDescriptor.h>
#import <react/renderer/components/EnrichedMarkdownTextSpec/EventEmitters.h>
#import <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>
#import <react/renderer/components/EnrichedMarkdownTextSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"
#import <React/RCTConversions.h>
#import <React/RCTFont.h>
#import <React/RCTI18nUtil.h>
#import <React/RCTMountingTransactionObserving.h>

using namespace facebook::react;

typedef NS_OPTIONS(NSUInteger, ENRMDirtyFlags) {
  ENRMDirtyNone = 0,
  ENRMDirtyRecreateSegments = 1 << 0,
  ENRMDirtyForceHeight = 1 << 1,
  ENRMDirtyRender = 1 << 2,
};

// A signature no segment has (they are FNV hashes salted per kind).
static const uint64_t kENRMUnknownSignature = UINT64_MAX;

@interface EnrichedMarkdown () <RCTEnrichedMarkdownViewProtocol, UITextViewDelegate, ENRMImageLayoutObserver,
                                RCTMountingTransactionObserving>
+ (ENRMMd4cFlags *)flagsFromProps:(const EnrichedMarkdownMd4cFlagsStruct &)props;
- (void)emitLinkPress:(NSString *)url;
- (void)emitLinkLongPress:(NSString *)url;
- (void)emitLinkContextMenuItemPress:(NSString *)itemText pattern:(NSString *)pattern url:(NSString *)url;
- (void)emitImagePress:(NSString *)url altText:(NSString *)altText;
- (void)emitTextPress:(NSInteger)index text:(NSString *)text;
- (void)emitTaskListItemPress:(NSInteger)index checked:(BOOL)checked text:(NSString *)text;
- (void)emitCopyPress:(NSString *)code language:(NSString *)language;
- (void)emitCodeBlockPress:(NSString *)code language:(NSString *)language;
- (void)emitContextMenuItemPress:(NSString *)itemText
                    selectedText:(NSString *)selectedText
                  selectionStart:(NSUInteger)selectionStart
                    selectionEnd:(NSUInteger)selectionEnd;
@end

#if !TARGET_OS_OSX
@interface EnrichedMarkdown () <ENRMLinkContextMenuSource>
@end
#endif

@implementation EnrichedMarkdown {
  ENRMMarkdownParser *_parser;
  StyleConfig *_config;
  ENRMMd4cFlags *_md4cFlags;
  BOOL _isGFM;
  ENRMLinkRegexConfig *_linkRegex;
  ENRMLinkRegexConfig *_inlineCodeLinkRegex;
  NSString *_cachedMarkdown;
  NSString *_renderedMarkdown;
  ENRMLatexErrorCoordinator *_latexErrorCoordinator;
  NSMutableArray<RCTUIView *> *_segmentViews;
  NSMutableArray<NSNumber *> *_segmentSignatures;
  // Block segments off screen, their bitmaps dropped (see updateDrawnSegments).
  ENRMVisibleArea *_visibleArea;
  CGRect _drawnVisibleRect;
  NSHashTable<RCTUIView *> *_undrawnSegments;
  ENRMSegmentViewRegistry *_segmentViewRegistry;
  ENRMDirtyFlags _dirtyFlags;

  // Fabric children (React replacements for blocks) live here, above the
  // segments, so the segment reconciler's subview indices stay its own. The
  // shadow node publishes which slots exist and where they landed through state.
  RCTUIView *_slotLayer;
  NSSet<NSString *> *_activeBlockSlotIds;
  NSDictionary<NSString *, NSNumber *> *_blockSlotHeights;
  ENRMBlockSlotRevealController *_blockSlotReveal;

  ENRMAsyncRenderCoordinator *_renderCoordinator;
  // Text laid out while detached is current when the view attaches; one that
  // left a window may hold a stale layout and is refreshed on return (#155).
  BOOL _needsWindowAttachRefresh;

  EnrichedMarkdownShadowNode::ConcreteState::Shared _state;
  int _heightUpdateCounter;

  FontScaleObserver *_fontScaleObserver;
  CGFloat _maxFontSizeMultiplier;

  BOOL _allowTrailingMargin;
  BOOL _selectable;
  BOOL _enableLinkPreview;
  BOOL _enableTaskListItemToggle;
  BOOL _enableImagePress;
  BOOL _enableTextPress;
  BOOL _streaming;
  // The stream ended and its last text has not been rendered yet: it still animates, then settles.
  BOOL _streamEnding;
  BOOL _streamingFade;
  // Smooth pacing (streamingConfig.smooth): the view renders the markdown revealed so far.
  ENRMStreamingPacer *_pacer;
  ENRMTableStreamingMode _tableStreamingMode;
  ENRMCodeBlockStreamingMode _codeBlockStreamingMode;
  ENRMMediaStreamingMode _mediaStreamingMode;
  // Render requested during this mount transaction (props or slot ids), run once
  // in finalizeUpdates so a mutation that touches both parses once.
  NSString *_pendingRenderMarkdown;
  // The slot ids changed: Fabric mounts or unmounts the React child in this
  // transaction, so the native block it replaces must leave in the same one.
  BOOL _pendingRenderSynchronously;
  // Slot heights changed in this transaction; compare against the committed
  // frame in finalizeUpdates, when the new layout metrics have landed.
  BOOL _pendingSlotHeightCheck;
  // Trailing code block whose closing fence hasn't streamed in yet, if any.
  ENRMCodeBlockSegment *_pendingCodeBlockSegment;
  ENRMCodeBlockWrapState *_codeBlockWrapState;

  size_t _renderedStyleFingerprint;
  size_t _pendingStyleFingerprint;

  ENRMLinkContextMenus *_linkContextMenus;
  NSArray<NSString *> *_contextMenuItemTexts;
  NSArray<NSString *> *_contextMenuItemIcons;
  ENRMSelectionMenuConfig _selectionMenuConfig;
  ENRMAccessibilityLabels *_accessibilityLabels;
  ENRMSelectionMenuLabels _selectionMenuLabels;

  ENRMDynamicBlockProps *_dynamicBlockProps;

  ENRMSpoilerOverlay _spoilerOverlay;

  NSLineBreakStrategy _lineBreakStrategy;

  ENRMWritingDirectionMode _writingDirectionMode;
  NSWritingDirection _resolvedLayoutDirection;

  ENRMLaidOutSize _laidOutSize;
  // The markdown the segments were rendered from, published with their size.
  std::shared_ptr<const std::string> _laidOutMarkdown;

  // Reused by the next render on the render queue (see ENRMTextRenderCache); a recycled view
  // starts a new epoch, which drops it.
  ENRMTextRenderCache *_textRenderCache;
  NSUInteger _textRenderCacheEpoch;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<EnrichedMarkdownComponentDescriptor>();
}

+ (ENRMMd4cFlags *)flagsFromProps:(const EnrichedMarkdownMd4cFlagsStruct &)props
{
  return ENRMMd4cFlagsFromProps(props);
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const EnrichedMarkdownProps>();
    _props = defaultProps;

    self.backgroundColor = [RCTUIColor clearColor];
    _parser = [[ENRMMarkdownParser alloc] init];
    _md4cFlags = [EnrichedMarkdown flagsFromProps:defaultProps->md4cFlags];
    _isGFM = defaultProps->isGFM;
    _linkRegex = ENRMLinkRegexConfigFromProps(defaultProps->linkRecognition.text);
    _inlineCodeLinkRegex = ENRMLinkRegexConfigFromProps(defaultProps->linkRecognition.inlineCode);
    _segmentViews = [NSMutableArray array];
    _segmentSignatures = [NSMutableArray array];
    _slotLayer = [[ENRMBlockSlotLayerView alloc] initWithFrame:self.bounds];
    _slotLayer.backgroundColor = [RCTUIColor clearColor];
#if !TARGET_OS_OSX
    _slotLayer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
#else
    _slotLayer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
#endif
    [self addSubview:_slotLayer];
    __weak __typeof(self) weakLatexSelf = self;
    _latexErrorCoordinator =
        [[ENRMLatexErrorCoordinator alloc] initWithEmit:^BOOL(NSString *source, NSString *message, BOOL displayMode) {
          __typeof(self) strongSelf = weakLatexSelf;
          if (!strongSelf)
            return NO;
          auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(strongSelf->_eventEmitter);
          if (!emitter)
            return NO;
          emitter->onLatexError({
              .source = std::string(source.UTF8String ?: ""),
              .message = std::string(message.UTF8String ?: ""),
              .displayMode = displayMode ? true : false,
          });
          return YES;
        }];
    _dirtyFlags = ENRMDirtyNone;
    [self configureSegmentViewRegistry];

    _renderCoordinator =
        [[ENRMAsyncRenderCoordinator alloc] initWithQueueLabel:"com.swmansion.enriched.markdown.container.render"];

    _maxFontSizeMultiplier = 0;
    _allowTrailingMargin = NO;
    _selectable = YES;
    _enableLinkPreview = YES;
    _enableTaskListItemToggle = YES;
    _enableImagePress = NO;
    __weak EnrichedMarkdown *weakWrapSelf = self;
    _codeBlockWrapState = [[ENRMCodeBlockWrapState alloc]
        initWithCodeBlockViews:^{
          NSMutableArray<ENRMCodeBlockContainerView *> *views = [NSMutableArray array];
          EnrichedMarkdown *strongSelf = weakWrapSelf;
          if (strongSelf) {
            ENRMCollectCodeBlockViews(strongSelf->_segmentViews, views);
          }
          return views;
        }
        onHeightChanged:^{
          EnrichedMarkdown *strongSelf = weakWrapSelf;
          [strongSelf setNeedsLayout];
          [strongSelf requestHeightUpdate];
        }];
    _enableTextPress = NO;
    _dynamicBlockProps = [[ENRMDynamicBlockProps alloc] init];
    _linkContextMenus = [[ENRMLinkContextMenus alloc] init];
    __weak EnrichedMarkdown *weakMenuSelf = self;
    _linkContextMenus.onPress = ^(NSString *url, NSString *pattern, NSString *itemText) {
      [weakMenuSelf emitLinkContextMenuItemPress:itemText pattern:pattern url:url];
    };
    _dynamicBlockProps.linkContextMenus = _linkContextMenus;
    _streaming = NO;
    _streamingFade = YES;
    __weak EnrichedMarkdown *weakPacingSelf = self;
    _pacer = [[ENRMStreamingPacer alloc]
        initWithReveal:^(NSString *markdown) { [weakPacingSelf renderMarkdownContent:markdown]; }
        done:^{
          EnrichedMarkdown *strongSelf = weakPacingSelf;
          [strongSelf stopStreaming];
          [strongSelf renderMarkdownContent:strongSelf->_pacer.markdown];
        }];
    _tableStreamingMode = ENRMTableStreamingModeProgressive;
    _codeBlockStreamingMode = ENRMCodeBlockStreamingModeProgressive;
    _mediaStreamingMode = ENRMMediaStreamingModeProgressive;
    _selectionMenuConfig = (ENRMSelectionMenuConfig){.copyAsMarkdown = YES, .copyImageURL = YES};
    _lineBreakStrategy = NSLineBreakStrategyNone;
    _writingDirectionMode = ENRMWritingDirectionModeFirstStrong;
    _resolvedLayoutDirection =
        [[RCTI18nUtil sharedInstance] isRTL] ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;

    _fontScaleObserver = [[FontScaleObserver alloc] init];
    _textRenderCache = [[ENRMTextRenderCache alloc] init];
    __weak EnrichedMarkdown *weakSelf = self;
    _blockSlotReveal =
        [[ENRMBlockSlotRevealController alloc] initWithFrameHandler:^{ [weakSelf stepBlockSlotReveal]; }];
    // Text segments follow the scroll views themselves.
    _visibleArea = [[ENRMVisibleArea alloc] initWithView:self onChange:^{ [weakSelf updateDrawnBlocks]; }];
    _drawnVisibleRect = CGRectNull;
    _undrawnSegments = [NSHashTable weakObjectsHashTable];
    _fontScaleObserver.onChange = ^{
      EnrichedMarkdown *strongSelf = weakSelf;
      if (!strongSelf)
        return;
      if (strongSelf->_config != nil) {
        [strongSelf->_config setFontScaleMultiplier:strongSelf->_fontScaleObserver.effectiveFontScale];
      }
      if (strongSelf->_cachedMarkdown != nil && strongSelf->_cachedMarkdown.length > 0) {
        strongSelf->_dirtyFlags |= ENRMDirtyRecreateSegments | ENRMDirtyForceHeight;
        [strongSelf renderMarkdownContent:strongSelf->_cachedMarkdown];
      }
    };
  }
  return self;
}

- (void)configureSegmentViewRegistry
{
  __weak EnrichedMarkdown *weakSelf = self;
  NSMutableArray<ENRMSegmentViewHandler *> *handlers = [NSMutableArray array];

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindText
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[EnrichedMarkdownInternalText class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (!strongSelf) {
                              return [[RCTUIView alloc] init];
                            }

                            EnrichedMarkdownInternalText *view =
                                [strongSelf createTextViewForRenderedSegment:segment.textResult];
                            [strongSelf configureStreamingEffectsOfTextSegment:view];
                            [strongSelf animateTextView:view fromTailStart:0];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (strongSelf) {
                              [strongSelf updateTextView:(EnrichedMarkdownInternalText *)view
                                     withRenderedSegment:segment.textResult];
                            }
                          }]];

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindTable
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[TableContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (!strongSelf) {
                              return [[RCTUIView alloc] init];
                            }

                            TableContainerView *view = [strongSelf createTableViewForSegment:segment.tableSegment];
                            [strongSelf animateBlockViewIfNeeded:view];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (strongSelf) {
                              [strongSelf updateTableView:(TableContainerView *)view withSegment:segment.tableSegment];
                            }
                          }]];

#if ENRICHED_MARKDOWN_MATH
  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindMath
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMMathContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (!strongSelf) {
                              return [[RCTUIView alloc] init];
                            }

                            ENRMMathContainerView *view =
                                [strongSelf createMathViewForSegment:(ENRMMathSegment *)segment.mathSegment];
                            [strongSelf animateBlockViewIfNeeded:view];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            [(ENRMMathContainerView *)view applyLatex:((ENRMMathSegment *)segment.mathSegment).latex];
                          }]];
#endif

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindCodeBlock
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMCodeBlockContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (!strongSelf) {
                              return [[RCTUIView alloc] init];
                            }

                            ENRMCodeBlockContainerView *view =
                                [strongSelf createCodeBlockViewForSegment:segment.codeBlockSegment];
                            [strongSelf animateBlockViewIfNeeded:view];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            ENRMCodeBlockContainerView *codeBlockView = (ENRMCodeBlockContainerView *)view;
                            codeBlockView.pending =
                                strongSelf && segment.codeBlockSegment == strongSelf->_pendingCodeBlockSegment;
                            [codeBlockView applyCodeBlockNode:segment.codeBlockSegment.codeBlockNode];
                          }]];

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindBlockquote
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMBlockquoteContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (!strongSelf) {
                              return [[RCTUIView alloc] init];
                            }

                            ENRMBlockquoteContainerView *view =
                                [strongSelf createBlockquoteViewForSegment:segment.blockquoteSegment];
                            [strongSelf animateBlockViewIfNeeded:view];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            [(ENRMBlockquoteContainerView *)view
                                applyBlockquoteNode:segment.blockquoteSegment.blockquoteNode];
                          }]];

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindBlockSlot
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMBlockSlotSegmentView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            ENRMBlockSlotSegmentView *view = [[ENRMBlockSlotSegmentView alloc] init];
                            view.slotId = segment.blockSlotSegment.slotId;
                            view.kind = segment.blockSlotSegment.kind;
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (strongSelf) {
                              view.slotHeight = strongSelf->_blockSlotHeights[view.slotId].doubleValue;
                            }
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            ENRMBlockSlotSegmentView *slotView = (ENRMBlockSlotSegmentView *)view;
                            slotView.slotId = segment.blockSlotSegment.slotId;
                            slotView.kind = segment.blockSlotSegment.kind;
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (strongSelf) {
                              slotView.slotHeight = strongSelf->_blockSlotHeights[slotView.slotId].doubleValue;
                            }
                          }]];

#if ENRICHED_MARKDOWN_VIDEO
  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindVideo
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMVideoContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            EnrichedMarkdown *strongSelf = weakSelf;
                            if (!strongSelf) {
                              return [[RCTUIView alloc] init];
                            }

                            ENRMVideoContainerView *view =
                                [[ENRMVideoContainerView alloc] initWithConfig:strongSelf->_config];
                            view.dynamicProps = strongSelf->_dynamicBlockProps;
                            [view applyVideoNode:segment.videoSegment.videoNode];
                            [strongSelf animateBlockViewIfNeeded:view];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            ENRMVideoContainerView *videoView = (ENRMVideoContainerView *)view;
                            [videoView applyVideoNode:segment.videoSegment.videoNode];
                            [videoView reapplyStyle];
                          }]];
#endif

  _segmentViewRegistry = [[ENRMSegmentViewRegistry alloc] initWithHandlers:handlers];
}

- (ENRMBlockquoteContainerView *)createBlockquoteViewForSegment:(ENRMBlockquoteSegment *)blockquoteSegment
{
  ENRMBlockquoteContainerView *view = [[ENRMBlockquoteContainerView alloc] initWithConfig:_config];
  view.allowFontScaling = _fontScaleObserver.allowFontScaling;
  view.lineBreakStrategy = _lineBreakStrategy;
  view.dynamicProps = _dynamicBlockProps;
  view.accessibilityLabels = _accessibilityLabels;

  __weak EnrichedMarkdown *weakSelf = self;
  view.onCopyPress = ^(NSString *code, NSString *language) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf)
      [strongSelf emitCopyPress:code language:language];
  };
  view.onCodeBlockPress = ^(NSString *code, NSString *language) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf)
      [strongSelf emitCodeBlockPress:code language:language];
  };
  view.onLinkPress = ^(NSString *url) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf && url)
      [strongSelf emitLinkPress:url];
  };
  view.onLinkLongPress = ^(NSString *url) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf && url)
      [strongSelf emitLinkLongPress:url];
  };

  view.onImagePress = ^(NSString *url, NSString *altText) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf && strongSelf->_enableImagePress && url)
      [strongSelf emitImagePress:url altText:altText];
  };
  view.onTextPress = ^(NSInteger index, NSString *text) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf && strongSelf->_enableTextPress)
      [strongSelf emitTextPress:index text:text];
  };

  [view applyBlockquoteNode:blockquoteSegment.blockquoteNode];
  return view;
}

/// The box the segments actually live in: the component frame inset by the
/// `containerStyle` border and padding (`LayoutMetrics::getContentFrame`).
///
/// Yoga hands `measureContent` an available size that already excludes those
/// insets and then adds them back to the frame it commits, so laying the
/// segments out against `self.bounds` would stack them over the padding and
/// across the border while the space Yoga reserved for the content stays blank
/// at the bottom. Unlike `EnrichedMarkdownText`, the segments are attached to
/// the component view itself rather than to `contentView`, so nothing applies
/// the insets for us.
///
/// Taken from `_layoutMetrics` rather than recomputed off `self.bounds`:
/// `prepareForRecycle` resets the metrics but leaves the bounds behind, so the
/// two do not always agree. The box is empty both before the first layout
/// metrics arrive and when the insets consume the whole component width; neither
/// may fall back to `self.bounds`, which is the padded border box the segments
/// must not be drawn across, so an over-constrained box clamps to zero and
/// callers skip laying out at all.
- (CGRect)contentBounds
{
  CGRect box = RCTCGRectFromRect(_layoutMetrics.getContentFrame());
  box.size.width = MAX(box.size.width, 0);
  box.size.height = MAX(box.size.height, 0);
  return box;
}

// The size `measureSize:` reports for a laid-out content size: whole pixels, no wider than the width.
static CGSize ENRMRoundedContentSize(CGSize contentSize, CGFloat width)
{
  CGFloat scale = RCTScreenScale();
  return CGSizeMake(MIN(ceil(contentSize.width * scale) / scale, width), ceil(contentSize.height * scale) / scale);
}

// Every layout of the segments also refreshes the size the shadow node may take
// (laidOutSizeForWidth:), whichever path laid them out before asking for a new height.
- (CGSize)computeSegmentLayoutForWidth:(CGFloat)width applyFrames:(BOOL)applyFrames
{
  if (_segmentViews.count == 0) {
    _laidOutSize.clear();
    return CGSizeZero;
  }

  if (applyFrames) {
    CGFloat overhang = MAX(_config.tableHorizontalOverflow, 0);
    BOOL needsOverhang = NO;
    if (overhang > 0) {
      for (RCTUIView *seg in _segmentViews) {
        if ([seg isKindOfClass:[TableContainerView class]]) {
          needsOverhang = YES;
          break;
        }
      }
    }
#if TARGET_OS_OSX
    BOOL isClipping = self.layer.masksToBounds;
    if (isClipping && needsOverhang)
      self.layer.masksToBounds = NO;
    else if (!isClipping && !needsOverhang)
      self.layer.masksToBounds = YES;
#else
    if (self.clipsToBounds != !needsOverhang)
      self.clipsToBounds = !needsOverhang;
#endif
  }

  __block CGFloat yOffset = 0.0;
  __block CGFloat maxContentWidth = 0.0;
  const NSUInteger lastIndex = _segmentViews.count - 1;
  // Frames are stacked in the component's own coordinate space, so the content
  // origin (containerStyle border + padding) shifts every segment. yOffset stays
  // content-relative because it doubles as the measured content height.
  const CGPoint contentOrigin = applyFrames ? [self contentBounds].origin : CGPointZero;

  [_segmentViews enumerateObjectsUsingBlock:^(RCTUIView *segment, NSUInteger i, BOOL *stop) {
    const BOOL isLast = (i == lastIndex);
    const BOOL shouldAddBottomMargin = (!isLast || _allowTrailingMargin);

    CGFloat segmentHeight = 0;
    const BOOL isTable = [segment isKindOfClass:[TableContainerView class]];

    if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      EnrichedMarkdownInternalText *textView = (EnrichedMarkdownInternalText *)segment;
      textView.allowTrailingMargin = shouldAddBottomMargin;
      CGSize textSize = [textView measureSize:width];
      segmentHeight = textSize.height;
      maxContentWidth = MAX(maxContentWidth, textSize.width);

    } else if (isTable) {
      yOffset += _config.tableMarginTop;
      segmentHeight = [(TableContainerView *)segment measureHeight:width];
      maxContentWidth = width;
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[ENRMMathContainerView class]]) {
      yOffset += _config.mathMarginTop;
      segmentHeight = [(ENRMMathContainerView *)segment measureHeight:width];
      maxContentWidth = width;
    }
#endif
    else if ([segment isKindOfClass:[ENRMCodeBlockContainerView class]]) {
      yOffset += _config.codeBlockMarginTop;
      segmentHeight = [(ENRMCodeBlockContainerView *)segment measureHeight:width];
      maxContentWidth = width;
    } else if ([segment isKindOfClass:[ENRMBlockquoteContainerView class]]) {
      yOffset += _config.blockquoteMarginTop;
      segmentHeight = [(ENRMBlockquoteContainerView *)segment measureHeight:width];
      maxContentWidth = width;
    } else if ([segment isKindOfClass:[ENRMBlockSlotSegmentView class]]) {
      ENRMBlockSlotSegmentView *slotView = (ENRMBlockSlotSegmentView *)segment;
      yOffset += ENRMBlockSlotMarginTop(slotView.kind, _config);
      // Measurement reserves the full height; the stack follows the grow-in.
      segmentHeight = applyFrames ? slotView.revealedHeight : [slotView measureHeight:width];
      maxContentWidth = width;
    }
#if ENRICHED_MARKDOWN_VIDEO
    else if ([segment isKindOfClass:[ENRMVideoContainerView class]]) {
      yOffset += _config.videoMarginTop;
      segmentHeight = [(ENRMVideoContainerView *)segment measureHeight:width];
      maxContentWidth = width;
    }
#endif

    if (applyFrames) {
      CGFloat segmentX = contentOrigin.x;
      CGFloat segmentWidth = width;
      if (isTable) {
        CGFloat overhang = MAX(_config.tableHorizontalOverflow, 0);
        if (overhang > 0) {
          segmentX = contentOrigin.x - overhang;
          segmentWidth = width + overhang * 2;
        }
      }
      CGRect segmentFrame = CGRectMake(segmentX, contentOrigin.y + yOffset, segmentWidth, segmentHeight);
      segment.frame = segmentFrame;
#if TARGET_OS_OSX
      if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
        EnrichedMarkdownInternalText *textSeg = (EnrichedMarkdownInternalText *)segment;
        textSeg.textView.frame = segment.bounds;
        textSeg.textView.textContainer.size = CGSizeMake(width, CGFLOAT_MAX);
        [textSeg.textView.layoutManager ensureLayoutForTextContainer:textSeg.textView.textContainer];
        ENRMSetNeedsDisplay(textSeg.textView);
      }
#endif
    }

    yOffset += segmentHeight;

    if ([segment isKindOfClass:[TableContainerView class]] && shouldAddBottomMargin) {
      yOffset += _config.tableMarginBottom;
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[ENRMMathContainerView class]] && shouldAddBottomMargin) {
      yOffset += _config.mathMarginBottom;
    }
#endif
    else if ([segment isKindOfClass:[ENRMCodeBlockContainerView class]] && shouldAddBottomMargin) {
      yOffset += _config.codeBlockMarginBottom;
    } else if ([segment isKindOfClass:[ENRMBlockquoteContainerView class]] && shouldAddBottomMargin) {
      yOffset += _config.blockquoteMarginBottom;
    } else if ([segment isKindOfClass:[ENRMBlockSlotSegmentView class]] && shouldAddBottomMargin) {
      yOffset += ENRMBlockSlotMarginBottom(((ENRMBlockSlotSegmentView *)segment).kind, _config);
    }
#if ENRICHED_MARKDOWN_VIDEO
    else if ([segment isKindOfClass:[ENRMVideoContainerView class]] && shouldAddBottomMargin) {
      yOffset += _config.videoMarginBottom;
    }
#endif
  }];

  if (applyFrames) {
    // Segments moved by the ones above them show another part of the document.
    [self updateDrawnSegments];
  }

  if (yOffset > 0) {
    _laidOutSize.store(width, ENRMRoundedContentSize(CGSizeMake(maxContentWidth, yOffset), width), _laidOutMarkdown);
  } else {
    _laidOutSize.clear();
  }
  return CGSizeMake(maxContentWidth, yOffset);
}

- (CGSize)measureSize:(CGFloat)maxWidth
{
  CGFloat defaultHeight = UIFontLineHeight([UIFont systemFontOfSize:16.0]);
  CGSize contentSize = [self computeSegmentLayoutForWidth:maxWidth applyFrames:NO];
  if (contentSize.height == 0)
    return CGSizeMake(maxWidth, defaultHeight);

  return ENRMRoundedContentSize(contentSize, maxWidth);
}

- (CGSize)laidOutSizeForWidth:(CGFloat)width
             pointScaleFactor:(CGFloat)pointScaleFactor
                     markdown:(std::string_view)markdown
{
  return _laidOutSize.sizeFor(width, pointScaleFactor, markdown);
}

- (BOOL)hasRenderedMarkdown:(NSString *)markdown
{
  return _renderedMarkdown != nil && [_renderedMarkdown isEqualToString:markdown];
}

- (BOOL)hasRenderedWithStyleFingerprint:(size_t)fingerprint
{
  return _renderedStyleFingerprint == fingerprint;
}

- (BOOL)renderedSegmentsChangeTopology:(NSArray<ENRMRenderedSegment *> *)renderedSegments
{
  if (renderedSegments.count != _segmentViews.count) {
    return YES;
  }

  for (NSUInteger index = 0; index < renderedSegments.count; index++) {
    if (![_segmentViewRegistry view:_segmentViews[index] matchesSegment:renderedSegments[index]]) {
      return YES;
    }
  }

  return NO;
}

- (void)updateState:(const facebook::react::State::Shared &)state
           oldState:(const facebook::react::State::Shared &)oldState
{
  _state = std::static_pointer_cast<const EnrichedMarkdownShadowNode::ConcreteState>(state);

  if (oldState == nullptr) {
    [self requestHeightUpdate];
  }
  [self applyBlockSlotPlacementsFromState];
}

// The shadow node says which slot children exist and how tall each placed one
// is. New ids need a parse that stamps them; new heights only need a relayout.
// Both are deferred to finalizeUpdates: the parse so it coalesces with the one
// updateProps asked for in the same transaction, the height check so it runs
// against the layout metrics this transaction delivers right after the state.
- (void)applyBlockSlotPlacementsFromState
{
  if (!_state) {
    return;
  }
  const auto &placements = _state->getData().getSlotPlacements();
  NSMutableSet<NSString *> *ids = [NSMutableSet setWithCapacity:placements.size()];
  NSMutableDictionary<NSString *, NSNumber *> *heights = [NSMutableDictionary dictionaryWithCapacity:placements.size()];
  for (const auto &placement : placements) {
    NSString *slotId = @(placement.id.c_str());
    [ids addObject:slotId];
    if (placement.placed) {
      heights[slotId] = @(placement.height);
    }
  }

  BOOL idsChanged = ![ids isEqualToSet:(_activeBlockSlotIds ?: [NSSet set])];
  BOOL heightsChanged = ![heights isEqualToDictionary:(_blockSlotHeights ?: @{})];
  _activeBlockSlotIds = ids.count > 0 ? [ids copy] : nil;
  [_blockSlotReveal keepSlotIds:ids];
  _blockSlotHeights = heights.count > 0 ? [heights copy] : nil;
  [self updateBlockSlotHeights:heights];

  if (idsChanged && (_pendingRenderMarkdown || _cachedMarkdown.length > 0)) {
    _dirtyFlags |= ENRMDirtyForceHeight;
    _pendingRenderMarkdown = _pendingRenderMarkdown ?: _cachedMarkdown;
    _pendingRenderSynchronously = YES;
  } else if (heightsChanged) {
    [self setNeedsLayout];
    _pendingSlotHeightCheck = YES;
  }
}

- (void)finalizeUpdates:(RNComponentViewUpdateMask)updateMask
{
  [super finalizeUpdates:updateMask];

  if (_pendingRenderMarkdown) {
    NSString *markdown = _pendingRenderMarkdown;
    // The first content renders inline: Yoga has already laid the view out at
    // its measured size, so an async render would show it empty (#1131).
    BOOL synchronously = _pendingRenderSynchronously || _renderedMarkdown.length == 0;
    _pendingRenderMarkdown = nil;
    _pendingRenderSynchronously = NO;
    _pendingSlotHeightCheck = NO;
    [self renderMarkdownContent:markdown synchronously:synchronously];
    return;
  }
  if (_pendingSlotHeightCheck) {
    _pendingSlotHeightCheck = NO;
    CGRect contentBounds = [self contentBounds];
    if (contentBounds.size.width > 0) {
      CGSize measured = [self measureSize:contentBounds.size.width];
      if (needsHeightUpdate(measured, contentBounds)) {
        [self requestHeightUpdate];
      }
    }
  }
}

- (void)bindBlockSlotViews
{
  NSMutableDictionary<NSString *, RCTUIView *> *views = [NSMutableDictionary dictionary];
  for (RCTUIView *child in _slotLayer.subviews) {
    if ([child isKindOfClass:[EnrichedMarkdownBlockSlot class]]) {
      views[((EnrichedMarkdownBlockSlot *)child).slotId] = child;
    }
  }
  ENRMBindBlockSlotViews(_segmentViews, views);
  // A child mounted mid grow-in is placed and clipped before it draws.
  [self applyBlockSlotReveal];
}

// A root slot getting its first height while streaming grows into place
// (ENRMBlockSlotRevealController) instead of pushing the text below it down at once.
- (void)updateBlockSlotHeights:(NSDictionary<NSString *, NSNumber *> *)heights
{
  ENRMApplyBlockSlotHeights(_segmentViews, heights);
  [_blockSlotReveal noteHeights:heights inSegments:_segmentViews reveal:[self fadesArrivals]];
  [self applyBlockSlotReveal];
}

- (void)applyBlockSlotReveal
{
  [_blockSlotReveal applyToSegments:_segmentViews slotViews:_slotLayer.subviews];
}

- (void)stepBlockSlotReveal
{
  [self applyBlockSlotReveal];
  const CGFloat width = [self contentBounds].size.width;
  if (width > 0) {
    [self computeSegmentLayoutForWidth:width applyFrames:YES];
  }
}

- (void)mountChildComponentView:(RCTUIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  NSInteger clamped = MAX(0, MIN(index, (NSInteger)_slotLayer.subviews.count));
#if !TARGET_OS_OSX
  [_slotLayer insertSubview:childComponentView atIndex:clamped];
#else
  if (clamped >= (NSInteger)_slotLayer.subviews.count) {
    [_slotLayer addSubview:childComponentView];
  } else {
    [_slotLayer addSubview:childComponentView
                positioned:NSWindowBelow
                relativeTo:_slotLayer.subviews[(NSUInteger)clamped]];
  }
#endif
  [self bindBlockSlotViews];
}

- (void)unmountChildComponentView:(RCTUIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  [childComponentView removeFromSuperview];
  [self bindBlockSlotViews];
}

// Where segments live: beside the slot layer. RCTViewComponentView moves its
// subviews into a container view for some styles (overflow with a shadow,
// filters), and the slot layer moves with them.
- (RCTUIView *)segmentContainer
{
  return (RCTUIView *)_slotLayer.superview ?: self;
}

- (void)bringSlotLayerToFront
{
  RCTUIView *container = [self segmentContainer];
#if !TARGET_OS_OSX
  [container bringSubviewToFront:_slotLayer];
#else
  if (container.subviews.lastObject != _slotLayer) {
    [_slotLayer removeFromSuperviewWithoutNeedingDisplay];
    [container addSubview:_slotLayer];
  }
#endif
}

- (nullable RCTUIView *)mountedBlockSlotViewForId:(NSString *)slotId
{
  for (RCTUIView *child in _slotLayer.subviews) {
    if ([child isKindOfClass:[EnrichedMarkdownBlockSlot class]] &&
        [((EnrichedMarkdownBlockSlot *)child).slotId isEqualToString:slotId]) {
      return child;
    }
  }
  return nil;
}

/// Picks up the Yoga-resolved direction inherited from any ancestor `direction`
/// style. In FirstStrong mode the direction feeds the neutral-paragraph
/// fallback, so a change requires segment recreation.
- (void)updateLayoutMetrics:(const LayoutMetrics &)layoutMetrics
           oldLayoutMetrics:(const LayoutMetrics &)oldLayoutMetrics
{
  [super updateLayoutMetrics:layoutMetrics oldLayoutMetrics:oldLayoutMetrics];

  NSWritingDirection resolved = _resolvedLayoutDirection;
  if (layoutMetrics.layoutDirection == LayoutDirection::RightToLeft) {
    resolved = NSWritingDirectionRightToLeft;
  } else if (layoutMetrics.layoutDirection == LayoutDirection::LeftToRight) {
    resolved = NSWritingDirectionLeftToRight;
  }

  if (resolved != _resolvedLayoutDirection) {
    _resolvedLayoutDirection = resolved;
    [self pushWritingDirectionToTableSegments];
    if (_writingDirectionMode == ENRMWritingDirectionModeFirstStrong && _cachedMarkdown.length > 0) {
      _dirtyFlags |= ENRMDirtyRecreateSegments | ENRMDirtyForceHeight;
      [self renderMarkdownContent:_cachedMarkdown];
    }
  }
}

- (void)pushWritingDirectionToTableSegments
{
  for (RCTUIView *segment in _segmentViews) {
    if ([segment isKindOfClass:[TableContainerView class]]) {
      TableContainerView *tableView = (TableContainerView *)segment;
      tableView.writingDirectionMode = _writingDirectionMode;
      tableView.resolvedLayoutDirection = _resolvedLayoutDirection;
    }
  }
}

- (void)pushAccessibilityLabelsToSegments
{
  for (RCTUIView *segment in _segmentViews) {
    if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      ((EnrichedMarkdownInternalText *)segment).accessibilityLabels = _accessibilityLabels;
    } else if ([segment isKindOfClass:[TableContainerView class]]) {
      ((TableContainerView *)segment).accessibilityLabels = _accessibilityLabels;
    } else if ([segment isKindOfClass:[ENRMBlockquoteContainerView class]]) {
      ((ENRMBlockquoteContainerView *)segment).accessibilityLabels = _accessibilityLabels;
    } else if ([segment isKindOfClass:[ENRMCodeBlockContainerView class]]) {
      ((ENRMCodeBlockContainerView *)segment).accessibilityLabels = _accessibilityLabels;
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[ENRMMathContainerView class]]) {
      ((ENRMMathContainerView *)segment).accessibilityLabels = _accessibilityLabels;
    }
#endif
  }
}

- (void)requestHeightUpdate
{
  ENRMRequestHeightUpdate<EnrichedMarkdownState>(_state, _heightUpdateCounter, self);
}

// A block image in one of the text segments resolved its box height after
// loading (maxHeight/aspectRatio sizing). The shadow node measured — and
// cached — this markdown with the pre-load fallback height, so drop those
// entries, re-stack segments, and re-measure.
- (void)imageAttachmentDidResolveLayout
{
  if (_renderedMarkdown.length > 0) {
    MeasurementCache::shared().removeMatchingMarkdown(std::string(_renderedMarkdown.UTF8String));
  }

  CGRect contentBounds = [self contentBounds];
  if (contentBounds.size.width > 0) {
    [self setNeedsLayout];
    CGSize measured = [self measureSize:contentBounds.size.width];
    if (needsHeightUpdate(measured, contentBounds)) {
      [self requestHeightUpdate];
    }
  }
}

- (void)renderMarkdownContent:(NSString *)markdownString
{
  [self renderMarkdownContent:markdownString synchronously:NO];
}

// Parses and lays the document out on the render queue and applies the result
// on the main queue, unless `synchronously`: then both run here, in the current
// mount transaction, and any render in flight is dropped (the Android host's
// renderSynchronously). The parse memo keeps the inline parse cheap.
- (void)renderMarkdownContent:(NSString *)markdownString synchronously:(BOOL)synchronously
{
  if (_renderCoordinator.blockAsyncRender)
    return;

  _cachedMarkdown = [markdownString copy];

  StyleConfig *config = [_config copy];
  ENRMMarkdownParser *parser = _parser;
  ENRMMd4cFlags *md4cFlags = [_md4cFlags copy];
  BOOL isGFM = _isGFM;
  ENRMLinkRegexConfig *linkRegex = _linkRegex;
  ENRMLinkRegexConfig *inlineCodeLinkRegex = _inlineCodeLinkRegex;

  BOOL allowFontScaling = _fontScaleObserver.allowFontScaling;
  CGFloat maxFontSizeMultiplier = _maxFontSizeMultiplier;
  BOOL allowTrailingMargin = _allowTrailingMargin;
  BOOL streaming = _streaming;
  ENRMTableStreamingMode tableStreamingMode = _tableStreamingMode;
  ENRMCodeBlockStreamingMode codeBlockStreamingMode = _codeBlockStreamingMode;
  ENRMMediaStreamingMode mediaStreamingMode = _mediaStreamingMode;
  NSLineBreakStrategy lineBreakStrategy = _lineBreakStrategy;
  ENRMWritingDirectionMode writingDirectionMode = _writingDirectionMode;
  NSWritingDirection resolvedLayoutDirection = _resolvedLayoutDirection;
  NSSet<NSString *> *activeBlockSlotIds = _activeBlockSlotIds;
  BOOL annotateImages = config.imageSourceOverrides.count > 0;
  // The render queue owns the cache; a synchronous render leaves it alone.
  ENRMTextRenderCache *textRenderCache = synchronously ? nil : _textRenderCache;
  const BOOL clearTextRenderCache = (_dirtyFlags & ENRMDirtyRecreateSegments) != 0;
  NSArray *textRenderKey =
      ENRMTextRenderKey(config, _pendingStyleFingerprint, allowFontScaling, maxFontSizeMultiplier, lineBreakStrategy,
                        writingDirectionMode, resolvedLayoutDirection, _textRenderCacheEpoch);

  __block NSArray<ENRMRenderedSegment *> *renderedSegments = nil;
  __block NSString *renderableMarkdown = nil;
  __block BOOL endsInsideOpenCodeFence = NO;

  BOOL (^render)(void) = ^BOOL {
    renderableMarkdown = streaming ? ENRMRenderableMarkdownForStreaming(markdownString, md4cFlags, tableStreamingMode,
                                                                        codeBlockStreamingMode, mediaStreamingMode,
                                                                        &endsInsideOpenCodeFence)
                                   : markdownString;

    if (renderableMarkdown.length == 0) {
      renderedSegments = @[];
      return YES;
    }

    MarkdownASTNode *ast = [parser parseMarkdown:renderableMarkdown
                                           flags:md4cFlags
                                           isGFM:isGFM
                                       linkRegex:linkRegex
                             inlineCodeLinkRegex:inlineCodeLinkRegex
                              activeBlockSlotIds:activeBlockSlotIds
                                  annotateImages:annotateImages];
    if (!ast)
      return NO;

    if (textRenderCache) {
      if (clearTextRenderCache) {
        [textRenderCache clear];
      }
      [textRenderCache beginRenderWithKey:textRenderKey];
      renderedSegments = ENRMRenderSegmentsFromASTCached(ast, config, allowTrailingMargin, allowFontScaling,
                                                         maxFontSizeMultiplier, lineBreakStrategy, writingDirectionMode,
                                                         resolvedLayoutDirection, textRenderCache);
      [textRenderCache endRender];
      return YES;
    }
    renderedSegments = ENRMRenderSegmentsFromAST(ast, config, allowTrailingMargin, allowFontScaling,
                                                 maxFontSizeMultiplier, lineBreakStrategy,
                                                 /*blockquoteContent*/ NO);
    for (ENRMRenderedSegment *segment in renderedSegments) {
      if (segment.kind == ENRMSegmentKindText && segment.textResult) {
        ENRMApplyWritingDirectionMode(segment.textResult.attributedText, writingDirectionMode, resolvedLayoutDirection);
      }
    }
    return YES;
  };
  // What this render answers, taken now: an older render can still apply after a
  // newer one is scheduled, and must not claim the newer one's style or flags.
  const size_t styleFingerprint = _pendingStyleFingerprint;
  const ENRMDirtyFlags dirtyFlags = _dirtyFlags & (ENRMDirtyRecreateSegments | ENRMDirtyForceHeight);
  dispatch_block_t apply = ^{
    self->_renderedStyleFingerprint = styleFingerprint;
    self->_laidOutMarkdown = ENRMLaidOutMarkdown(markdownString);
    [self applyRenderedSegments:renderedSegments
               renderedMarkdown:renderableMarkdown
        endsInsideOpenCodeFence:endsInsideOpenCodeFence
                     dirtyFlags:dirtyFlags];
  };

  if (synchronously) {
    [_renderCoordinator invalidate];
    // Its views show revisions the cache never made.
    _textRenderCacheEpoch++;
    // A first render reuses what Yoga's measurement rendered, when it matches.
    NSArray<ENRMRenderedSegment *> *prepared =
        _renderedMarkdown.length == 0 && !streaming
            ? ENRMTakePreparedSegments(
                  {_props, _fontScaleObserver.effectiveFontScale, resolvedLayoutDirection, activeBlockSlotIds})
            : nil;
    if (prepared) {
      renderedSegments = prepared;
      renderableMarkdown = markdownString;
    } else if (!render()) {
      return;
    }
    apply();
    return;
  }
  [_renderCoordinator scheduleRender:render apply:apply];
}

- (NSArray *)parseAndRenderSegments:(NSString *)markdownString
{
  MarkdownASTNode *ast = [_parser parseMarkdown:markdownString
                                          flags:_md4cFlags
                                          isGFM:_isGFM
                                      linkRegex:_linkRegex
                            inlineCodeLinkRegex:_inlineCodeLinkRegex
                             activeBlockSlotIds:_activeBlockSlotIds
                                 annotateImages:_config.imageSourceOverrides.count > 0];
  if (!ast) {
    return nil;
  }

  NSArray<ENRMRenderedSegment *> *segments =
      ENRMRenderSegmentsFromAST(ast, _config, _allowTrailingMargin, _fontScaleObserver.allowFontScaling,
                                _maxFontSizeMultiplier, _lineBreakStrategy, /*blockquoteContent*/ NO);
  for (ENRMRenderedSegment *segment in segments) {
    if (segment.kind == ENRMSegmentKindText && segment.textResult) {
      ENRMApplyWritingDirectionMode(segment.textResult.attributedText, _writingDirectionMode, _resolvedLayoutDirection);
    }
  }
  return segments;
}

/// Synchronous rendering for mock view measurement (no UI updates needed).
- (void)renderMarkdownSynchronously:(NSString *)markdownString
{
  if (!markdownString || markdownString.length == 0) {
    return;
  }

  for (RCTUIView *view in _segmentViews) {
    [view removeFromSuperview];
  }
  [_segmentViews removeAllObjects];
  [_segmentSignatures removeAllObjects];

  _renderCoordinator.blockAsyncRender = YES;
  _cachedMarkdown = [markdownString copy];
  _laidOutMarkdown = ENRMLaidOutMarkdown(markdownString);
  BOOL endsInsideOpenCodeFence = NO;
  NSString *renderableMarkdown =
      _streaming
          ? ENRMRenderableMarkdownForStreaming(markdownString, _md4cFlags, _tableStreamingMode, _codeBlockStreamingMode,
                                               _mediaStreamingMode, &endsInsideOpenCodeFence)
          : markdownString;
  _renderedMarkdown = [renderableMarkdown copy];
  _renderedStyleFingerprint = _pendingStyleFingerprint;

  if (renderableMarkdown.length == 0) {
    return;
  }

  NSArray *renderedSegments = [self parseAndRenderSegments:renderableMarkdown];
  if (!renderedSegments) {
    return;
  }

  [self updatePendingCodeBlockSegment:endsInsideOpenCodeFence segments:renderedSegments];

  for (ENRMRenderedSegment *segment in renderedSegments) {
    RCTUIView *view = [_segmentViewRegistry createViewForSegment:segment];
    [_segmentViews addObject:view];
    [_segmentSignatures addObject:@(segment.signature)];
    [[self segmentContainer] addSubview:view];
  }
  [self bringSlotLayerToFront];
  [self updateBlockSlotHeights:_blockSlotHeights ?: @{}];
  [self bindBlockSlotViews];
}

- (void)updatePendingCodeBlockSegment:(BOOL)endsInsideOpenCodeFence segments:(NSArray<ENRMRenderedSegment *> *)segments
{
  _pendingCodeBlockSegment = nil;
  if (!_streaming || !endsInsideOpenCodeFence) {
    return;
  }
  ENRMRenderedSegment *last = segments.lastObject;
  if (last.kind == ENRMSegmentKindCodeBlock) {
    _pendingCodeBlockSegment = last.codeBlockSegment;
  }
}

/// `scheduledFlags` are the ones set when this render was scheduled: it takes those
/// still set, and flags set since stay for the newer render they belong to.
- (void)applyRenderedSegments:(NSArray *)renderedSegments
             renderedMarkdown:(NSString *)renderedMarkdown
      endsInsideOpenCodeFence:(BOOL)endsInsideOpenCodeFence
                   dirtyFlags:(ENRMDirtyFlags)scheduledFlags
{
  const ENRMDirtyFlags dirtyFlags = scheduledFlags & _dirtyFlags;
  _renderedMarkdown = [renderedMarkdown copy];
  [self updatePendingCodeBlockSegment:endsInsideOpenCodeFence segments:renderedSegments];
  BOOL segmentTopologyChanged = _streaming && [self renderedSegmentsChangeTopology:renderedSegments];

  ENRMSegmentReconciliationResult *result = [ENRMSegmentReconciler reconcileCurrentViews:_segmentViews
      currentSignatures:_segmentSignatures
      renderedSegments:renderedSegments
      reset:(dirtyFlags & ENRMDirtyRecreateSegments) != 0
      createView:^RCTUIView *(ENRMRenderedSegment *segment) {
        return [self->_segmentViewRegistry createViewForSegment:segment];
      }
      updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
        [self->_segmentViewRegistry updateView:view withSegment:segment];
      }
      attachView:^(RCTUIView *view) { [[self segmentContainer] addSubview:view]; }
      removeView:^(RCTUIView *view) { [view removeFromSuperview]; }
      matchesKind:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
        return [self->_segmentViewRegistry view:view matchesSegment:segment];
      }];
  BOOL forceHeightUpdate = (dirtyFlags & ENRMDirtyForceHeight) != 0;
  _dirtyFlags &= ~dirtyFlags;

  _segmentViews = result.views;
  _segmentSignatures = result.signatures;
  _streamEnding = NO;
  if (_streaming) {
    [self settleTextSegmentsBefore:_segmentViews.lastObject];
  }
  // A view that missed a patch gets the whole text from a full render: forgetting its signature
  // makes the reconciler update it then, where it would keep a view whose segment it matches.
  NSIndexSet *missedPatches = ENRMSyncTextRevisions(renderedSegments, _segmentViews);
  if (missedPatches.count > 0) {
    [missedPatches enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) {
      self->_segmentSignatures[i] = @(kENRMUnknownSignature);
    }];
    _textRenderCacheEpoch++;
    [self renderMarkdownContent:_cachedMarkdown];
  }
  [self bringSlotLayerToFront];
  // Recreated placeholders (nested ones in particular) start at zero height; the
  // shadow node only republishes frames when they change, so reapply the last ones.
  [self updateBlockSlotHeights:_blockSlotHeights ?: @{}];
  [self bindBlockSlotViews];

  // A just-closed block has unchanged content, so the reconciler reuses it
  // without an update; sync pending here to trigger its deferred highlight.
  [_segmentViews enumerateObjectsUsingBlock:^(RCTUIView *segment, NSUInteger i, BOOL *stop) {
    if ([segment isKindOfClass:[ENRMCodeBlockContainerView class]]) {
      ((ENRMCodeBlockContainerView *)segment).pending =
          self->_pendingCodeBlockSegment != nil && i == self->_segmentViews.count - 1;
    }
  }];
  [_codeBlockWrapState sync];

  CGRect contentBounds = [self contentBounds];
  if (!self.window) {
    _needsWindowAttachRefresh = contentBounds.size.width <= 0;
  }
  if (contentBounds.size.width > 0) {
    [self setNeedsLayout];

    if (forceHeightUpdate || segmentTopologyChanged) {
      [self computeSegmentLayoutForWidth:contentBounds.size.width applyFrames:YES];
      [self layoutIfNeeded];
      [self requestHeightUpdate];
    } else {
      CGSize measured = [self measureSize:contentBounds.size.width];
      if (needsHeightUpdate(measured, contentBounds)) {
        [self requestHeightUpdate];
      }
    }
  }
}

- (void)configureTextView:(EnrichedMarkdownInternalText *)view withRenderedSegment:(ENRMRenderResult *)segment
{
  const BOOL patches = segment.patchTail && segment.patchBaseRevision == view.renderedRevision;
  if (!patches && !segment.attributedText) {
    // A patch to text this view doesn't show: left for the full render applyRenderedSegments asks for.
    return;
  }
  view.spoilerOverlay = _spoilerOverlay;
  view.allowTrailingMargin = _allowTrailingMargin;
  view.lastElementMarginBottom = segment.lastElementMarginBottom;
  view.accessibilityInfo = segment.accessibilityInfo;
  view.accessibilityLabels = _accessibilityLabels;
  view.textView.selectable = _selectable;
  [_latexErrorCoordinator wireReporters:segment.context.mathReporters];
  if (patches) {
    [view applyAttributedTextPatch:segment.patchTail from:segment.patchStart];
  } else {
    [view applyAttributedText:segment.attributedText context:segment.context];
  }
  view.renderedRevision = segment.revision;

  const auto &selectionProps = *std::static_pointer_cast<EnrichedMarkdownProps const>(self->_props);
  ENRMApplySelectionColor(view.textView, selectionProps.selectionColor);
}

- (EnrichedMarkdownInternalText *)createTextViewForRenderedSegment:(ENRMRenderResult *)segment
{
  EnrichedMarkdownInternalText *view = [[EnrichedMarkdownInternalText alloc] initWithConfig:_config];
  [self configureTextView:view withRenderedSegment:segment];

  ENRMTapRecognizer *tapRecognizer = [[ENRMTapRecognizer alloc] initWithTarget:self action:@selector(textTapped:)];
  [view.textView addGestureRecognizer:tapRecognizer];

#if !TARGET_OS_OSX
  view.textView.delegate = self;
#else
  __weak EnrichedMarkdown *weakSelf = self;
  [view setContextMenuProvider:^NSMenu *_Nullable(NSMenu *baseMenu, NSTextView *textView) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (!strongSelf) {
      return baseMenu;
    }
    NSString *segmentMarkdown = extractMarkdownFromAttributedString(textView.textStorage, textView.selectedRange);
    NSArray<NSMenuItem *> *customItems = ENRMBuildContextMenuItems(
        strongSelf->_contextMenuItemTexts, strongSelf->_contextMenuItemIcons, textView,
        ^(NSString *itemText, NSString *selectedText, NSUInteger selectionStart, NSUInteger selectionEnd) {
          [strongSelf emitContextMenuItemPress:itemText
                                  selectedText:selectedText
                                selectionStart:selectionStart
                                  selectionEnd:selectionEnd];
        });
    return buildEditMenuForSelection(textView.textStorage, textView.selectedRange, segmentMarkdown, strongSelf->_config,
                                     @[ baseMenu ], customItems, strongSelf->_selectionMenuConfig);
  }];
#endif

  return view;
}

- (TableContainerView *)createTableViewForSegment:(ENRMTableSegment *)tableSegment
{
  TableContainerView *tableView = [[TableContainerView alloc] initWithConfig:_config];

  tableView.allowFontScaling = _fontScaleObserver.allowFontScaling;
  tableView.maxFontSizeMultiplier = _maxFontSizeMultiplier;
  tableView.enableLinkPreview = _enableLinkPreview;
  tableView.dynamicProps = _dynamicBlockProps;
  tableView.writingDirectionMode = _writingDirectionMode;
  tableView.resolvedLayoutDirection = _resolvedLayoutDirection;
  tableView.accessibilityLabels = _accessibilityLabels;

  __weak EnrichedMarkdown *weakSelf = self;

  tableView.onLinkPress = ^(NSString *url) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf && url)
      [strongSelf emitLinkPress:url];
  };

  tableView.onLinkLongPress = ^(NSString *url) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf && url)
      [strongSelf emitLinkLongPress:url];
  };

  tableView.onImagePress = ^(NSString *url, NSString *altText) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf && strongSelf->_enableImagePress && url)
      [strongSelf emitImagePress:url altText:altText];
  };

  [tableView applyTableNode:tableSegment.tableNode];

  return tableView;
}

- (void)updateTableView:(TableContainerView *)view withSegment:(ENRMTableSegment *)tableSegment
{
  view.writingDirectionMode = _writingDirectionMode;
  view.resolvedLayoutDirection = _resolvedLayoutDirection;
  NSUInteger previousRowCount = view.rowCount;
  [view applyTableNode:tableSegment.tableNode];

  if ([self fadesArrivals]) {
    [view animateNewRowsFromPreviousCount:previousRowCount duration:0.20];
  }
}

#if ENRICHED_MARKDOWN_MATH
- (ENRMMathContainerView *)createMathViewForSegment:(ENRMMathSegment *)mathSegment
{
  ENRMMathContainerView *mathView = [[ENRMMathContainerView alloc] initWithConfig:_config];
  mathView.dynamicProps = _dynamicBlockProps;
  mathView.accessibilityLabels = _accessibilityLabels;
  ENRMLatexErrorCoordinator *coordinator = _latexErrorCoordinator;
  mathView.onLatexError = ^(NSString *source, NSString *message, BOOL displayMode) {
    [coordinator reportSource:source message:message displayMode:displayMode];
  };
  [mathView applyLatex:mathSegment.latex];
  return mathView;
}
#endif

- (ENRMCodeBlockContainerView *)createCodeBlockViewForSegment:(ENRMCodeBlockSegment *)codeBlockSegment
{
  ENRMCodeBlockContainerView *codeBlockView = [[ENRMCodeBlockContainerView alloc] initWithConfig:_config];
  codeBlockView.dynamicProps = _dynamicBlockProps;
  codeBlockView.accessibilityLabels = _accessibilityLabels;

  __weak EnrichedMarkdown *weakSelf = self;
  codeBlockView.onCopyPress = ^(NSString *code, NSString *language) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf)
      [strongSelf emitCopyPress:code language:language];
  };
  codeBlockView.onCodeBlockPress = ^(NSString *code, NSString *language) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (strongSelf)
      [strongSelf emitCodeBlockPress:code language:language];
  };

  codeBlockView.pending = codeBlockSegment == _pendingCodeBlockSegment;
  [codeBlockView applyCodeBlockNode:codeBlockSegment.codeBlockNode];
  return codeBlockView;
}

- (NSSet<NSNumber *> *)wrappedCodeBlockIndices
{
  return _codeBlockWrapState.indices;
}

// New streamed content fades in, unless the fade is off or Reduce Motion is on.
- (BOOL)fadesArrivals
{
  return _streaming && _streamingFade && !ENRMShouldReduceMotion();
}

- (void)animateBlockViewIfNeeded:(RCTUIView *)view
{
#if !TARGET_OS_OSX
  if (![self fadesArrivals]) {
    return;
  }
  view.alpha = 0.0;
  [UIView animateWithDuration:0.20 animations:^{ view.alpha = 1.0; }];
#endif
}

// Starts a text segment's effects over with the current props.
- (void)configureStreamingEffectsOfTextSegment:(EnrichedMarkdownInternalText *)view
{
#if !TARGET_OS_OSX
  ENRMMarkdownTextView *textView = (ENRMMarkdownTextView *)view.textView;
  ENRMConfigureStreamingEffects(textView.streamingEffects,
                                static_cast<const EnrichedMarkdownProps &>(*_props).streamingConfig);
  [textView streamingEffectsChanged];
#endif
}

- (void)animateTextView:(EnrichedMarkdownInternalText *)view fromTailStart:(NSUInteger)tailStart
{
#if !TARGET_OS_OSX
  if (!_streaming && !_streamEnding) {
    return;
  }
  ENRMStreamingEffects *effects = ((ENRMMarkdownTextView *)view.textView).streamingEffects;
  CFTimeInterval now = CACurrentMediaTime();
  // The text storage, not attributedText: that copies the whole text.
  NSString *text = view.textView.textStorage.string;
  [effects noteArrivalIn:text from:tailStart to:text.length at:now];
  if (_streamEnding) {
    [effects finishAt:now];
  }
  [(ENRMMarkdownTextView *)view.textView streamingEffectsChanged];
#endif
}

// What still animates in text segments settles: all of them once the stream ends, or the ones the
// document's end has left (a gradient follows only the end of the document).
- (void)settleTextSegmentsBefore:(nullable RCTUIView *)last
{
#if !TARGET_OS_OSX
  CFTimeInterval now = CACurrentMediaTime();
  for (RCTUIView *segment in _segmentViews) {
    if (segment == last || ![segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      continue;
    }
    ENRMStreamingEffects *effects =
        ((ENRMMarkdownTextView *)((EnrichedMarkdownInternalText *)segment).textView).streamingEffects;
    if (last == nil ? effects.type != ENRMStreamingEffectNone : effects.type == ENRMStreamingEffectGradient) {
      [effects finishAt:now];
      [(ENRMMarkdownTextView *)((EnrichedMarkdownInternalText *)segment).textView streamingEffectsChanged];
    }
  }
#endif
}

// The stream ended: the next render shows the whole document, and what still animates settles.
- (void)stopStreaming
{
  _streaming = NO;
  _streamEnding = YES;
  if (auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter)) {
    emitter->onStreamingEnd({});
  }
  _dirtyFlags |= ENRMDirtyForceHeight;
  [self finishStreamingAnimations];
  [self settleTextSegmentsBefore:nil];
}

// Shows the blocks still fading in at once.
- (void)finishStreamingAnimations
{
  [_blockSlotReveal cancel];
  [self applyBlockSlotReveal];
  [self setNeedsLayout];
  for (RCTUIView *segment in _segmentViews) {
    if ([segment isKindOfClass:[TableContainerView class]]) {
      [(TableContainerView *)segment finishRowFade];
    } else if (![segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      // A block fading in (animateBlockViewIfNeeded:).
      [segment.layer removeAnimationForKey:@"opacity"];
    }
  }
}

- (void)updateTextView:(EnrichedMarkdownInternalText *)view withRenderedSegment:(ENRMRenderResult *)segment
{
  NSUInteger tailStart = view.textView.textStorage.length;
  [self configureTextView:view withRenderedSegment:segment];
  [self animateTextView:view fromTailStart:tailStart];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  CGFloat contentWidth = [self contentBounds].size.width;
  if (contentWidth > 0) {
    [self computeSegmentLayoutForWidth:contentWidth applyFrames:YES];
  }
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<EnrichedMarkdownProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<EnrichedMarkdownProps const>(props);

  BOOL markdownChanged = oldViewProps.markdown != newViewProps.markdown;
  if (markdownChanged) {
    // A task toggle renders its result locally before JS echoes it back as a
    // prop, so the rendered document is handed over for the echo check.
    if ([_codeBlockWrapState markdownPropDidChangeFrom:oldViewProps.markdown
                                                    to:newViewProps.markdown
                                              rendered:_cachedMarkdown]) {
      _dirtyFlags |= ENRMDirtyForceHeight;
    }
  }

  if (_config == nil) {
    _config = [[StyleConfig alloc] init];
    [_config setFontScaleMultiplier:_fontScaleObserver.effectiveFontScale];
  }

  if (applyMarkdownStyleToConfig(_config, newViewProps.markdownStyle, oldViewProps.markdownStyle)) {
    _dirtyFlags |= ENRMDirtyForceHeight | ENRMDirtyRender;
    if (!markdownChanged) {
      _dirtyFlags |= ENRMDirtyRecreateSegments;
    }
  }

  if (ENRMImageRequestHeadersChanged(oldViewProps.imageRequestHeaders, newViewProps.imageRequestHeaders)) {
    [_config setImageRequestHeaders:ENRMImageRequestHeadersFromProps(newViewProps.imageRequestHeaders)];
    _dirtyFlags |= ENRMDirtyRender;
    if (!markdownChanged) {
      _dirtyFlags |= ENRMDirtyRecreateSegments;
    }
  }

  // Overridden sources decide which image loads, so its box height. With a
  // markdown change in the same commit the reconciler decides per segment; the
  // segment signature carries the sources (SegmentRenderer) so a reused one
  // never keeps the previous attachment.
  if (ENRMImageSourcesChanged(oldViewProps.imageSources, newViewProps.imageSources)) {
    [_config setImageSourceOverrides:ENRMImageSourceOverridesFromProps(newViewProps.imageSources)];
    _dirtyFlags |= ENRMDirtyRender | ENRMDirtyForceHeight;
    if (!markdownChanged) {
      _dirtyFlags |= ENRMDirtyRecreateSegments;
    }
  }

  // Pill labels change layout, so treat new content like a style change.
  if (ENRMLinkPillContentChanged(oldViewProps.linkPillContent, newViewProps.linkPillContent)) {
    [_config setLinkPillContent:ENRMLinkPillContentFromProps(newViewProps.linkPillContent)];
    _dirtyFlags |= ENRMDirtyRender;
    if (!markdownChanged) {
      _dirtyFlags |= ENRMDirtyRecreateSegments;
    }
  }

  _selectable = newViewProps.selectable;

  for (RCTUIView *segment in _segmentViews) {
    if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      EnrichedMarkdownInternalText *textSegment = (EnrichedMarkdownInternalText *)segment;
      if (textSegment.textView.selectable != newViewProps.selectable) {
        textSegment.textView.selectable = newViewProps.selectable;
      }
    }
  }

  if (newViewProps.allowFontScaling != oldViewProps.allowFontScaling) {
    _fontScaleObserver.allowFontScaling = newViewProps.allowFontScaling;
    if (_config != nil) {
      [_config setFontScaleMultiplier:_fontScaleObserver.effectiveFontScale];
    }
    _dirtyFlags |= ENRMDirtyRecreateSegments | ENRMDirtyForceHeight | ENRMDirtyRender;
  }

  if (newViewProps.maxFontSizeMultiplier != oldViewProps.maxFontSizeMultiplier) {
    _maxFontSizeMultiplier = newViewProps.maxFontSizeMultiplier;
    if (_config != nil) {
      [_config setMaxFontSizeMultiplier:_maxFontSizeMultiplier];
    }
    _dirtyFlags |= ENRMDirtyRecreateSegments | ENRMDirtyForceHeight | ENRMDirtyRender;
  }

  if (newViewProps.allowTrailingMargin != oldViewProps.allowTrailingMargin) {
    _allowTrailingMargin = newViewProps.allowTrailingMargin;
    _dirtyFlags |= ENRMDirtyRecreateSegments | ENRMDirtyForceHeight | ENRMDirtyRender;
  }

  if (!ENRMLinkRegexPropsEqual(oldViewProps.linkRecognition.text, newViewProps.linkRecognition.text)) {
    _linkRegex = ENRMLinkRegexConfigFromProps(newViewProps.linkRecognition.text);
    _dirtyFlags |= ENRMDirtyRender;
    _dirtyFlags |= ENRMDirtyForceHeight;
  }
  if (!ENRMLinkRegexPropsEqual(oldViewProps.linkRecognition.inlineCode, newViewProps.linkRecognition.inlineCode)) {
    _inlineCodeLinkRegex = ENRMLinkRegexConfigFromProps(newViewProps.linkRecognition.inlineCode);
    _dirtyFlags |= ENRMDirtyRender;
    _dirtyFlags |= ENRMDirtyForceHeight;
  }

  if (newViewProps.md4cFlags.underline != oldViewProps.md4cFlags.underline ||
      newViewProps.md4cFlags.superscript != oldViewProps.md4cFlags.superscript ||
      newViewProps.md4cFlags.subscript != oldViewProps.md4cFlags.subscript ||
      newViewProps.md4cFlags.strikethrough != oldViewProps.md4cFlags.strikethrough ||
      newViewProps.md4cFlags.latexMath != oldViewProps.md4cFlags.latexMath ||
      newViewProps.md4cFlags.highlight != oldViewProps.md4cFlags.highlight ||
      newViewProps.md4cFlags.hardSoftBreaks != oldViewProps.md4cFlags.hardSoftBreaks ||
      newViewProps.md4cFlags.preserveBlankLines != oldViewProps.md4cFlags.preserveBlankLines ||
      newViewProps.md4cFlags.admonitions != oldViewProps.md4cFlags.admonitions) {
    _md4cFlags = [EnrichedMarkdown flagsFromProps:newViewProps.md4cFlags];
    _dirtyFlags |= ENRMDirtyForceHeight | ENRMDirtyRender;
  }

  if (newViewProps.isGFM != oldViewProps.isGFM) {
    _isGFM = newViewProps.isGFM;
    _dirtyFlags |= ENRMDirtyRecreateSegments | ENRMDirtyForceHeight | ENRMDirtyRender;
  }

  _enableLinkPreview = newViewProps.enableLinkPreview;
  _enableTaskListItemToggle = newViewProps.enableTaskListItemToggle;
  _enableImagePress = newViewProps.enableImagePress;
  _enableTextPress = newViewProps.enableTextPress;

  // Block gates: mutate the shared box in place. Every existing and future block
  // view reads it live at use-time, so no push into segments is needed.
  _dynamicBlockProps.enableLinkPreview = newViewProps.enableLinkPreview;
  _dynamicBlockProps.enableBlockContextMenu = newViewProps.enableBlockContextMenu;
  _dynamicBlockProps.enableCodeBlockPress = newViewProps.enableCodeBlockPress;

  if ([_codeBlockWrapState updateEnabled:newViewProps.enableCodeBlockWrapToggle]) {
    [self setNeedsLayout];
    [self requestHeightUpdate];
  }

  BOOL streamingEnded = NO;
  if (newViewProps.streaming != oldViewProps.streaming) {
    if (newViewProps.streaming) {
      _streaming = YES;
      _streamEnding = NO;
      [_pacer resume];
      _dirtyFlags |= ENRMDirtyForceHeight | ENRMDirtyRender;
    } else {
      streamingEnded = YES;
    }
  }
  if (newViewProps.streamingConfig.smooth != oldViewProps.streamingConfig.smooth) {
    _dirtyFlags |= ENRMDirtyRender;
  }

  BOOL animationChanged = !ENRMSameStreamingAnimation(newViewProps.streamingConfig, oldViewProps.streamingConfig);
  if (animationChanged) {
    _streamingFade = newViewProps.streamingConfig.animation != "none";
    if (!_streamingFade) {
      [self finishStreamingAnimations];
    }
  }

  if (newViewProps.streamingConfig.tableMode != oldViewProps.streamingConfig.tableMode) {
    NSString *tableModeStr = [[NSString alloc] initWithUTF8String:newViewProps.streamingConfig.tableMode.c_str()];
    _tableStreamingMode =
        [tableModeStr isEqualToString:@"hidden"] ? ENRMTableStreamingModeHidden : ENRMTableStreamingModeProgressive;
    _dirtyFlags |= ENRMDirtyForceHeight | ENRMDirtyRender;
  }

  if (newViewProps.streamingConfig.codeBlockMode != oldViewProps.streamingConfig.codeBlockMode) {
    NSString *codeBlockModeStr =
        [[NSString alloc] initWithUTF8String:newViewProps.streamingConfig.codeBlockMode.c_str()];
    _codeBlockStreamingMode = [codeBlockModeStr isEqualToString:@"hidden"] ? ENRMCodeBlockStreamingModeHidden
                                                                           : ENRMCodeBlockStreamingModeProgressive;
    _dirtyFlags |= ENRMDirtyForceHeight | ENRMDirtyRender;
  }

  if (newViewProps.streamingConfig.mediaMode != oldViewProps.streamingConfig.mediaMode) {
    NSString *mediaModeStr = [[NSString alloc] initWithUTF8String:newViewProps.streamingConfig.mediaMode.c_str()];
    _mediaStreamingMode =
        [mediaModeStr isEqualToString:@"hidden"] ? ENRMMediaStreamingModeHidden : ENRMMediaStreamingModeProgressive;
    _dirtyFlags |= ENRMDirtyForceHeight | ENRMDirtyRender;
  }

  if (ENRMLinkContextMenuItemsChanged(oldViewProps.linkContextMenuItems, newViewProps.linkContextMenuItems)) {
    _linkContextMenus.entries = ENRMLinkContextMenuEntriesFromProps(newViewProps.linkContextMenuItems);
  }

  if (ENRMContextMenuItemsChanged(oldViewProps.contextMenuItems, newViewProps.contextMenuItems)) {
    _contextMenuItemTexts = ENRMContextMenuTextsFromItems(newViewProps.contextMenuItems);
    _contextMenuItemIcons = ENRMContextMenuIconsFromItems(newViewProps.contextMenuItems);
  }

  _selectionMenuLabels = ENRMParseSelectionMenuLabels(newViewProps.selectionMenuConfig);
  _selectionMenuConfig =
      ENRMBuildSelectionMenuConfig(_selectionMenuLabels, newViewProps.selectionMenuConfig.copyAsMarkdown,
                                   newViewProps.selectionMenuConfig.copyImageUrl);
  // Block menu labels live in the shared box; block views read them live at
  // menu-open. (_selectionMenuLabels also feeds the text selection menu above.)
  _dynamicBlockProps.copyLabel = _selectionMenuLabels.copyLabel;
  _dynamicBlockProps.copyAsMarkdownLabel = _selectionMenuLabels.copyAsMarkdownLabel;

  if (ENRMAccessibilityLabelsChanged(oldViewProps.accessibilityLabels, newViewProps.accessibilityLabels)) {
    _accessibilityLabels = [[ENRMAccessibilityLabels alloc] init];
    _accessibilityLabels.bulletPoint =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.list.bulletPoint.c_str()];
    _accessibilityLabels.nestedBulletPoint =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.list.nestedBulletPoint.c_str()];
    _accessibilityLabels.orderedItem =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.list.orderedItem.c_str()];
    _accessibilityLabels.nestedOrderedItem =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.list.nestedOrderedItem.c_str()];
    _accessibilityLabels.blockquote =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.blockquote.quote.c_str()];
    _accessibilityLabels.nestedBlockquote =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.blockquote.nestedQuote.c_str()];
    _accessibilityLabels.tableRow =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.table.row.c_str()];
    _accessibilityLabels.mathEquation =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.math.equation.c_str()];
    _accessibilityLabels.codeBlockWrap =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.codeBlock.wrap.c_str()];
    _accessibilityLabels.codeBlockUnwrap =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.codeBlock.unwrap.c_str()];
    _accessibilityLabels.rotorHeadings =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.rotor.headings.c_str()];
    _accessibilityLabels.rotorLinks =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.rotor.links.c_str()];
    _accessibilityLabels.rotorImages =
        [[NSString alloc] initWithUTF8String:newViewProps.accessibilityLabels.rotor.images.c_str()];
    [self pushAccessibilityLabelsToSegments];
  }

  if (newViewProps.spoilerOverlay != oldViewProps.spoilerOverlay) {
    NSString *modeStr = [[NSString alloc] initWithUTF8String:newViewProps.spoilerOverlay.c_str()];
    _spoilerOverlay = ENRMSpoilerOverlayFromString(modeStr);
    for (RCTUIView *segment in _segmentViews) {
      if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
        ((EnrichedMarkdownInternalText *)segment).spoilerOverlay = _spoilerOverlay;
      }
    }
  }

  if (newViewProps.selectionColor != oldViewProps.selectionColor) {
    for (RCTUIView *segment in _segmentViews) {
      if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
        ENRMPlatformTextView *tv = ((EnrichedMarkdownInternalText *)segment).textView;
        ENRMApplySelectionColor(tv, newViewProps.selectionColor);
      }
    }
  }

  if (newViewProps.lineBreakStrategyIOS != oldViewProps.lineBreakStrategyIOS) {
    NSString *strategy = [[NSString alloc] initWithUTF8String:newViewProps.lineBreakStrategyIOS.c_str()];
    _lineBreakStrategy = ENRMResolveLineBreakStrategy(strategy);
    _dirtyFlags |= ENRMDirtyForceHeight | ENRMDirtyRender;
  }

  if (newViewProps.writingDirection != oldViewProps.writingDirection) {
    NSString *value = [[NSString alloc] initWithUTF8String:newViewProps.writingDirection.c_str()];
    _writingDirectionMode = ENRMResolveWritingDirectionMode(value);
    _dirtyFlags |= ENRMDirtyRecreateSegments | ENRMDirtyForceHeight | ENRMDirtyRender;
    [self pushWritingDirectionToTableSegments];
  }

  // With smooth pacing the words still waiting appear first (within 200 ms), then streaming stops.
  if (streamingEnded) {
    if (newViewProps.streamingConfig.smooth) {
      [_pacer markdownToRender:ENRMStringFromUTF8(newViewProps.markdown) pacing:YES];
      [_pacer finish];
    }
    if (_pacer.waiting) {
      _dirtyFlags |= ENRMDirtyRender;
    } else {
      [self stopStreaming];
      _dirtyFlags |= ENRMDirtyRender;
    }
  }

  if (markdownChanged || (_dirtyFlags & ENRMDirtyRender)) {
    // Smooth pacing renders what has been revealed and hands the rest over frame by frame, so new
    // markdown that reveals nothing yet renders nothing.
    NSString *markdown = [_pacer markdownToRender:ENRMStringFromUTF8(newViewProps.markdown)
                                           pacing:_streaming && newViewProps.streamingConfig.smooth];
    if ((_dirtyFlags & ENRMDirtyRender) || ![markdown isEqualToString:_cachedMarkdown]) {
      _pendingStyleFingerprint =
          computeStyleFingerprint(newViewProps.markdownStyle) ^ std::hash<bool>{}(newViewProps.allowTrailingMargin);
      // Rendered in finalizeUpdates, once per transaction (see
      // applyBlockSlotPlacementsFromState).
      _pendingRenderMarkdown = markdown;
    }
    _dirtyFlags &= ~ENRMDirtyRender;
  }

  [super updateProps:props oldProps:oldProps];

  // Text segments start over with the new animation, from `_props` (set by super): 'none' shows
  // what still animates at once.
  if (animationChanged) {
    for (RCTUIView *segment in _segmentViews) {
      if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
        [self configureStreamingEffectsOfTextSegment:(EnrichedMarkdownInternalText *)segment];
      }
    }
  }
}

#if !TARGET_OS_OSX
static void ENRMUpdateNestedViewports(UIView *view)
{
  for (UIView *subview in view.subviews) {
    if ([subview isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      [(EnrichedMarkdownInternalText *)subview updateViewport];
    } else if (![subview isKindOfClass:[UITextView class]]) {
      ENRMUpdateNestedViewports(subview);
    }
  }
}

static BOOL ENRMDrawsItself(UIView *view)
{
  static IMP viewDrawRect;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ viewDrawRect = class_getMethodImplementation([UIView class], @selector(drawRect:)); });
  return class_getMethodImplementation([view class], @selector(drawRect:)) != viewDrawRect;
}

// Drops (`draws` NO) or redraws the bitmaps of the library's views in `view` that draw themselves.
// Text views draw only their drawn rect already; a UIKit view may keep its contents some other way.
static void ENRMSetViewDrawsContent(UIView *view, BOOL draws)
{
  if ([view isKindOfClass:[UITextView class]]) {
    return;
  }
  static NSBundle *uiKit;
  static dispatch_once_t uiKitOnce;
  dispatch_once(&uiKitOnce, ^{ uiKit = [NSBundle bundleForClass:[UIView class]]; });
  if (ENRMDrawsItself(view) && [NSBundle bundleForClass:[view class]] != uiKit) {
    if (draws) {
      [view setNeedsDisplay];
    } else {
      view.layer.contents = nil;
    }
  }
  for (UIView *subview in view.subviews) {
    ENRMSetViewDrawsContent(subview, draws);
  }
}

// Runs `block` once Core Animation committed this run loop turn (its observer has order 2000000).
static void ENRMAfterCommit(dispatch_block_t block)
{
  CFRunLoopObserverRef observer =
      CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, false, 2000001,
                                         ^(CFRunLoopObserverRef firing, CFRunLoopActivity activity) {
                                           CFRunLoopRemoveObserver(CFRunLoopGetMain(), firing, kCFRunLoopCommonModes);
                                           block();
                                         });
  CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
  CFRelease(observer);
}
#endif

// A layout change around this view (a message above it in a list growing) moves it on screen
// without a scroll. Called for every mount on the surface: only a change in what shows matters.
- (void)mountingTransactionDidMount:(const MountingTransaction &)transaction
               withSurfaceTelemetry:(const SurfaceTelemetry &)surfaceTelemetry
{
#if !TARGET_OS_OSX
  if (!CGRectEqualToRect([_visibleArea visibleRect], _drawnVisibleRect)) {
    [self updateDrawnSegments];
  }
#endif
}

/// Draws only the segments near the visible part of the document. A text segment draws the part of
/// its text there (ENRMTextViewport); a block segment off screen (a code block, a table, a quote)
/// drops the bitmaps it drew, and draws again when it comes back.
- (void)updateDrawnSegments
{
#if !TARGET_OS_OSX
  for (RCTUIView *segment in _segmentViews) {
    if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      [(EnrichedMarkdownInternalText *)segment updateViewport];
    } else if (![segment isKindOfClass:[ENRMBlockSlotSegmentView class]]) {
      // A quote holds text segments of its own, moved with it.
      ENRMUpdateNestedViewports(segment);
    }
  }
  [self updateDrawnBlocks];
#endif
}

- (void)updateDrawnBlocks
{
#if !TARGET_OS_OSX
  CGRect visible = [_visibleArea visibleRect];
  _drawnVisibleRect = visible;
  CGRect drawn = CGRectIsNull(visible) || CGRectIsEmpty(visible) ? CGRectNull
                 : CGRectIsInfinite(visible)                     ? CGRectInfinite
                                                                 : CGRectInset(visible, 0, -ENRMVisibleAreaMargin);
  NSMutableArray<RCTUIView *> *dropped = nil;
  for (RCTUIView *segment in _segmentViews) {
    // React Native draws the views it renders into a slot.
    if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]] ||
        [segment isKindOfClass:[ENRMBlockSlotSegmentView class]]) {
      continue;
    }
    BOOL draws = !CGRectIsNull(drawn) && CGRectIntersectsRect(drawn, segment.frame);
    if (draws == ![_undrawnSegments containsObject:segment]) {
      continue;
    }
    if (draws) {
      [_undrawnSegments removeObject:segment];
    } else {
      [_undrawnSegments addObject:segment];
      dropped = dropped ?: [NSMutableArray array];
      [dropped addObject:segment];
    }
    ENRMSetViewDrawsContent(segment, draws);
  }
  if (dropped != nil) {
    // A view that never drew (a new segment) draws when this run loop turn commits: drop that too.
    __weak EnrichedMarkdown *weakSelf = self;
    ENRMAfterCommit(^{
      EnrichedMarkdown *strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }
      for (RCTUIView *segment in dropped) {
        if ([strongSelf->_undrawnSegments containsObject:segment]) {
          ENRMSetViewDrawsContent(segment, NO);
        }
      }
    });
  }
#endif
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];
  [self updateDrawnSegments];

  if (!self.window) {
    _needsWindowAttachRefresh = YES;
    return;
  }
  if (_renderedMarkdown != nil && _needsWindowAttachRefresh) {
    _needsWindowAttachRefresh = NO;
    for (RCTUIView *segment in _segmentViews) {
      if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
        EnrichedMarkdownInternalText *textSegment = (EnrichedMarkdownInternalText *)segment;
        [textSegment refreshAfterWindowAttach];
      }
    }

    CGRect contentBounds = [self contentBounds];
    if (contentBounds.size.width > 0) {
      CGSize measured = [self measureSize:contentBounds.size.width];
      if (needsHeightUpdate(measured, contentBounds)) {
        [self requestHeightUpdate];
      }
    }
  }
}

- (void)prepareForRecycle
{
  const auto resetProps = std::make_shared<const EnrichedMarkdownProps>();
  _props = resetProps;
  [_renderCoordinator invalidate];
  _laidOutSize.clear();
  _laidOutMarkdown = nullptr;

  for (RCTUIView *segment in _segmentViews) {
    [segment removeFromSuperview];
  }
  [_segmentViews removeAllObjects];
  [_segmentSignatures removeAllObjects];
  _textRenderCacheEpoch++;

  _cachedMarkdown = nil;
  _renderedMarkdown = nil;
  _config = nil;
  _activeBlockSlotIds = nil;
  _blockSlotHeights = nil;
  [_blockSlotReveal reset];
  _pendingRenderMarkdown = nil;
  _pendingRenderSynchronously = NO;
  _pendingSlotHeightCheck = NO;
  _md4cFlags = [EnrichedMarkdown flagsFromProps:resetProps->md4cFlags];
  _isGFM = resetProps->isGFM;
  _linkRegex = ENRMLinkRegexConfigFromProps(resetProps->linkRecognition.text);
  _inlineCodeLinkRegex = ENRMLinkRegexConfigFromProps(resetProps->linkRecognition.inlineCode);
  _maxFontSizeMultiplier = 0;
  _allowTrailingMargin = NO;
  _streaming = NO;
  _streamEnding = NO;
  [_pacer reset];
  _streamingFade = YES;
  _tableStreamingMode = ENRMTableStreamingModeProgressive;
  _codeBlockStreamingMode = ENRMCodeBlockStreamingModeProgressive;
  _mediaStreamingMode = ENRMMediaStreamingModeProgressive;
  _pendingCodeBlockSegment = nil;
  [_codeBlockWrapState reset];
  _lineBreakStrategy = NSLineBreakStrategyNone;
  _writingDirectionMode = ENRMWritingDirectionModeFirstStrong;
  _renderedStyleFingerprint = 0;
  _pendingStyleFingerprint = 0;
  _linkContextMenus.entries = @[];
  _contextMenuItemTexts = nil;
  _contextMenuItemIcons = nil;
  _fontScaleObserver.allowFontScaling = resetProps->allowFontScaling;
  _accessibilityLabels = nil;
  _spoilerOverlay =
      ENRMSpoilerOverlayFromString([[NSString alloc] initWithUTF8String:resetProps->spoilerOverlay.c_str()]);
  _dirtyFlags = ENRMDirtyNone;

  [super prepareForRecycle];
}

Class<RCTComponentViewProtocol> EnrichedMarkdownCls(void)
{
  return EnrichedMarkdown.class;
}

#if !TARGET_OS_OSX
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
  if ([super pointInside:point withEvent:event]) {
    return YES;
  }

  for (RCTUIView *segment in _segmentViews) {
    if (CGRectContainsPoint(segment.frame, point)) {
      return YES;
    }
  }
  for (RCTUIView *slot in _slotLayer.subviews) {
    if (CGRectContainsPoint(slot.frame, point)) {
      return YES;
    }
  }

  return NO;
}
#endif

- (facebook::react::SharedTouchEventEmitter)touchEventEmitterAtPoint:(CGPoint)point
{
  for (RCTUIView *segment in _segmentViews) {
    if ([segment isKindOfClass:[TableContainerView class]]) {
      CGPoint segmentPoint = [self convertPoint:point toView:segment];
#if !TARGET_OS_OSX
      if ([segment pointInside:segmentPoint withEvent:nil]) {
        return nil;
      }
#else
      if (CGRectContainsPoint(segment.bounds, segmentPoint)) {
        return nil;
      }
#endif
    }

    if (![segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      continue;
    }
    EnrichedMarkdownInternalText *textSegment = (EnrichedMarkdownInternalText *)segment;
    CGPoint segmentPoint = [self convertPoint:point toView:textSegment.textView];
#if !TARGET_OS_OSX
    BOOL isInsideView = [textSegment.textView pointInside:segmentPoint withEvent:nil];
#else
    BOOL isInsideView = CGRectContainsPoint(textSegment.textView.bounds, segmentPoint);
#endif
    if (isInsideView) {
      // Only where textTapped would emit, so a parent Pressable still gets the rest, as on Android.
      BOOL isTextPress = _enableTextPress && textSegment.textView.selectedRange.length == 0 &&
                         textPressIndexAtPoint(textSegment.textView, segmentPoint) != NSNotFound;
      if (isTextPress || isPointOnInteractiveElement(textSegment.textView, segmentPoint, _enableImagePress, NO)) {
        return nil;
      }
      break;
    }
  }

  return [super touchEventEmitterAtPoint:point];
}

#if TARGET_OS_OSX
- (void)mouseDown:(NSEvent *)event
{
  for (RCTUIView *segment in _segmentViews) {
    if (![segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      continue;
    }
    ENRMPlatformTextView *tv = ((EnrichedMarkdownInternalText *)segment).textView;
    if (tv.selectedRange.length > 0) {
      tv.selectedRange = NSMakeRange(0, 0);
    }
  }
  [super mouseDown:event];
}
#endif

- (void)emitLinkPress:(NSString *)url
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onLinkPress({.url = std::string(url.UTF8String)});
}

- (void)emitTextPress:(NSInteger)index text:(NSString *)text
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onTextPress({.index = (int)index, .text = std::string(text.UTF8String ?: "")});
}

- (void)emitImagePress:(NSString *)url altText:(NSString *)altText
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onImagePress({.url = std::string(url.UTF8String ?: ""), .altText = std::string(altText.UTF8String ?: "")});
}

- (void)emitLinkLongPress:(NSString *)url
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onLinkLongPress({.url = std::string(url.UTF8String)});
}

- (void)emitLinkContextMenuItemPress:(NSString *)itemText pattern:(NSString *)pattern url:(NSString *)url
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter) {
    emitter->onLinkContextMenuItemPress({.url = std::string(url.UTF8String),
                                         .pattern = std::string(pattern.UTF8String),
                                         .itemText = std::string(itemText.UTF8String)});
  }
}

- (void)emitTaskListItemPress:(NSInteger)index checked:(BOOL)checked text:(NSString *)text
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onTaskListItemPress({.index = (int)index, .checked = checked, .text = std::string(text.UTF8String ?: "")});
}

- (void)emitCopyPress:(NSString *)code language:(NSString *)language
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onCopyPress(
        {.code = std::string(code.UTF8String ?: ""), .language = std::string(language.UTF8String ?: "")});
}

- (void)emitCodeBlockPress:(NSString *)code language:(NSString *)language
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onCodeBlockPress(
        {.code = std::string(code.UTF8String ?: ""), .language = std::string(language.UTF8String ?: "")});
}

- (void)emitContextMenuItemPress:(NSString *)itemText
                    selectedText:(NSString *)selectedText
                  selectionStart:(NSUInteger)selectionStart
                    selectionEnd:(NSUInteger)selectionEnd
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onContextMenuItemPress({
        .itemText = std::string(itemText.UTF8String),
        .selectedText = std::string(selectedText.UTF8String),
        .selectionStart = (int)selectionStart,
        .selectionEnd = (int)selectionEnd,
    });
}

- (void)updateEventEmitter:(const facebook::react::EventEmitter::Shared &)eventEmitter
{
  [super updateEventEmitter:eventEmitter];
  [_latexErrorCoordinator flushPending];
}

- (void)textTapped:(ENRMTapRecognizer *)recognizer
{
  ENRMPlatformTextView *textView = (ENRMPlatformTextView *)recognizer.view;
  // Read before the link check below clears the selection.
  BOOL hadSelection = textView.selectedRange.length > 0;

  if (_enableTaskListItemToggle &&
      handleTaskListTapWithSharedLogic(
          textView, recognizer, &self->_cachedMarkdown, self->_config,
          ^(NSInteger index, BOOL checked, NSString *itemText) {
            [self emitTaskListItemPress:index checked:checked text:itemText];
          },
          ^(NSString *updatedMarkdown) { [self renderMarkdownContent:updatedMarkdown]; })) {
    return;
  }

  for (RCTUIView *segment in _segmentViews) {
    if ([segment conformsToProtocol:@protocol(ENRMSpoilerCapable)]) {
      id<ENRMSpoilerCapable> spoilerSegment = (id<ENRMSpoilerCapable>)segment;
      if (spoilerSegment.textView == textView) {
        if (handleSpoilerTap(textView, recognizer, spoilerSegment.spoilerManager))
          return;
        break;
      }
    }
  }

  if (ENRMHandleTapOnTextView(textView, recognizer, ^(NSString *url) { [self emitLinkPress:url]; })) {
    return;
  }

  if (_enableImagePress) {
    NSDictionary<NSString *, NSString *> *image = imageAtTapLocation(textView, recognizer);
    if (image) {
      [self emitImagePress:image[@"url"] altText:image[@"altText"]];
      return;
    }
  }

  // Skip while text is selected so the tap only clears the selection.
  if (_enableTextPress && !hadSelection) {
    NSUInteger index = textPressIndexAtTapLocation(textView, recognizer);
    if (index != NSNotFound)
      [self emitTextPress:index text:ENRMGetAttributedText(textView).string];
  }
}

// TODO: Remove API_AVAILABLE(ios(16.0)) guard when the minimum iOS deployment target in RN is bumped to 16.
#if !TARGET_OS_OSX
- (UIMenu *)textView:(UITextView *)textView
    editMenuForTextInRange:(NSRange)range
          suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions API_AVAILABLE(ios(16.0))
{
  __weak EnrichedMarkdown *weakSelf = self;
  ENRMContextMenuPressHandler handler =
      ^(NSString *itemText, NSString *selectedText, NSUInteger selectionStart, NSUInteger selectionEnd) {
        EnrichedMarkdown *strongSelf = weakSelf;
        if (strongSelf)
          [strongSelf emitContextMenuItemPress:itemText
                                  selectedText:selectedText
                                selectionStart:selectionStart
                                  selectionEnd:selectionEnd];
      };
  NSMutableArray<UIAction *> *customActions =
      ENRMBuildContextMenuActions(_contextMenuItemTexts, _contextMenuItemIcons, textView, range, handler);

  NSString *segmentMarkdown = extractMarkdownFromAttributedString(textView.attributedText, range);
  return buildEditMenuForSelection(textView.attributedText, range, segmentMarkdown, _config, suggestedActions,
                                   customActions, _selectionMenuConfig);
}

- (UITextItemMenuConfiguration *)textView:(UITextView *)textView
             menuConfigurationForTextItem:(UITextItem *)textItem
                              defaultMenu:(UIMenu *)defaultMenu API_AVAILABLE(ios(17.0))
{
  __weak EnrichedMarkdown *weakSelf = self;
  return ENRMLinkMenuConfigurationForTextItem(textView, textItem, defaultMenu, _linkContextMenus, _enableLinkPreview,
                                              ^(NSString *url) { [weakSelf emitLinkLongPress:url]; });
}

- (ENRMLinkContextMenus *)linkContextMenusForTextView:(UITextView *)textView
{
  return _linkContextMenus;
}

- (BOOL)textView:(UITextView *)textView
    shouldInteractWithURL:(NSURL *)URL
                  inRange:(NSRange)characterRange
              interaction:(UITextItemInteraction)interaction
{
  if (interaction != UITextItemInteractionPresentActions) {
    return YES;
  }

  NSString *urlString = linkURLAtRange(textView, characterRange);

  // A link with a menu is presented by the iOS 17 callback above and must not be vetoed here.
  if ([_linkContextMenus hasMenuForURL:urlString])
    return YES;

  if (!urlString || _enableLinkPreview) {
    return YES;
  }

  [self emitLinkLongPress:urlString];
  return NO;
}
#endif

- (BOOL)isAccessibilityElement
{
  return NO;
}

// Each placeholder stands in for the React child mounted in the slot layer, so
// VoiceOver reads the child in document order instead of an empty view.
- (NSArray *)accessibilityElements
{
  NSMutableArray *elements = [NSMutableArray arrayWithCapacity:_segmentViews.count];
  for (RCTUIView *segment in _segmentViews) {
    if ([segment isKindOfClass:[ENRMBlockSlotSegmentView class]]) {
      RCTUIView *slot = [self mountedBlockSlotViewForId:((ENRMBlockSlotSegmentView *)segment).slotId];
      if (slot) {
        [elements addObject:slot];
      }
      continue;
    }
    [elements addObject:segment];
  }
  return elements;
}

- (NSInteger)accessibilityElementCount
{
  return [self accessibilityElements].count;
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
  NSArray *elements = [self accessibilityElements];
  if (index < 0 || index >= (NSInteger)elements.count) {
    return nil;
  }
  return elements[index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
  return [[self accessibilityElements] indexOfObject:element];
}

#if !TARGET_OS_OSX
- (NSArray<UIAccessibilityCustomRotor *> *)accessibilityCustomRotors
{
  // The rotors filter by trait, which only the leaves inside the segments carry.
  NSArray *leaves = [MarkdownAccessibilityElementBuilder collectLeafElementsFromElements:[self accessibilityElements]];
  return [MarkdownAccessibilityElementBuilder buildRotorsFromElements:leaves labels:_accessibilityLabels];
}
#endif

@end
