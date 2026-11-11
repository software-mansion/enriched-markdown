#import "EnrichedMarkdownText.h"
#import "CodeBlockBackground.h"
#import "ContextMenuUtils.h"
#import "ENRMAccessibilityLabels.h"
#import "ENRMAsyncRenderCoordinator.h"
#import "ENRMContextMenuTextView+macOS.h"
#import "ENRMImageAttachment.h"
#import "ENRMLaidOutSize.h"
#import "ENRMLatexErrorCoordinator.h"
#import "ENRMLinkContextMenus.h"
#import "ENRMLinkRegexProps.h"
#import "ENRMMarkdownParser.h"
#import "ENRMMarkdownTextView.h"
#import "ENRMPreparedRenderStore.h"
#import "ENRMSpoilerOverlayManager.h"
#import "ENRMSpoilerTapUtils.h"
#import "ENRMTailFadeInAnimator.h"
#import "ENRMTextInteractionUtils.h"
#import "ENRMTextRenderCache.h"
#import "ENRMTextRenderer.h"
#import "ENRMTextViewSetup.h"
#import "ENRMUIKit.h"
#import "ENRMUTF8.h"
#import "ENRMViewFreeMeasurement.h"
#import "EditMenuUtils.h"
#import "FontScaleObserver.h"
#import "FontUtils.h"
#import "HeightUpdateUtils.h"
#import "ImageRequestHeaderUtils.h"
#import "LinkContextMenuUtils.h"
#import "LinkPillContentUtils.h"
#import "LinkTapUtils.h"
#import "MarkdownASTNode.h"
#import "MarkdownAccessibilityElementBuilder.h"
#import "MarkdownExtractor.h"
#import "MeasurementCache.h"
#import "ParagraphStyleUtils.h"
#import "PasteboardUtils.h"
#import "RenderContext.h"
#import "RuntimeKeys.h"
#import "SelectionColorUtils.h"
#import "StreamingMarkdownFilter.h"
#import "StylePropsUtils.h"
#import "TaskListTapUtils.h"

#import <ReactNativeEnrichedMarkdown/EnrichedMarkdownTextComponentDescriptor.h>
#import <react/renderer/components/EnrichedMarkdownTextSpec/EventEmitters.h>
#import <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>
#import <react/renderer/components/EnrichedMarkdownTextSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"
#import <React/RCTConversions.h>
#import <React/RCTFont.h>
#import <React/RCTI18nUtil.h>

using namespace facebook::react;

typedef NS_OPTIONS(NSUInteger, ENRMDirtyFlags) {
  ENRMDirtyNone = 0,
  ENRMDirtyRender = 1 << 0,
};

@interface EnrichedMarkdownText () <RCTEnrichedMarkdownTextViewProtocol, UITextViewDelegate, ENRMImageLayoutObserver>
+ (ENRMMd4cFlags *)flagsFromProps:(const EnrichedMarkdownTextMd4cFlagsStruct &)props;
- (void)setupTextView;
- (void)renderMarkdownContent:(NSString *)markdownString;
- (void)applyRenderedText:(ENRMRenderResult *)result forceHeightUpdate:(BOOL)scheduledForceHeight;
- (void)textTapped:(ENRMTapRecognizer *)recognizer;
- (void)setupLayoutManager;
- (void)emitLinkPress:(NSString *)url;
- (void)emitLinkLongPress:(NSString *)url;
- (void)emitLinkContextMenuItemPress:(NSString *)itemText pattern:(NSString *)pattern url:(NSString *)url;
- (void)emitImagePress:(NSString *)url altText:(NSString *)altText;
- (void)emitTextPress:(NSInteger)index text:(NSString *)text;
- (void)emitCodeBlockPress:(NSString *)code language:(NSString *)language;
- (void)emitTaskListItemPress:(NSInteger)index checked:(BOOL)checked text:(NSString *)text;
- (void)emitContextMenuItemPress:(NSString *)itemText
                    selectedText:(NSString *)selectedText
                  selectionStart:(NSUInteger)selectionStart
                    selectionEnd:(NSUInteger)selectionEnd;
- (ENRMSelectionCopyHandler)selectionCopyHandler;
@end

#if !TARGET_OS_OSX
@interface EnrichedMarkdownText () <ENRMLinkContextMenuSource>
@end
#endif

@implementation EnrichedMarkdownText {
  ENRMPlatformTextView *_textView;
  ENRMMarkdownParser *_parser;
  NSString *_cachedMarkdown;
  NSString *_renderedMarkdown;
  NSString *_pendingRenderMarkdown;
  StyleConfig *_config;
  ENRMMd4cFlags *_md4cFlags;
  BOOL _isGFM;
  ENRMLinkRegexConfig *_linkRegex;
  ENRMLinkRegexConfig *_inlineCodeLinkRegex;

  ENRMAsyncRenderCoordinator *_renderCoordinator;
  // Text laid out while detached is current when the view attaches; one that
  // left a window may hold a stale layout and is refreshed on return (#155).
  BOOL _needsWindowAttachRefresh;

  EnrichedMarkdownTextShadowNode::ConcreteState::Shared _state;
  int _heightUpdateCounter;

  FontScaleObserver *_fontScaleObserver;
  CGFloat _maxFontSizeMultiplier;

  CGFloat _lastElementMarginBottom;
  BOOL _allowTrailingMargin;
  BOOL _enableLinkPreview;
  BOOL _enableTaskListItemToggle;
  BOOL _enableImagePress;
  BOOL _enableTextPress;
  BOOL _enableCodeBlockPress;
  BOOL _streamingAnimation;
  ENRMTableStreamingMode _tableStreamingMode;
  ENRMCodeBlockStreamingMode _codeBlockStreamingMode;
  ENRMMediaStreamingMode _mediaStreamingMode;
  BOOL _forceHeightUpdateOnNextRender;

  size_t _renderedStyleFingerprint;
  size_t _pendingStyleFingerprint;

  NSUInteger _previousTextLength;
  ENRMTailFadeInAnimator *_fadeAnimator;

  // Reused by the next render on the render queue (see ENRMTextRenderCache); a recycled view
  // starts a new epoch, which drops it.
  ENRMTextRenderCache *_textRenderCache;
  NSUInteger _textRenderCacheEpoch;
  // The ENRMRenderResult revision the text view shows, which a patch must be based on.
  uint64_t _renderedRevision;

  AccessibilityInfo *_accessibilityInfo;
  ENRMAccessibilityLabels *_accessibilityLabels;
#if !TARGET_OS_OSX
  NSMutableArray<UIAccessibilityElement *> *_accessibilityElements;
#else
  NSMutableArray *_accessibilityElements;
#endif
  BOOL _accessibilityNeedsRebuild;

  ENRMLinkContextMenus *_linkContextMenus;
  NSArray<NSString *> *_contextMenuItemTexts;
  NSArray<NSString *> *_contextMenuItemIcons;
  ENRMSelectionMenuConfig _selectionMenuConfig;
  ENRMSelectionMenuLabels _selectionMenuLabels;

  ENRMSpoilerOverlayManager *_spoilerManager;

  NSLineBreakStrategy _lineBreakStrategy;

  NSInteger _numberOfLines;
  NSLineBreakMode _ellipsizeLineBreakMode;

  ENRMWritingDirectionMode _writingDirectionMode;
  NSWritingDirection _resolvedLayoutDirection;

  ENRMDirtyFlags _dirtyFlags;

  ENRMLaidOutSize _laidOutSize;
  // The markdown the text was rendered from, published with its size.
  std::shared_ptr<const std::string> _laidOutMarkdown;

  ENRMLatexErrorCoordinator *_latexErrorCoordinator;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<EnrichedMarkdownTextComponentDescriptor>();
}

+ (ENRMMd4cFlags *)flagsFromProps:(const EnrichedMarkdownTextMd4cFlagsStruct &)props
{
  return ENRMMd4cFlagsFromProps(props);
}

#pragma mark - Measuring and State

/// The box the text actually lives in: `self.bounds` inset by the
/// `containerStyle` border and padding.
///
/// Yoga hands `measureContent` an available size that already excludes those
/// insets, and `RCTViewComponentView` sizes `contentView` (our text view) to
/// `layoutMetrics.getContentFrame()`, so the shadow node's height and the text
/// view's frame are both content-box quantities. Measuring at `self.bounds`
/// instead overshoots by the horizontal insets, and because
/// `ENRMMeasureTextLayout` measures by resizing the live display container and
/// leaves it there (UIKit never re-syncs it - `widthTracksTextView` does not
/// apply with `scrollEnabled = NO`), the overshoot becomes the layout the user
/// sees: glyphs spill past the text view and get clipped, while the taller
/// content-width height Yoga committed shows up as blank space at the bottom.
///
/// The text view's frame is authoritative, so this is zero-sized both before the
/// first layout metrics arrive and when the insets consume the whole component
/// width. Neither may fall back to `self.bounds`: that is the padded border box,
/// and in the second case it is a real layout the text would then be drawn
/// across. Callers skip measuring and laying out at a zero width instead.
///
/// The frame, not the bounds: a `UITextView` is a scroll view, so its
/// `bounds.origin` is the content offset rather than the inset the segments of
/// `EnrichedMarkdown` get from the matching method.
- (CGRect)contentBounds
{
  return _textView.frame;
}

- (CGSize)measureSize:(CGFloat)maxWidth
{
  CGSize size = ENRMMeasureMarkdownText(_textView, maxWidth, _config, _allowTrailingMargin, _lastElementMarginBottom);
  if (CGSizeEqualToSize(size, CGSizeZero)) {
    _laidOutSize.clear();
    CGFloat defaultHeight = UIFontLineHeight([UIFont systemFontOfSize:16.0]);
    return CGSizeMake(maxWidth, defaultHeight);
  }
  _laidOutSize.store(maxWidth, size, _laidOutMarkdown);
  return size;
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

- (void)updateState:(const facebook::react::State::Shared &)state
           oldState:(const facebook::react::State::Shared &)oldState
{
  _state = std::static_pointer_cast<const EnrichedMarkdownTextShadowNode::ConcreteState>(state);

  if (oldState == nullptr) {
    [self requestHeightUpdate];
  }
}

/// Picks up the Yoga-resolved direction inherited from any ancestor `direction`
/// style. In FirstStrong mode the direction feeds the neutral-paragraph
/// fallback, so a change requires a re-render of the cached markdown.
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
    if (_writingDirectionMode == ENRMWritingDirectionModeFirstStrong && _cachedMarkdown.length > 0) {
      [self renderMarkdownContent:_cachedMarkdown];
    }
  }
}

- (void)requestHeightUpdate
{
  ENRMRequestHeightUpdate<EnrichedMarkdownTextState>(_state, _heightUpdateCounter, self);
}

// A block image resolved its box height after loading (maxHeight/aspectRatio
// sizing). The shadow node measured — and cached — this markdown with the
// pre-load fallback height, so drop those entries and re-measure.
- (void)imageAttachmentDidResolveLayout
{
  // The text around the attachment moved, and the spoiler overlays with it.
  [_spoilerManager setNeedsUpdate];
  [_spoilerManager updateIfNeeded];

  if (_renderedMarkdown.length > 0) {
    facebook::react::MeasurementCache::shared().removeMatchingMarkdown(std::string(_renderedMarkdown.UTF8String));
  }

  CGRect contentBounds = [self contentBounds];
  if (contentBounds.size.width > 0) {
    CGSize measured = [self measureSize:contentBounds.size.width];
    if (needsHeightUpdate(measured, contentBounds)) {
      [self requestHeightUpdate];
    }
  }
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const EnrichedMarkdownTextProps>();
    _props = defaultProps;

    self.backgroundColor = [RCTUIColor clearColor];
    _parser = [[ENRMMarkdownParser alloc] init];
    _linkContextMenus = [[ENRMLinkContextMenus alloc] init];
    __weak EnrichedMarkdownText *weakMenuSelf = self;
    _linkContextMenus.onPress = ^(NSString *url, NSString *pattern, NSString *itemText) {
      [weakMenuSelf emitLinkContextMenuItemPress:itemText pattern:pattern url:url];
    };
    _md4cFlags = [EnrichedMarkdownText flagsFromProps:defaultProps->md4cFlags];
    _isGFM = defaultProps->isGFM;
    _linkRegex = ENRMLinkRegexConfigFromProps(defaultProps->linkRecognition.text);
    _inlineCodeLinkRegex = ENRMLinkRegexConfigFromProps(defaultProps->linkRecognition.inlineCode);

    _renderCoordinator =
        [[ENRMAsyncRenderCoordinator alloc] initWithQueueLabel:"com.swmansion.enriched.markdown.render"];

    __weak __typeof(self) weakLatexSelf = self;
    _latexErrorCoordinator =
        [[ENRMLatexErrorCoordinator alloc] initWithEmit:^BOOL(NSString *source, NSString *message, BOOL displayMode) {
          __typeof(self) strongSelf = weakLatexSelf;
          if (!strongSelf)
            return NO;
          auto emitter = std::static_pointer_cast<EnrichedMarkdownTextEventEmitter const>(strongSelf->_eventEmitter);
          if (!emitter)
            return NO;
          emitter->onLatexError({
              .source = std::string(source.UTF8String ?: ""),
              .message = std::string(message.UTF8String ?: ""),
              .displayMode = displayMode ? true : false,
          });
          return YES;
        }];
    _maxFontSizeMultiplier = 0;
    _allowTrailingMargin = NO;
    _enableLinkPreview = YES;
    _enableTaskListItemToggle = YES;
    _enableImagePress = NO;
    _enableTextPress = NO;
    _enableCodeBlockPress = NO;
    _forceHeightUpdateOnNextRender = NO;
    _selectionMenuConfig = (ENRMSelectionMenuConfig){.copyAsMarkdown = YES, .copyImageURL = YES};
    _lineBreakStrategy = NSLineBreakStrategyNone;
    _numberOfLines = 0;
    _ellipsizeLineBreakMode = NSLineBreakByTruncatingTail;
    _writingDirectionMode = ENRMWritingDirectionModeFirstStrong;
    _resolvedLayoutDirection =
        [[RCTI18nUtil sharedInstance] isRTL] ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;
    _dirtyFlags = ENRMDirtyNone;
    _tableStreamingMode = ENRMTableStreamingModeProgressive;
    _codeBlockStreamingMode = ENRMCodeBlockStreamingModeProgressive;
    _mediaStreamingMode = ENRMMediaStreamingModeProgressive;

    _fontScaleObserver = [[FontScaleObserver alloc] init];
    _textRenderCache = [[ENRMTextRenderCache alloc] init];
    __weak EnrichedMarkdownText *weakSelf = self;
    _fontScaleObserver.onChange = ^{
      EnrichedMarkdownText *strongSelf = weakSelf;
      if (!strongSelf)
        return;
      if (strongSelf->_config != nil) {
        [strongSelf->_config setFontScaleMultiplier:strongSelf->_fontScaleObserver.effectiveFontScale];
      }
      if (strongSelf->_cachedMarkdown != nil && strongSelf->_cachedMarkdown.length > 0) {
        strongSelf->_forceHeightUpdateOnNextRender = YES;
        [strongSelf renderMarkdownContent:strongSelf->_cachedMarkdown];
      }
    };

    [self setupTextView];
  }

  return self;
}

- (void)setupTextView
{
  __weak EnrichedMarkdownText *weakCopyOwner = self;
  void (^copySelectionHandler)(NSRange) = ^(NSRange range) {
    EnrichedMarkdownText *owner = weakCopyOwner;
    if (!owner)
      return;
    NSAttributedString *text = owner->_textView.textStorage;
    ENRMCopySelection([text attributedSubstringFromRange:range], range,
                      markdownForRange(text, range, owner->_cachedMarkdown), owner -> _config,
                      [owner selectionCopyHandler]);
  };
#if !TARGET_OS_OSX
  ENRMMarkdownTextView *markdownTextView = [[ENRMMarkdownTextView alloc] init];
  markdownTextView.copySelectionHandler = copySelectionHandler;
  _textView = markdownTextView;
  _textView.text = @"";
#else
  ENRMContextMenuTextView *contextMenuTextView = [[ENRMContextMenuTextView alloc] init];
  contextMenuTextView.copySelectionHandler = copySelectionHandler;
  _textView = contextMenuTextView;
  _textView.string = @"";
#endif
  ENRMConfigureMarkdownTextView(_textView);
  _textView.delegate = self;
  _textView.hidden = YES;

#if TARGET_OS_OSX
  __weak EnrichedMarkdownText *weakSelf = self;
  ((ENRMContextMenuTextView *)_textView).contextMenuProvider =
      ^NSMenu *_Nullable(NSMenu *baseMenu, NSTextView *textView)
  {
    EnrichedMarkdownText *strongSelf = weakSelf;
    if (!strongSelf) {
      return baseMenu;
    }
    NSArray<NSMenuItem *> *customItems = ENRMBuildContextMenuItems(
        strongSelf->_contextMenuItemTexts, strongSelf->_contextMenuItemIcons, textView,
        ^(NSString *itemText, NSString *selectedText, NSUInteger selectionStart, NSUInteger selectionEnd) {
          [strongSelf emitContextMenuItemPress:itemText
                                  selectedText:selectedText
                                selectionStart:selectionStart
                                  selectionEnd:selectionEnd];
        });
    return buildEditMenuForSelection(textView.textStorage, textView.selectedRange, strongSelf->_cachedMarkdown,
                                     strongSelf->_config, @[ baseMenu ], customItems,
                                     strongSelf -> _selectionMenuConfig, [strongSelf selectionCopyHandler]);
  };
#endif

  ENRMTapRecognizer *tapRecognizer = [[ENRMTapRecognizer alloc] initWithTarget:self action:@selector(textTapped:)];
  [_textView addGestureRecognizer:tapRecognizer];

  self.contentView = _textView;
}

- (void)didAddSubview:(RCTUIView *)subview
{
  [super didAddSubview:subview];

  if (subview == _textView) {
    [self setupLayoutManager];
  }
}

- (void)willRemoveSubview:(RCTUIView *)subview
{
  if (subview == _textView) {
    ENRMDetachLayoutManager(_textView);
  }
  [super willRemoveSubview:subview];
}

- (void)setupLayoutManager
{
  ENRMAttachLayoutManager(_textView, _config);
}

- (void)renderMarkdownContent:(NSString *)markdownString
{
  [self renderMarkdownContent:markdownString synchronously:NO];
}

// Parses on the render queue and applies on the main queue, unless
// `synchronously`: then both run here and any render in flight is dropped.
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
  NSLineBreakStrategy lineBreakStrategy = _lineBreakStrategy;
  ENRMWritingDirectionMode writingDirectionMode = _writingDirectionMode;
  NSWritingDirection resolvedLayoutDirection = _resolvedLayoutDirection;
  BOOL streamingAnimation = _streamingAnimation;
  ENRMTableStreamingMode tableStreamingMode = _tableStreamingMode;
  ENRMCodeBlockStreamingMode codeBlockStreamingMode = _codeBlockStreamingMode;
  ENRMMediaStreamingMode mediaStreamingMode = _mediaStreamingMode;
  // The render queue owns the cache; a synchronous render leaves it alone.
  ENRMTextRenderCache *textRenderCache = synchronously ? nil : _textRenderCache;
  NSArray *textRenderKey =
      ENRMTextRenderKey(config, _pendingStyleFingerprint, allowFontScaling, maxFontSizeMultiplier, lineBreakStrategy,
                        writingDirectionMode, resolvedLayoutDirection, _textRenderCacheEpoch);

  __block ENRMRenderResult *result = nil;

  BOOL (^render)(void) = ^BOOL {
    NSString *renderableMarkdown =
        streamingAnimation ? ENRMRenderableMarkdownForStreaming(markdownString, md4cFlags, tableStreamingMode,
                                                                codeBlockStreamingMode, mediaStreamingMode, NULL)
                           : markdownString;
    MarkdownASTNode *ast = [parser parseMarkdown:renderableMarkdown
                                           flags:md4cFlags
                                           isGFM:isGFM
                                       linkRegex:linkRegex
                             inlineCodeLinkRegex:inlineCodeLinkRegex];
    if (!ast)
      return NO;

    if (textRenderCache) {
      [textRenderCache beginRenderWithKey:textRenderKey];
      result = ENRMRenderTextCached(ast.children, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier,
                                    lineBreakStrategy, writingDirectionMode, resolvedLayoutDirection, textRenderCache);
      [textRenderCache endRender];
      return YES;
    }
    result = ENRMRenderASTNodes(ast.children, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier,
                                lineBreakStrategy);
    ENRMApplyWritingDirectionMode(result.attributedText, writingDirectionMode, resolvedLayoutDirection);
    return YES;
  };
  // What this render answers, taken now: an older render can still apply after a
  // newer one is scheduled, and must not claim the newer one's style or forced height.
  const size_t styleFingerprint = _pendingStyleFingerprint;
  const BOOL forceHeightUpdate = _forceHeightUpdateOnNextRender;
  dispatch_block_t apply = ^{
    if (!result.attributedText && result.revision != self->_renderedRevision && ![self patchFits:result]) {
      // A patch to text this view doesn't show (a render it skipped): render in full.
      self->_textRenderCacheEpoch++;
      [self renderMarkdownContent:self->_cachedMarkdown];
      return;
    }
    self->_lastElementMarginBottom = result.lastElementMarginBottom;
    self->_accessibilityInfo = result.accessibilityInfo;
    self->_renderedStyleFingerprint = styleFingerprint;
    [self->_latexErrorCoordinator wireReporters:result.context.mathReporters];
    self->_laidOutMarkdown = ENRMLaidOutMarkdown(markdownString);
    [self applyRenderedText:result forceHeightUpdate:forceHeightUpdate];
  };

  if (synchronously) {
    [_renderCoordinator invalidate];
    // Its views show revisions the cache never made.
    _textRenderCacheEpoch++;
    // A first render reuses what Yoga's measurement rendered, when it matches.
    ENRMRenderResult *prepared =
        _renderedMarkdown.length == 0 && !_streamingAnimation
            ? ENRMTakePreparedText({_props, _fontScaleObserver.effectiveFontScale, resolvedLayoutDirection, nil})
            : nil;
    if (prepared) {
      result = prepared;
    } else if (!render()) {
      return;
    }
    apply();
    return;
  }
  [_renderCoordinator scheduleRender:render apply:apply];
}

- (NSMutableAttributedString *)parseAndRenderMarkdown:(NSString *)markdownString
{
  MarkdownASTNode *ast = [_parser parseMarkdown:markdownString
                                          flags:_md4cFlags
                                          isGFM:_isGFM
                                      linkRegex:_linkRegex
                            inlineCodeLinkRegex:_inlineCodeLinkRegex];
  if (!ast) {
    return nil;
  }

  ENRMRenderResult *result =
      ENRMRenderASTNodes(ast.children, _config, _allowTrailingMargin, _fontScaleObserver.allowFontScaling,
                         _maxFontSizeMultiplier, _lineBreakStrategy);
  ENRMApplyWritingDirectionMode(result.attributedText, _writingDirectionMode, _resolvedLayoutDirection);

  _lastElementMarginBottom = result.lastElementMarginBottom;
  _accessibilityInfo = result.accessibilityInfo;

  return result.attributedText;
}

/// Synchronous rendering for mock view measurement (no UI updates needed).
- (void)renderMarkdownSynchronously:(NSString *)markdownString
{
  if (!markdownString || markdownString.length == 0) {
    return;
  }

  _renderCoordinator.blockAsyncRender = YES;
  _cachedMarkdown = [markdownString copy];

  NSString *renderableMarkdown =
      _streamingAnimation ? ENRMRenderableMarkdownForStreaming(markdownString, _md4cFlags, _tableStreamingMode,
                                                               _codeBlockStreamingMode, _mediaStreamingMode, NULL)
                          : markdownString;
  NSMutableAttributedString *attributedText = [self parseAndRenderMarkdown:renderableMarkdown];
  if (!attributedText) {
    return;
  }

  _textView.attributedText = attributedText;
  _renderedRevision = 0;
  _renderedMarkdown = [_cachedMarkdown copy];
  _laidOutMarkdown = ENRMLaidOutMarkdown(markdownString);
  _renderedStyleFingerprint = _pendingStyleFingerprint;
}

// Kept in sync with the view-free measurement so the rendered line count matches
// the measured height: both clamp a layout performed at the content width (see
// contentBounds), so the truncation falls on the same word.
// numberOfLines == 0 restores the unlimited default.
- (void)applyLineClampToTextContainer
{
  if (_numberOfLines > 0) {
    _textView.textContainer.maximumNumberOfLines = _numberOfLines;
    _textView.textContainer.lineBreakMode = _ellipsizeLineBreakMode;
  } else {
    _textView.textContainer.maximumNumberOfLines = 0;
    _textView.textContainer.lineBreakMode = NSLineBreakByWordWrapping;
  }
}

/// `scheduledForceHeight` is the forced-height request set when this render was
/// scheduled; one set since stays for the newer render it belongs to.
// A patch fits only the text it was made from: one past the end of the shown text is missed too.
- (BOOL)patchFits:(ENRMRenderResult *)result
{
  return result.patchTail && result.patchBaseRevision == _renderedRevision &&
         result.patchStart <= _textView.textStorage.length;
}

- (void)applyRenderedText:(ENRMRenderResult *)result forceHeightUpdate:(BOOL)scheduledForceHeight
{
  const BOOL patches = [self patchFits:result];
  NSMutableAttributedString *attributedText = result.attributedText;
  NSUInteger tailStart = _previousTextLength;

  NSLayoutManager *layoutManager = _textView.layoutManager;
  if ([layoutManager isKindOfClass:[TextViewLayoutManager class]]) {
    [layoutManager setValue:_config forKey:@"config"];
  }

  objc_setAssociatedObject(_textView.textContainer, kTextViewKey, _textView, OBJC_ASSOCIATION_ASSIGN);

  // Ensure the text container has unlimited height before setting content.
  // updateLayoutMetrics may have shrunk the frame (and thus the text container)
  // from a previous layout pass, which would clip the new attributed text.
  CGRect contentBounds = [self contentBounds];
  CGFloat containerWidth = contentBounds.size.width;
  if (containerWidth <= 0) {
    containerWidth = _textView.textContainer.size.width;
  }
  _textView.textContainer.size = CGSizeMake(containerWidth, CGFLOAT_MAX);
  [self applyLineClampToTextContainer];

  _accessibilityElements = nil;
  _accessibilityNeedsRebuild = YES;

  // Restores the faded colors onto the text they came from.
  [_fadeAnimator cancel];
  if (patches) {
    NSTextStorage *storage = _textView.textStorage;
    [storage beginEditing];
    [storage replaceCharactersInRange:NSMakeRange(result.patchStart, storage.length - result.patchStart)
                 withAttributedString:result.patchTail];
    [storage endEditing];
  } else if (attributedText) {
    _textView.attributedText = attributedText;
    [_textView.layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, attributedText.length)
                                          actualCharacterRange:NULL];
  }
  // Otherwise the view shows this text already (the cache handed the same segment back).
  _renderedRevision = result.revision;
  _renderedMarkdown = [_cachedMarkdown copy];
  if (!self.window) {
    _needsWindowAttachRefresh = contentBounds.size.width <= 0;
  }

  // When bounds width is zero (recycled view not yet laid out), skip layout
  // and measurement — layoutSubviews will handle it once the view has real
  // bounds. Measuring with width=0 produces a bogus single-line measurement
  // that corrupts the height sent to Yoga.
  [_spoilerManager setNeedsUpdate];

  if (contentBounds.size.width > 0) {
    // Font/style changes can produce the same measured size before UIKit has
    // fully refreshed layout, so force one Yoga update after those renders.
    BOOL forceHeightUpdate = scheduledForceHeight && _forceHeightUpdateOnNextRender;
    if (forceHeightUpdate) {
      _forceHeightUpdateOnNextRender = NO;
    }

    [_textView.layoutManager ensureLayoutForTextContainer:_textView.textContainer];
    ENRMSetNeedsDisplay(_textView);
#if !TARGET_OS_OSX
    [self setNeedsLayout];
#endif

    [_spoilerManager updateIfNeeded];

    CGSize measured = [self measureSize:contentBounds.size.width];
    if (forceHeightUpdate || needsHeightUpdate(measured, contentBounds)) {
      [self requestHeightUpdate];
    }
  }

  if (_textView.hidden) {
    dispatch_async(dispatch_get_main_queue(), ^{ self->_textView.hidden = NO; });
  }

  if (_streamingAnimation) {
    if (!_fadeAnimator) {
      _fadeAnimator = [[ENRMTailFadeInAnimator alloc] initWithTextView:_textView];
    }
    [_fadeAnimator animateFrom:tailStart to:result.textLength];
    _previousTextLength = result.textLength;
  }
}

#if !TARGET_OS_OSX
- (void)layoutSubviews
{
  [super layoutSubviews];
  [_spoilerManager updateIfNeeded];
}
#endif

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<EnrichedMarkdownTextProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<EnrichedMarkdownTextProps const>(props);

  if (oldViewProps.markdown != newViewProps.markdown) {
    _dirtyFlags |= ENRMDirtyRender;
  }

  if (_config == nil) {
    _config = [[StyleConfig alloc] init];
    [_config setFontScaleMultiplier:_fontScaleObserver.effectiveFontScale];
    _spoilerManager = [[ENRMSpoilerOverlayManager alloc] initWithTextView:_textView config:_config];
  }

  if (applyMarkdownStyleToConfig(_config, newViewProps.markdownStyle, oldViewProps.markdownStyle)) {
    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  if (ENRMImageRequestHeadersChanged(oldViewProps.imageRequestHeaders, newViewProps.imageRequestHeaders)) {
    [_config setImageRequestHeaders:ENRMImageRequestHeadersFromProps(newViewProps.imageRequestHeaders)];
    _dirtyFlags |= ENRMDirtyRender;
  }

  // Pill labels change layout, so treat new content like a style change.
  if (ENRMLinkPillContentChanged(oldViewProps.linkPillContent, newViewProps.linkPillContent)) {
    [_config setLinkPillContent:ENRMLinkPillContentFromProps(newViewProps.linkPillContent)];
    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  NSLayoutManager *layoutManager = _textView.layoutManager;
  if ([layoutManager isKindOfClass:[TextViewLayoutManager class]]) {
    StyleConfig *currentConfig = [layoutManager valueForKey:@"config"];
    if (currentConfig != _config) {
      [layoutManager setValue:_config forKey:@"config"];
    }
  }

  if (_textView.selectable != newViewProps.selectable) {
    _textView.selectable = newViewProps.selectable;
  }

  if (newViewProps.selectionColor != oldViewProps.selectionColor) {
    ENRMApplySelectionColor(_textView, newViewProps.selectionColor);
  }

  if (newViewProps.allowFontScaling != oldViewProps.allowFontScaling) {
    _fontScaleObserver.allowFontScaling = newViewProps.allowFontScaling;

    if (_config != nil) {
      [_config setFontScaleMultiplier:_fontScaleObserver.effectiveFontScale];
    }

    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  if (newViewProps.maxFontSizeMultiplier != oldViewProps.maxFontSizeMultiplier) {
    _maxFontSizeMultiplier = newViewProps.maxFontSizeMultiplier;

    if (_config != nil) {
      [_config setMaxFontSizeMultiplier:_maxFontSizeMultiplier];
    }

    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  if (newViewProps.allowTrailingMargin != oldViewProps.allowTrailingMargin) {
    _allowTrailingMargin = newViewProps.allowTrailingMargin;
    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  if (!ENRMLinkRegexPropsEqual(oldViewProps.linkRecognition.text, newViewProps.linkRecognition.text)) {
    _linkRegex = ENRMLinkRegexConfigFromProps(newViewProps.linkRecognition.text);
    _dirtyFlags |= ENRMDirtyRender;
    _forceHeightUpdateOnNextRender = YES;
  }
  if (!ENRMLinkRegexPropsEqual(oldViewProps.linkRecognition.inlineCode, newViewProps.linkRecognition.inlineCode)) {
    _inlineCodeLinkRegex = ENRMLinkRegexConfigFromProps(newViewProps.linkRecognition.inlineCode);
    _dirtyFlags |= ENRMDirtyRender;
    _forceHeightUpdateOnNextRender = YES;
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
    _md4cFlags = [EnrichedMarkdownText flagsFromProps:newViewProps.md4cFlags];
    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  if (newViewProps.isGFM != oldViewProps.isGFM) {
    _isGFM = newViewProps.isGFM;
    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  _enableLinkPreview = newViewProps.enableLinkPreview;
  _enableTaskListItemToggle = newViewProps.enableTaskListItemToggle;
  _enableImagePress = newViewProps.enableImagePress;
  _enableTextPress = newViewProps.enableTextPress;
  _enableCodeBlockPress = newViewProps.enableCodeBlockPress;

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
    _accessibilityNeedsRebuild = YES;
  }

  if (newViewProps.streamingAnimation != oldViewProps.streamingAnimation) {
    _streamingAnimation = newViewProps.streamingAnimation;
    // The streaming session decides what renders, so the text renders again.
    _dirtyFlags |= ENRMDirtyRender;
    if (_streamingAnimation) {
      _previousTextLength = ENRMGetAttributedText(_textView).length;
    } else {
      [_fadeAnimator cancel];
      _fadeAnimator = nil;
      _previousTextLength = 0;
    }
  }

  // The modes decide what renders only while streaming.
  if (newViewProps.streamingConfig.tableMode != oldViewProps.streamingConfig.tableMode) {
    _tableStreamingMode = ENRMStreamingModeFromString<ENRMTableStreamingMode>(newViewProps.streamingConfig.tableMode);
    _dirtyFlags |= _streamingAnimation ? ENRMDirtyRender : ENRMDirtyNone;
  }
  if (newViewProps.streamingConfig.codeBlockMode != oldViewProps.streamingConfig.codeBlockMode) {
    _codeBlockStreamingMode =
        ENRMStreamingModeFromString<ENRMCodeBlockStreamingMode>(newViewProps.streamingConfig.codeBlockMode);
    _dirtyFlags |= _streamingAnimation ? ENRMDirtyRender : ENRMDirtyNone;
  }
  if (newViewProps.streamingConfig.mediaMode != oldViewProps.streamingConfig.mediaMode) {
    _mediaStreamingMode = ENRMStreamingModeFromString<ENRMMediaStreamingMode>(newViewProps.streamingConfig.mediaMode);
    _dirtyFlags |= _streamingAnimation ? ENRMDirtyRender : ENRMDirtyNone;
  }

  if (newViewProps.spoilerOverlay != oldViewProps.spoilerOverlay) {
    NSString *modeStr = [[NSString alloc] initWithUTF8String:newViewProps.spoilerOverlay.c_str()];
    _spoilerManager.spoilerOverlay = ENRMSpoilerOverlayFromString(modeStr);
  }

  if (newViewProps.lineBreakStrategyIOS != oldViewProps.lineBreakStrategyIOS) {
    NSString *strategy = [[NSString alloc] initWithUTF8String:newViewProps.lineBreakStrategyIOS.c_str()];
    _lineBreakStrategy = ENRMResolveLineBreakStrategy(strategy);
    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  if (newViewProps.writingDirection != oldViewProps.writingDirection) {
    NSString *value = [[NSString alloc] initWithUTF8String:newViewProps.writingDirection.c_str()];
    _writingDirectionMode = ENRMResolveWritingDirectionMode(value);
    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  if (newViewProps.numberOfLines != oldViewProps.numberOfLines) {
    _numberOfLines = (NSInteger)newViewProps.numberOfLines;
    [self applyLineClampToTextContainer];
    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  if (newViewProps.ellipsizeMode != oldViewProps.ellipsizeMode) {
    _ellipsizeLineBreakMode =
        ENRMResolveEllipsizeLineBreakMode([[NSString alloc] initWithUTF8String:newViewProps.ellipsizeMode.c_str()]);
    [self applyLineClampToTextContainer];
    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  if (_dirtyFlags & ENRMDirtyRender) {
    _pendingStyleFingerprint =
        computeStyleFingerprint(newViewProps.markdownStyle) ^ std::hash<bool>{}(newViewProps.allowTrailingMargin);
    // Rendered in finalizeUpdates, once the view has its layout metrics.
    _pendingRenderMarkdown = ENRMStringFromUTF8(newViewProps.markdown);
    _dirtyFlags &= ~ENRMDirtyRender;
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)finalizeUpdates:(RNComponentViewUpdateMask)updateMask
{
  [super finalizeUpdates:updateMask];

  if (_pendingRenderMarkdown) {
    NSString *markdown = _pendingRenderMarkdown;
    _pendingRenderMarkdown = nil;
    // The first content renders inline: Yoga has already laid the view out at
    // its measured size, so an async render would show it empty (#1131).
    [self renderMarkdownContent:markdown synchronously:_renderedMarkdown.length == 0];
  }
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];

  if (!self.window) {
    _needsWindowAttachRefresh = YES;
    return;
  }
  if (_renderedMarkdown == nil) {
    return;
  }
  _textView.hidden = NO;
  BOOL refresh = _needsWindowAttachRefresh;
  _needsWindowAttachRefresh = NO;
  if (refresh) {
    // Refresh in place: RCTViewComponentView owns the text view's frame and has
    // already set it to the content frame, so re-assigning self.bounds here would
    // drop the containerStyle insets (see contentBounds).
    ENRMRefreshTextViewLayout(_textView);
  }

  [_spoilerManager setNeedsUpdate];
  [_spoilerManager updateIfNeeded];

  CGRect contentBounds = [self contentBounds];
  if (refresh && contentBounds.size.width > 0) {
    CGSize measured = [self measureSize:contentBounds.size.width];
    if (needsHeightUpdate(measured, contentBounds)) {
      [self requestHeightUpdate];
    }
  }
}

- (void)prepareForRecycle
{
  const auto resetProps = std::make_shared<const EnrichedMarkdownTextProps>();
  _props = resetProps;
  [_renderCoordinator invalidate];
  _laidOutSize.clear();
  _laidOutMarkdown = nullptr;

  [_fadeAnimator cancel];
  _fadeAnimator = nil;
  _previousTextLength = 0;
  _streamingAnimation = NO;
  _tableStreamingMode = ENRMTableStreamingModeProgressive;
  _codeBlockStreamingMode = ENRMCodeBlockStreamingModeProgressive;
  _mediaStreamingMode = ENRMMediaStreamingModeProgressive;
  _forceHeightUpdateOnNextRender = NO;
  _cachedMarkdown = nil;
  _renderedMarkdown = nil;
  _pendingRenderMarkdown = nil;
  _config = nil;
  _md4cFlags = [EnrichedMarkdownText flagsFromProps:resetProps->md4cFlags];
  _isGFM = resetProps->isGFM;
  _linkRegex = ENRMLinkRegexConfigFromProps(resetProps->linkRecognition.text);
  _inlineCodeLinkRegex = ENRMLinkRegexConfigFromProps(resetProps->linkRecognition.inlineCode);
  _maxFontSizeMultiplier = 0;
  _lastElementMarginBottom = 0;
  _allowTrailingMargin = NO;
  _lineBreakStrategy = NSLineBreakStrategyNone;
  _writingDirectionMode = ENRMWritingDirectionModeFirstStrong;
  _numberOfLines = 0;
  _ellipsizeLineBreakMode = NSLineBreakByTruncatingTail;
  [self applyLineClampToTextContainer];
  _renderedStyleFingerprint = 0;
  _pendingStyleFingerprint = 0;
  _linkContextMenus.entries = @[];
  _contextMenuItemTexts = nil;
  _contextMenuItemIcons = nil;
  _fontScaleObserver.allowFontScaling = resetProps->allowFontScaling;
  _accessibilityLabels = nil;
  _accessibilityElements = nil;
  _accessibilityInfo = nil;
  _accessibilityNeedsRebuild = NO;
  [_spoilerManager removeAllOverlays];
  _spoilerManager = nil;
  if (_textView != nil) {
    ENRMSetAttributedText(_textView, [[NSAttributedString alloc] initWithString:@""]);
    _textView.hidden = YES;
  }
  _renderedRevision = 0;
  _textRenderCacheEpoch++;

  [super prepareForRecycle];
}

Class<RCTComponentViewProtocol> EnrichedMarkdownTextCls(void)
{
  return EnrichedMarkdownText.class;
}

- (facebook::react::SharedTouchEventEmitter)touchEventEmitterAtPoint:(CGPoint)point
{
  if (_textView) {
    CGPoint textViewPoint = [self convertPoint:point toView:_textView];
    // Only where textTapped would emit, so a parent Pressable still gets the rest, as on Android.
    BOOL isTextPress = _enableTextPress && _textView.selectedRange.length == 0 &&
                       textPressIndexAtPoint(_textView, textViewPoint) != NSNotFound;
    if (isTextPress ||
        isPointOnInteractiveElement(_textView, textViewPoint, _enableImagePress, _enableCodeBlockPress)) {
      return nil;
    }
  }

  return [super touchEventEmitterAtPoint:point];
}

- (void)emitLinkPress:(NSString *)url
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownTextEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onLinkPress({.url = std::string(url.UTF8String)});
}

- (void)emitLinkLongPress:(NSString *)url
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownTextEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onLinkLongPress({.url = std::string(url.UTF8String)});
}

- (void)emitLinkContextMenuItemPress:(NSString *)itemText pattern:(NSString *)pattern url:(NSString *)url
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownTextEventEmitter const>(_eventEmitter);
  if (emitter) {
    emitter->onLinkContextMenuItemPress({.url = std::string(url.UTF8String),
                                         .pattern = std::string(pattern.UTF8String),
                                         .itemText = std::string(itemText.UTF8String)});
  }
}

- (void)emitTextPress:(NSInteger)index text:(NSString *)text
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownTextEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onTextPress({.index = (int)index, .text = std::string(text.UTF8String ?: "")});
}

- (void)emitImagePress:(NSString *)url altText:(NSString *)altText
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownTextEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onImagePress({.url = std::string(url.UTF8String ?: ""), .altText = std::string(altText.UTF8String ?: "")});
}

- (void)emitCodeBlockPress:(NSString *)code language:(NSString *)language
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownTextEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onCodeBlockPress(
        {.code = std::string(code.UTF8String ?: ""), .language = std::string(language.UTF8String ?: "")});
}

- (void)emitTaskListItemPress:(NSInteger)index checked:(BOOL)checked text:(NSString *)text
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownTextEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onTaskListItemPress({.index = (int)index, .checked = checked, .text = std::string(text.UTF8String ?: "")});
}

- (void)emitContextMenuItemPress:(NSString *)itemText
                    selectedText:(NSString *)selectedText
                  selectionStart:(NSUInteger)selectionStart
                    selectionEnd:(NSUInteger)selectionEnd
{
  auto emitter = std::static_pointer_cast<EnrichedMarkdownTextEventEmitter const>(_eventEmitter);
  if (emitter)
    emitter->onContextMenuItemPress({
        .itemText = std::string(itemText.UTF8String),
        .selectedText = std::string(selectedText.UTF8String),
        .selectionStart = (int)selectionStart,
        .selectionEnd = (int)selectionEnd,
    });
}

- (ENRMSelectionCopyHandler)selectionCopyHandler
{
  __weak EnrichedMarkdownText *weakSelf = self;
  return ^(NSString *text, NSString *format, NSRange range) {
    EnrichedMarkdownText *strongSelf = weakSelf;
    if (!strongSelf)
      return;
    auto emitter = std::static_pointer_cast<EnrichedMarkdownTextEventEmitter const>(strongSelf->_eventEmitter);
    if (emitter)
      emitter->onSelectionCopy({
          .text = std::string(text.UTF8String ?: ""),
          .format = std::string(format.UTF8String),
          .selectionStart = (int)range.location,
          .selectionEnd = (int)NSMaxRange(range),
      });
  };
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

  if (handleSpoilerTap(textView, recognizer, _spoilerManager)) {
    return;
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

  // Skip while text is selected so the tap clears the selection instead of
  // firing the press (matches the web guard).
  if (_enableCodeBlockPress && textView.selectedRange.length == 0) {
    NSDictionary<NSString *, NSString *> *codeBlock = codeBlockAtTapLocation(textView, recognizer);
    if (codeBlock) {
      [self emitCodeBlockPress:codeBlock[@"code"] language:codeBlock[@"language"]];
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

#pragma mark - UITextViewDelegate (Link Interaction)

#if !TARGET_OS_OSX
- (UITextItemMenuConfiguration *)textView:(UITextView *)textView
             menuConfigurationForTextItem:(UITextItem *)textItem
                              defaultMenu:(UIMenu *)defaultMenu API_AVAILABLE(ios(17.0))
{
  __weak EnrichedMarkdownText *weakSelf = self;
  return ENRMLinkMenuConfigurationForTextItem(textView, textItem, defaultMenu, _linkContextMenus, _enableLinkPreview,
                                              ^(NSString *url) { [weakSelf emitLinkLongPress:url]; });
}

- (ENRMLinkContextMenus *)linkContextMenusForTextView:(UITextView *)textView
{
  return _linkContextMenus;
}

- (BOOL)textView:(ENRMPlatformTextView *)textView
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

#pragma mark - UITextViewDelegate (Edit Menu)

// TODO: Remove API_AVAILABLE(ios(16.0)) guard when the minimum iOS deployment target in RN is bumped to 16.
- (UIMenu *)textView:(ENRMPlatformTextView *)textView
    editMenuForTextInRange:(NSRange)range
          suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions API_AVAILABLE(ios(16.0))
{
  __weak EnrichedMarkdownText *weakSelf = self;
  ENRMContextMenuPressHandler handler =
      ^(NSString *itemText, NSString *selectedText, NSUInteger selectionStart, NSUInteger selectionEnd) {
        EnrichedMarkdownText *strongSelf = weakSelf;
        if (strongSelf)
          [strongSelf emitContextMenuItemPress:itemText
                                  selectedText:selectedText
                                selectionStart:selectionStart
                                  selectionEnd:selectionEnd];
      };
  NSMutableArray<UIAction *> *customActions =
      ENRMBuildContextMenuActions(_contextMenuItemTexts, _contextMenuItemIcons, textView, range, handler);

  return buildEditMenuForSelection(textView.attributedText, range, _cachedMarkdown, _config, suggestedActions,
                                   customActions, _selectionMenuConfig, [self selectionCopyHandler]);
}
#endif

#pragma mark - Accessibility (VoiceOver Navigation)

- (void)rebuildAccessibilityElementsIfNeeded
{
  if (!_accessibilityNeedsRebuild) {
    return;
  }
  _accessibilityNeedsRebuild = NO;
#if !TARGET_OS_OSX
  _accessibilityElements = [MarkdownAccessibilityElementBuilder buildElementsForTextView:_textView
                                                                                    info:_accessibilityInfo
                                                                                  labels:_accessibilityLabels
                                                                               container:self];
#else
  _accessibilityElements = [NSMutableArray array];
#endif
}

- (BOOL)isAccessibilityElement
{
  return NO;
}

- (NSInteger)accessibilityElementCount
{
  [self rebuildAccessibilityElementsIfNeeded];
  return _accessibilityElements.count;
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
  [self rebuildAccessibilityElementsIfNeeded];
  if (index < 0 || index >= (NSInteger)_accessibilityElements.count) {
    return nil;
  }
  return _accessibilityElements[index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
  [self rebuildAccessibilityElementsIfNeeded];
  return [_accessibilityElements indexOfObject:element];
}

- (NSArray *)accessibilityElements
{
  [self rebuildAccessibilityElementsIfNeeded];
  return _accessibilityElements;
}

#if !TARGET_OS_OSX
- (NSArray<UIAccessibilityCustomRotor *> *)accessibilityCustomRotors
{
  [self rebuildAccessibilityElementsIfNeeded];
  return [MarkdownAccessibilityElementBuilder buildRotorsFromElements:_accessibilityElements
                                                               labels:_accessibilityLabels];
}
#endif

@end
