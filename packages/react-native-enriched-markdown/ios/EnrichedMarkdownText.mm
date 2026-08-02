#import "EnrichedMarkdownText.h"
#import "CodeBlockBackground.h"
#import "ContextMenuUtils.h"
#import "ENRMAccessibilityLabels.h"
#import "ENRMAsyncRenderCoordinator.h"
#import "ENRMAtomicSize.h"
#import "ENRMContextMenuTextView+macOS.h"
#import "ENRMImageAttachment.h"
#import "ENRMMarkdownParser.h"
#import "ENRMSpoilerOverlayManager.h"
#import "ENRMSpoilerTapUtils.h"
#import "ENRMTailFadeInAnimator.h"
#import "ENRMTextInteractionUtils.h"
#import "ENRMTextRenderer.h"
#import "ENRMTextViewSetup.h"
#import "ENRMUIKit.h"
#import "EditMenuUtils.h"
#import "FontScaleObserver.h"
#import "FontUtils.h"
#import "HeightUpdateUtils.h"
#import "ImageRequestHeaderUtils.h"
#import "LinkTapUtils.h"
#import "MarkdownASTNode.h"
#import "MarkdownAccessibilityElementBuilder.h"
#import "MarkdownExtractor.h"
#import "MeasurementCache.h"
#import "ParagraphStyleUtils.h"
#import "RuntimeKeys.h"
#import "SelectionColorUtils.h"
#import "StylePropsUtils.h"
#import "TaskListTapUtils.h"

#import <ReactNativeEnrichedMarkdown/EnrichedMarkdownTextComponentDescriptor.h>
#import <ReactNativeEnrichedMarkdown/EventEmitters.h>
#import <ReactNativeEnrichedMarkdown/Props.h>
#import <ReactNativeEnrichedMarkdown/RCTComponentViewHelpers.h>

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
- (void)applyRenderedText:(NSMutableAttributedString *)attributedText;
- (void)textTapped:(ENRMTapRecognizer *)recognizer;
- (void)setupLayoutManager;
- (void)emitLinkPress:(NSString *)url;
- (void)emitLinkLongPress:(NSString *)url;
- (void)emitTaskListItemPress:(NSInteger)index checked:(BOOL)checked text:(NSString *)text;
- (void)emitContextMenuItemPress:(NSString *)itemText
                    selectedText:(NSString *)selectedText
                  selectionStart:(NSUInteger)selectionStart
                    selectionEnd:(NSUInteger)selectionEnd;
@end

@implementation EnrichedMarkdownText {
  ENRMPlatformTextView *_textView;
  ENRMMarkdownParser *_parser;
  NSString *_cachedMarkdown;
  NSString *_renderedMarkdown;
  StyleConfig *_config;
  ENRMMd4cFlags *_md4cFlags;

  ENRMAsyncRenderCoordinator *_renderCoordinator;

  EnrichedMarkdownTextShadowNode::ConcreteState::Shared _state;
  int _heightUpdateCounter;

  FontScaleObserver *_fontScaleObserver;
  CGFloat _maxFontSizeMultiplier;

  CGFloat _lastElementMarginBottom;
  BOOL _allowTrailingMargin;
  BOOL _enableLinkPreview;
  BOOL _streamingAnimation;
  BOOL _forceHeightUpdateOnNextRender;

  size_t _renderedStyleFingerprint;
  size_t _pendingStyleFingerprint;

  NSUInteger _previousTextLength;
  ENRMTailFadeInAnimator *_fadeAnimator;

  AccessibilityInfo *_accessibilityInfo;
  ENRMAccessibilityLabels *_accessibilityLabels;
#if !TARGET_OS_OSX
  NSMutableArray<UIAccessibilityElement *> *_accessibilityElements;
#else
  NSMutableArray *_accessibilityElements;
#endif
  BOOL _accessibilityNeedsRebuild;

  NSArray<NSString *> *_contextMenuItemTexts;
  NSArray<NSString *> *_contextMenuItemIcons;
  ENRMSelectionMenuConfig _selectionMenuConfig;
  ENRMSelectionMenuLabels _selectionMenuLabels;

  ENRMSpoilerOverlayManager *_spoilerManager;

  NSLineBreakStrategy _lineBreakStrategy;

  ENRMWritingDirectionMode _writingDirectionMode;
  NSWritingDirection _resolvedLayoutDirection;

  ENRMDirtyFlags _dirtyFlags;

  ENRMAtomicSize _lastCommittedSize;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<EnrichedMarkdownTextComponentDescriptor>();
}

+ (ENRMMd4cFlags *)flagsFromProps:(const EnrichedMarkdownTextMd4cFlagsStruct &)props
{
  ENRMMd4cFlags *flags = [ENRMMd4cFlags defaultFlags];
  flags.underline = props.underline;
  flags.superscript = props.superscript;
  flags.subscript = props.subscript;
  flags.latexMath = props.latexMath;
  flags.highlight = props.highlight;
  return flags;
}

#pragma mark - Measuring and State

- (CGSize)measureSize:(CGFloat)maxWidth
{
  CGSize size = ENRMMeasureMarkdownText(_textView, maxWidth, _config, _allowTrailingMargin, _lastElementMarginBottom);
  if (CGSizeEqualToSize(size, CGSizeZero)) {
    CGFloat defaultHeight = UIFontLineHeight([UIFont systemFontOfSize:16.0]);
    return CGSizeMake(maxWidth, defaultHeight);
  }
  return size;
}

- (CGSize)lastCommittedLayoutSize
{
  return _lastCommittedSize.load();
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

/// Yoga-resolved direction inherited from any ancestor `direction` style.
/// In FirstStrong mode this feeds the neutral-paragraph fallback, so a change
/// requires a re-render of the cached markdown.
- (void)updateLayoutMetrics:(const LayoutMetrics &)layoutMetrics
           oldLayoutMetrics:(const LayoutMetrics &)oldLayoutMetrics
{
  [super updateLayoutMetrics:layoutMetrics oldLayoutMetrics:oldLayoutMetrics];

  _lastCommittedSize.store(CGSizeMake(layoutMetrics.frame.size.width, layoutMetrics.frame.size.height));

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
  if (_renderedMarkdown.length > 0) {
    facebook::react::MeasurementCache::shared().removeMatchingMarkdown(std::string(_renderedMarkdown.UTF8String));
  }

  if (self.bounds.size.width > 0) {
    CGSize measured = [self measureSize:self.bounds.size.width];
    if (needsHeightUpdate(measured, self.bounds)) {
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
    _md4cFlags = [EnrichedMarkdownText flagsFromProps:defaultProps->md4cFlags];

    _renderCoordinator =
        [[ENRMAsyncRenderCoordinator alloc] initWithQueueLabel:"com.swmansion.enriched.markdown.render"];

    _maxFontSizeMultiplier = 0;
    _allowTrailingMargin = NO;
    _enableLinkPreview = YES;
    _forceHeightUpdateOnNextRender = NO;
    _selectionMenuConfig = (ENRMSelectionMenuConfig){.copyAsMarkdown = YES, .copyImageURL = YES};
    _lineBreakStrategy = NSLineBreakStrategyNone;
    _writingDirectionMode = ENRMWritingDirectionModeFirstStrong;
    _resolvedLayoutDirection =
        [[RCTI18nUtil sharedInstance] isRTL] ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;
    _dirtyFlags = ENRMDirtyNone;

    _fontScaleObserver = [[FontScaleObserver alloc] init];
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
#if !TARGET_OS_OSX
  _textView = [[ENRMPlatformTextView alloc] init];
  _textView.text = @"";
#else
  _textView = [[ENRMContextMenuTextView alloc] init];
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
                                     strongSelf->_config, @[ baseMenu ], customItems, strongSelf->_selectionMenuConfig);
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
  if (_renderCoordinator.blockAsyncRender)
    return;

  _cachedMarkdown = [markdownString copy];

  StyleConfig *config = [_config copy];
  ENRMMarkdownParser *parser = _parser;
  ENRMMd4cFlags *md4cFlags = [_md4cFlags copy];

  BOOL allowFontScaling = _fontScaleObserver.allowFontScaling;
  CGFloat maxFontSizeMultiplier = _maxFontSizeMultiplier;
  BOOL allowTrailingMargin = _allowTrailingMargin;
  NSLineBreakStrategy lineBreakStrategy = _lineBreakStrategy;
  ENRMWritingDirectionMode writingDirectionMode = _writingDirectionMode;
  NSWritingDirection resolvedLayoutDirection = _resolvedLayoutDirection;

  __block ENRMRenderResult *result = nil;

  [_renderCoordinator
      scheduleRender:^BOOL {
        MarkdownASTNode *ast = [parser parseMarkdown:markdownString flags:md4cFlags];
        if (!ast)
          return NO;

        result = ENRMRenderASTNodes(ast.children, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier,
                                    lineBreakStrategy);
        ENRMApplyWritingDirectionMode(result.attributedText, writingDirectionMode, resolvedLayoutDirection);
        return YES;
      }
      apply:^{
        self->_lastElementMarginBottom = result.lastElementMarginBottom;
        self->_accessibilityInfo = result.accessibilityInfo;
        self->_renderedStyleFingerprint = self->_pendingStyleFingerprint;
        [self applyRenderedText:result.attributedText];
      }];
}

- (NSMutableAttributedString *)parseAndRenderMarkdown:(NSString *)markdownString
{
  MarkdownASTNode *ast = [_parser parseMarkdown:markdownString flags:_md4cFlags];
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

  NSMutableAttributedString *attributedText = [self parseAndRenderMarkdown:markdownString];
  if (!attributedText) {
    return;
  }

  _textView.attributedText = attributedText;
  _renderedMarkdown = [_cachedMarkdown copy];
  _renderedStyleFingerprint = _pendingStyleFingerprint;
}

- (void)applyRenderedText:(NSMutableAttributedString *)attributedText
{
  NSUInteger tailStart = _previousTextLength;

  NSLayoutManager *layoutManager = _textView.layoutManager;
  if ([layoutManager isKindOfClass:[TextViewLayoutManager class]]) {
    [layoutManager setValue:_config forKey:@"config"];
  }

  objc_setAssociatedObject(_textView.textContainer, kTextViewKey, _textView, OBJC_ASSOCIATION_ASSIGN);

  // Ensure the text container has unlimited height before setting content.
  // updateLayoutMetrics may have shrunk the frame (and thus the text container)
  // from a previous layout pass, which would clip the new attributed text.
  CGFloat containerWidth = _textView.textContainer.size.width;
  if (containerWidth <= 0) {
    containerWidth = self.bounds.size.width;
  }
  _textView.textContainer.size = CGSizeMake(containerWidth, CGFLOAT_MAX);

  _accessibilityElements = nil;
  _accessibilityNeedsRebuild = YES;

  _textView.attributedText = attributedText;
  _renderedMarkdown = [_cachedMarkdown copy];

  [_textView.layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, attributedText.length)
                                        actualCharacterRange:NULL];

  // When bounds width is zero (recycled view not yet laid out), skip layout
  // and measurement — layoutSubviews will handle it once the view has real
  // bounds. Measuring with width=0 produces a bogus single-line measurement
  // that corrupts the height sent to Yoga.
  [_spoilerManager setNeedsUpdate];

  if (self.bounds.size.width > 0) {
    // Font/style changes can produce the same measured size before UIKit has
    // fully refreshed layout, so force one Yoga update after those renders.
    BOOL forceHeightUpdate = _forceHeightUpdateOnNextRender;
    _forceHeightUpdateOnNextRender = NO;

    [_textView.layoutManager ensureLayoutForTextContainer:_textView.textContainer];
    ENRMSetNeedsDisplay(_textView);
#if !TARGET_OS_OSX
    [self setNeedsLayout];
#endif

    [_spoilerManager updateIfNeeded];

    CGSize measured = [self measureSize:self.bounds.size.width];
    if (forceHeightUpdate || needsHeightUpdate(measured, self.bounds)) {
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
    [_fadeAnimator animateFrom:tailStart to:attributedText.length];
    _previousTextLength = attributedText.length;
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
    [ENRMImageAttachment clearAttachmentRegistry];
    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  if (ENRMImageRequestHeadersChanged(oldViewProps.imageRequestHeaders, newViewProps.imageRequestHeaders)) {
    [_config setImageRequestHeaders:ENRMImageRequestHeadersFromProps(newViewProps.imageRequestHeaders)];
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

  if (newViewProps.md4cFlags.underline != oldViewProps.md4cFlags.underline ||
      newViewProps.md4cFlags.superscript != oldViewProps.md4cFlags.superscript ||
      newViewProps.md4cFlags.subscript != oldViewProps.md4cFlags.subscript ||
      newViewProps.md4cFlags.latexMath != oldViewProps.md4cFlags.latexMath ||
      newViewProps.md4cFlags.highlight != oldViewProps.md4cFlags.highlight) {
    _md4cFlags = [EnrichedMarkdownText flagsFromProps:newViewProps.md4cFlags];
    _forceHeightUpdateOnNextRender = YES;
    _dirtyFlags |= ENRMDirtyRender;
  }

  _enableLinkPreview = newViewProps.enableLinkPreview;

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
    if (_streamingAnimation) {
      _previousTextLength = ENRMGetAttributedText(_textView).length;
    } else {
      [_fadeAnimator cancel];
      _fadeAnimator = nil;
      _previousTextLength = 0;
    }
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

  if (_dirtyFlags & ENRMDirtyRender) {
    _pendingStyleFingerprint =
        computeStyleFingerprint(newViewProps.markdownStyle) ^ std::hash<bool>{}(newViewProps.allowTrailingMargin);
    NSString *markdownString = [[NSString alloc] initWithUTF8String:newViewProps.markdown.c_str()];
    [self renderMarkdownContent:markdownString];
    _dirtyFlags &= ~ENRMDirtyRender;
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];

  if (self.window && _renderedMarkdown != nil) {
    _textView.hidden = NO;
    ENRMRefreshTextViewAfterWindowAttach(_textView, self.bounds);

    [_spoilerManager setNeedsUpdate];
    [_spoilerManager updateIfNeeded];

    CGSize measured = [self measureSize:self.bounds.size.width];
    if (needsHeightUpdate(measured, self.bounds)) {
      [self requestHeightUpdate];
    }
  }
}

- (void)prepareForRecycle
{
  const auto resetProps = std::make_shared<const EnrichedMarkdownTextProps>();
  _props = resetProps;
  [_renderCoordinator invalidate];

  [_fadeAnimator cancel];
  _fadeAnimator = nil;
  _previousTextLength = 0;
  _streamingAnimation = NO;
  _forceHeightUpdateOnNextRender = NO;
  _cachedMarkdown = nil;
  _renderedMarkdown = nil;
  _config = nil;
  _md4cFlags = [EnrichedMarkdownText flagsFromProps:resetProps->md4cFlags];
  _maxFontSizeMultiplier = 0;
  _lastElementMarginBottom = 0;
  _allowTrailingMargin = NO;
  _lineBreakStrategy = NSLineBreakStrategyNone;
  _writingDirectionMode = ENRMWritingDirectionModeFirstStrong;
  _renderedStyleFingerprint = 0;
  _pendingStyleFingerprint = 0;
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
    if (isPointOnInteractiveElement(_textView, textViewPoint)) {
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

- (void)textTapped:(ENRMTapRecognizer *)recognizer
{
  ENRMPlatformTextView *textView = (ENRMPlatformTextView *)recognizer.view;

  if (handleTaskListTapWithSharedLogic(
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

  ENRMHandleTapOnTextView(textView, recognizer, ^(NSString *url) { [self emitLinkPress:url]; });
}

#pragma mark - UITextViewDelegate (Link Interaction)

#if !TARGET_OS_OSX
- (BOOL)textView:(ENRMPlatformTextView *)textView
    shouldInteractWithURL:(NSURL *)URL
                  inRange:(NSRange)characterRange
              interaction:(UITextItemInteraction)interaction
{
  if (interaction != UITextItemInteractionPresentActions) {
    return YES;
  }

  NSString *urlString = linkURLAtRange(textView, characterRange);

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
                                   customActions, _selectionMenuConfig);
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
