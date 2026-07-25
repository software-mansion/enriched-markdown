#import "EnrichedMarkdownTextInput.h"
#import "ContextMenuUtils.h"
#import "ENRMAutoLinkDetector.h"
#import "ENRMBlockHandler.h"
#import "ENRMBlockStore.h"
#import "ENRMDetectorPipeline.h"
#import "ENRMEditPipeline.h"
#import "ENRMEditSession.h"
#import "ENRMFormattingRange.h"
#import "ENRMFormattingStore.h"
#import "ENRMInputFormatter.h"
#import "ENRMInputLayoutManager.h"
#import "ENRMInputLinkPrompt.h"
#import "ENRMInputMentionCandidate.h"
#import "ENRMInputParser.h"
#import "ENRMInputTextView.h"
#import "ENRMLinkRegexConfig.h"
#import "ENRMMarkdownSerializer.h"
#import "ENRMStyleHandler.h"
#import "ENRMStyleMergingConfig.h"
#import "ENRMUIKit.h"
#import "ENRMWordsUtils.h"
#import "EnrichedMarkdownTextInput+Internal.h"
#import "InputStylePropsUtils.h"
#import "ParagraphStyleUtils.h"
#import "PasteboardUtils.h"
#import "SelectionColorUtils.h"
#import <QuartzCore/CABase.h>
#import <React/RCTI18nUtil.h>
#if TARGET_OS_OSX
#import <React/RCTBackedTextInputDelegate.h>
#endif

#import <ReactNativeEnrichedMarkdown/EnrichedMarkdownTextInputComponentDescriptor.h>
#import <ReactNativeEnrichedMarkdown/EventEmitters.h>
#import <ReactNativeEnrichedMarkdown/Props.h>
#import <ReactNativeEnrichedMarkdown/RCTComponentViewHelpers.h>

#import "EnrichedMarkdownTextInputShadowNode.h"
#import "HeightUpdateUtils.h"
#import "RCTFabricComponentsPlugins.h"
#import <React/RCTConversions.h>

using namespace facebook::react;

#if !TARGET_OS_OSX
@interface EnrichedMarkdownTextInput () <RCTEnrichedMarkdownTextInputViewProtocol, UITextViewDelegate,
                                         ENRMEditPipelineHost>
#else
@interface EnrichedMarkdownTextInput () <RCTEnrichedMarkdownTextInputViewProtocol, RCTBackedTextInputDelegate,
                                         ENRMEditPipelineHost>
#endif
- (void)setupTextView;
- (void)applyFormatting;
- (void)applyFormattingScopedToEditAtLocation:(NSUInteger)editLocation insertedLength:(NSUInteger)insertedLength;
- (void)toggleInlineStyle:(ENRMInputStyleType)styleType;
- (void)resetBaseTypingAttributes;
@end

@implementation EnrichedMarkdownTextInput {
  ENRMPlatformTextView *_textView;
  ENRMInputLayoutManager *_layoutManager;
  EnrichedMarkdownTextInputShadowNode::ConcreteState::Shared _state;
  int _heightUpdateCounter;
  ENRMInputFormatter *_formatter;
  ENRMInputFormatterStyle *_formatterStyle;
  ENRMFormattingStore *_formattingStore;
  ENRMBlockStore *_blockStore;
  NSMutableSet<NSNumber *> *_pendingStyles;
  NSMutableSet<NSNumber *> *_pendingStyleRemovals;
  BOOL _emitMarkdown;
  ENRMEditSession *_editSession;

  ENRMPlaceholderLabel *_placeholderLabel;

  NSUInteger _lastTextLength;
  NSRange _lastSelectedRange;
  NSRange _preEditSelectedRange;

  struct {
    BOOL bold, italic, underline, strikethrough, spoiler, link, initialized;
    NSInteger headingLevel;
    BOOL unorderedList;
    NSInteger unorderedListDepth;
    BOOL orderedList;
    NSInteger orderedListDepth;
  } _prevState;

  // Block type/level of the line being edited, captured before a text change so
  // a Return that continues a list (or an autocorrect/paste that replaces the
  // line) can restore the right block on the resulting line(s).
  ENRMInputBlockType _preEditBlockType;
  NSInteger _preEditBlockLevel;
  BOOL _preEditParagraphWasEmpty;
  // Whether the replaced range contained a line break, captured before the edit
  // applies (the deleted characters are gone afterwards). Drives the full-vs-
  // scoped reformat decision in handleTextChanged.
  BOOL _preEditReplacedNewline;

  std::optional<CGRect> _prevCaretRect;

#if TARGET_OS_OSX
  NSScrollView *_scrollView;
#endif

  NSArray<NSString *> *_contextMenuItemTexts;
  NSArray<NSString *> *_contextMenuItemIcons;
  NSArray<NSString *> *_mentionIndicators;
  NSString *_activeMentionIndicator;
  NSRange _activeMentionRange;
  NSString *_activeMentionText;

  ENRMAutoLinkDetector *_autoLinkDetector;
  ENRMDetectorPipeline *_detectorPipeline;
  ENRMEditPipeline *_editPipeline;

  ENRMWritingDirectionMode _writingDirectionMode;
  NSWritingDirection _resolvedLayoutDirection;

  ENRMInputSelectionMenuConfig _inputSelectionMenuConfig;
  ENRMFormatMenuConfig _formatMenuConfig;

  // Strong owners for the strings the two config structs above reference via
  // `__unsafe_unretained` pointers.
  NSString *_inputSelectionMenuFormatLabel;
  NSString *_inputSelectionMenuCopyAsMarkdownLabel;
  NSString *_formatMenuBoldLabel;
  NSString *_formatMenuItalicLabel;
  NSString *_formatMenuUnderlineLabel;
  NSString *_formatMenuStrikethroughLabel;
  NSString *_formatMenuSpoilerLabel;
  NSString *_formatMenuLinkLabel;
}

@synthesize editSession = _editSession;

#pragma mark - Fabric lifecycle

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<EnrichedMarkdownTextInputComponentDescriptor>();
}

+ (BOOL)shouldBeRecycled
{
  return NO;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const EnrichedMarkdownTextInputProps>();
    _props = defaultProps;

    self.backgroundColor = [RCTUIColor clearColor];
    _heightUpdateCounter = 0;
    _formatter = [[ENRMInputFormatter alloc] init];
    _formatterStyle = [[ENRMInputFormatterStyle alloc] init];
    _formattingStore = [[ENRMFormattingStore alloc] init];
    _blockStore = [[ENRMBlockStore alloc] init];
    _pendingStyles = [NSMutableSet set];
    _pendingStyleRemovals = [NSMutableSet set];
    _lastTextLength = 0;
    _lastSelectedRange = NSMakeRange(0, 0);
    _mentionIndicators = @[];
    _activeMentionRange = NSMakeRange(NSNotFound, 0);
    _activeMentionText = @"";

    _writingDirectionMode = ENRMWritingDirectionModeFirstStrong;
    _resolvedLayoutDirection =
        [[RCTI18nUtil sharedInstance] isRTL] ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;
    _inputSelectionMenuConfig = (ENRMInputSelectionMenuConfig){.format = YES, .copyAsMarkdown = YES};
    _formatMenuConfig = (ENRMFormatMenuConfig){
        .bold = YES, .italic = YES, .underline = YES, .strikethrough = YES, .spoiler = YES, .link = YES};

    [self setupTextView];
    _editSession = [[ENRMEditSession alloc] initWithTextView:_textView];

    [self setupDetectorPipeline];

    _editPipeline = [[ENRMEditPipeline alloc] initWithFormattingStore:_formattingStore
                                                           blockStore:_blockStore
                                                            formatter:_formatter
                                                     detectorPipeline:_detectorPipeline
                                                                 host:self];
  }
  return self;
}

- (void)setupDetectorPipeline
{
  _autoLinkDetector = [[ENRMAutoLinkDetector alloc] initWithTextStorage:_textView.textStorage
                                                        formattingStore:_formattingStore
                                                                  style:_formatterStyle];

  __weak EnrichedMarkdownTextInput *weakSelf = self;
  _autoLinkDetector.onLinkDetected = ^(NSString *text, NSString *url, NSRange range) {
    [weakSelf emitOnLinkDetectedWithText:text url:url range:range];
  };

  _detectorPipeline = [[ENRMDetectorPipeline alloc] init];
  [_detectorPipeline addDetector:_autoLinkDetector];
}

- (void)setupTextView
{
#if !TARGET_OS_OSX
  _layoutManager = [[ENRMInputLayoutManager alloc] init];
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(0, CGFLOAT_MAX)];
  textContainer.widthTracksTextView = YES;
  [_layoutManager addTextContainer:textContainer];

  NSTextStorage *textStorage = [[NSTextStorage alloc] init];
  [textStorage addLayoutManager:_layoutManager];

  ENRMInputTextView *inputTextView = [[ENRMInputTextView alloc] initWithFrame:CGRectZero textContainer:textContainer];
#else
  ENRMInputTextView *inputTextView = [[ENRMInputTextView alloc] initWithFrame:CGRectZero];
#endif
  inputTextView.markdownTextInput = self;
  _textView = inputTextView;
  ENRMConfigureMarkdownTextInputTextView(_textView);
#if !TARGET_OS_OSX
  _textView.adjustsFontForContentSizeCategory = YES;
  _textView.delegate = self;
#else
  _textView.textInputDelegate = self;
#endif

#if !TARGET_OS_OSX
  self.contentView = _textView;
#else
  _textView.selectable = YES;

  _scrollView = [[NSScrollView alloc] initWithFrame:CGRectZero];
  _scrollView.backgroundColor = [RCTUIColor clearColor];
  _scrollView.drawsBackground = NO;
  _scrollView.borderType = NSNoBorder;
  _scrollView.hasHorizontalRuler = NO;
  _scrollView.hasVerticalRuler = NO;
  _scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  _textView.verticallyResizable = YES;
  _textView.horizontallyResizable = YES;
  _textView.textContainer.containerSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
  _textView.textContainer.widthTracksTextView = YES;

  _scrollView.documentView = _textView;
  self.contentView = _scrollView;
#endif

  _placeholderLabel = ENRMCreatePlaceholderLabel(_textView, _formatterStyle.baseFont);
#if !TARGET_OS_OSX
  _placeholderLabel.adjustsFontForContentSizeCategory = YES;
  _placeholderLabel.accessibilityElementsHidden = YES;
  _placeholderLabel.isAccessibilityElement = NO;
#endif

  [self resetBaseTypingAttributes];
}

#if !TARGET_OS_OSX
#pragma mark - Accessibility

// The custom TextKit 1 stack leaves the inner UITextView invisible to VoiceOver, so
// the host vends the content itself as one readable element.
- (BOOL)isAccessibilityElement
{
  return YES;
}

- (NSString *)accessibilityValue
{
  NSString *text = ENRMGetPlainText(_textView);
  if (text.length > 0) {
    return text;
  }
  if (_placeholderLabel.text.length > 0) {
    return _placeholderLabel.text;
  }
  return [super accessibilityValue];
}

- (BOOL)accessibilityActivate
{
  ENRMFocusTextView(_textView);
  [super accessibilityActivate];
  return YES;
}
#endif

#pragma mark - State

- (void)updateState:(const facebook::react::State::Shared &)state
           oldState:(const facebook::react::State::Shared &)oldState
{
  _state = std::static_pointer_cast<const EnrichedMarkdownTextInputShadowNode::ConcreteState>(state);

  if (oldState == nullptr) {
    [self requestHeightUpdate];
  }
}

- (void)requestHeightUpdate
{
  ENRMRequestHeightUpdate<EnrichedMarkdownTextInputState>(_state, _heightUpdateCounter, self);
}

/// Yoga-resolved direction inherited from any ancestor `direction` style.
/// In FirstStrong mode this feeds the neutral-paragraph fallback, so a change
/// requires re-resolving per-paragraph directions over the current text.
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
    if (_writingDirectionMode == ENRMWritingDirectionModeFirstStrong && _textView.textStorage.length > 0) {
      [self applyFormatting];
    }
  }
}

#pragma mark - Measurement

- (CGSize)measureSize:(CGFloat)maxWidth
{
  NSMutableAttributedString *measuredText =
      [[NSMutableAttributedString alloc] initWithAttributedString:ENRMGetAttributedText(_textView)];

  // Empty input should still be the height of a single line.
  // Use typingAttributes so the measurement matches the actual configured font.
  if (measuredText.length == 0) {
    [measuredText appendAttributedString:[[NSAttributedString alloc] initWithString:@"I"
                                                                         attributes:_textView.typingAttributes]];
  }

  // Trailing newlines are not counted by boundingRectWithSize — append
  // a mock character so the extra line is included in the height.
  if (measuredText.length > 0) {
    unichar lastChar = [measuredText.string characterAtIndex:measuredText.length - 1];
    if ([[NSCharacterSet newlineCharacterSet] characterIsMember:lastChar]) {
      [measuredText appendAttributedString:[[NSAttributedString alloc] initWithString:@"I"
                                                                           attributes:_textView.typingAttributes]];
    }
  }

  CGRect boundingBox =
      [measuredText boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                 options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                 context:nil];

  return CGSizeMake(maxWidth, ceil(boundingBox.size.height));
}

#pragma mark - Props

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<EnrichedMarkdownTextInputProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<EnrichedMarkdownTextInputProps const>(props);

  if (newViewProps.editable != oldViewProps.editable) {
    _textView.editable = newViewProps.editable;
  }

#if !TARGET_OS_OSX
  if (newViewProps.scrollEnabled != oldViewProps.scrollEnabled) {
    _textView.scrollEnabled = newViewProps.scrollEnabled;
  }

  if (newViewProps.autoCapitalize != oldViewProps.autoCapitalize) {
    NSString *value = [NSString stringWithUTF8String:newViewProps.autoCapitalize.c_str()];
    _textView.autocapitalizationType = ENRMAutocapitalizationTypeFromString(value);
    if ([_textView isFirstResponder]) {
      [_textView resignFirstResponder];
      [_textView becomeFirstResponder];
    }
  }

  if (newViewProps.multiline != oldViewProps.multiline) {
    _textView.textContainer.maximumNumberOfLines = newViewProps.multiline ? 0 : 1;
    _textView.textContainer.lineBreakMode =
        newViewProps.multiline ? NSLineBreakByWordWrapping : NSLineBreakByTruncatingTail;
  }
#endif

  if (newViewProps.placeholder != oldViewProps.placeholder) {
    ENRMSetPlaceholderText(_placeholderLabel, [NSString stringWithUTF8String:newViewProps.placeholder.c_str()]);
  }

  if (newViewProps.placeholderTextColor != oldViewProps.placeholderTextColor) {
    if (isColorMeaningful(newViewProps.placeholderTextColor)) {
      _placeholderLabel.textColor = RCTUIColorFromSharedColor(newViewProps.placeholderTextColor);
    }
  }

  if (newViewProps.cursorColor != oldViewProps.cursorColor) {
    if (isColorMeaningful(newViewProps.cursorColor)) {
      ENRMSetCursorColor(_textView, RCTUIColorFromSharedColor(newViewProps.cursorColor));
    }
  }

  if (newViewProps.selectionColor != oldViewProps.selectionColor) {
    ENRMApplySelectionColor(_textView, newViewProps.selectionColor);
  }

  _emitMarkdown = newViewProps.isOnChangeMarkdownSet;

  {
    auto configFromProp = [](const auto &prop) {
      return [[ENRMLinkRegexConfig alloc] initWithPattern:[NSString stringWithUTF8String:prop.pattern.c_str()]
                                          caseInsensitive:prop.caseInsensitive
                                                   dotAll:prop.dotAll
                                               isDisabled:prop.isDisabled
                                                isDefault:prop.isDefault];
    };
    ENRMLinkRegexConfig *oldRegexConfig = configFromProp(oldViewProps.linkRegex);
    ENRMLinkRegexConfig *newRegexConfig = configFromProp(newViewProps.linkRegex);
    if (![newRegexConfig isEqualToConfig:oldRegexConfig]) {
      [_autoLinkDetector setRegexConfig:newRegexConfig];
    }
  }

  if (ENRMContextMenuItemsChanged(oldViewProps.contextMenuItems, newViewProps.contextMenuItems)) {
    _contextMenuItemTexts = ENRMContextMenuTextsFromItems(newViewProps.contextMenuItems);
    _contextMenuItemIcons = ENRMContextMenuIconsFromItems(newViewProps.contextMenuItems);
  }

  // Coalesce against `initWithUTF8String:` returning nil on malformed UTF-8 —
  // UIMenu / UIAction / NSMenuItem titles are _Nonnull and would crash.
  _inputSelectionMenuFormatLabel =
      [[NSString alloc] initWithUTF8String:newViewProps.selectionMenuConfig.formatLabel.c_str()] ?: @"";
  _inputSelectionMenuCopyAsMarkdownLabel =
      [[NSString alloc] initWithUTF8String:newViewProps.selectionMenuConfig.copyAsMarkdownLabel.c_str()] ?: @"";
  _inputSelectionMenuConfig = (ENRMInputSelectionMenuConfig){
      .format = newViewProps.selectionMenuConfig.format,
      .formatLabel = _inputSelectionMenuFormatLabel,
      .copyAsMarkdown = newViewProps.selectionMenuConfig.copyAsMarkdown,
      .copyAsMarkdownLabel = _inputSelectionMenuCopyAsMarkdownLabel,
  };

  _formatMenuBoldLabel = [[NSString alloc] initWithUTF8String:newViewProps.formatMenuConfig.boldLabel.c_str()] ?: @"";
  _formatMenuItalicLabel =
      [[NSString alloc] initWithUTF8String:newViewProps.formatMenuConfig.italicLabel.c_str()] ?: @"";
  _formatMenuUnderlineLabel =
      [[NSString alloc] initWithUTF8String:newViewProps.formatMenuConfig.underlineLabel.c_str()] ?: @"";
  _formatMenuStrikethroughLabel =
      [[NSString alloc] initWithUTF8String:newViewProps.formatMenuConfig.strikethroughLabel.c_str()] ?: @"";
  _formatMenuSpoilerLabel =
      [[NSString alloc] initWithUTF8String:newViewProps.formatMenuConfig.spoilerLabel.c_str()] ?: @"";
  _formatMenuLinkLabel = [[NSString alloc] initWithUTF8String:newViewProps.formatMenuConfig.linkLabel.c_str()] ?: @"";
  _formatMenuConfig = (ENRMFormatMenuConfig){
      .bold = newViewProps.formatMenuConfig.bold,
      .boldLabel = _formatMenuBoldLabel,
      .italic = newViewProps.formatMenuConfig.italic,
      .italicLabel = _formatMenuItalicLabel,
      .underline = newViewProps.formatMenuConfig.underline,
      .underlineLabel = _formatMenuUnderlineLabel,
      .strikethrough = newViewProps.formatMenuConfig.strikethrough,
      .strikethroughLabel = _formatMenuStrikethroughLabel,
      .spoiler = newViewProps.formatMenuConfig.spoiler,
      .spoilerLabel = _formatMenuSpoilerLabel,
      .link = newViewProps.formatMenuConfig.link,
      .linkLabel = _formatMenuLinkLabel,
  };

  if (newViewProps.mentionIndicators != oldViewProps.mentionIndicators) {
    NSMutableArray<NSString *> *indicators = [NSMutableArray array];
    for (const auto &indicator : newViewProps.mentionIndicators) {
      NSString *value = [NSString stringWithUTF8String:indicator.c_str()];
      if (value.length > 0) {
        [indicators addObject:value];
      }
    }
    _mentionIndicators = [indicators copy];
    if (_activeMentionIndicator != nil && ![_mentionIndicators containsObject:_activeMentionIndicator]) {
      [self clearActiveMention:_activeMentionIndicator];
    }
    [self updateActiveMention];
  }

  BOOL styleChanged = applyInputStyleProps(_formatterStyle, newViewProps, oldViewProps);

  BOOL writingDirectionChanged = NO;
  if (newViewProps.writingDirection != oldViewProps.writingDirection) {
    NSString *value = [[NSString alloc] initWithUTF8String:newViewProps.writingDirection.c_str()];
    _writingDirectionMode = ENRMResolveWritingDirectionMode(value);
    writingDirectionChanged = YES;
  }

  if (newViewProps.defaultValue != oldViewProps.defaultValue) {
    if (!newViewProps.defaultValue.empty() && oldViewProps.defaultValue.empty()) {
      NSString *markdown = [NSString stringWithUTF8String:newViewProps.defaultValue.c_str()];
      [self importMarkdown:markdown];
    }
  }

  if (styleChanged) {
    _placeholderLabel.font = _formatterStyle.baseFont;

    [self resetBaseTypingAttributes];

    if (_formattingStore.allRanges.count > 0) {
      [self applyFormatting];
    }

    [self requestHeightUpdate];
  } else if (writingDirectionChanged && _textView.textStorage.length > 0) {
    [self applyFormatting];
  }

  [super updateProps:props oldProps:oldProps];
}

#pragma mark - Relayout

- (void)scheduleRelayoutIfNeeded
{
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_performRelayout) object:nil];
  [self performSelector:@selector(_performRelayout) withObject:nil afterDelay:0];
}

- (void)_performRelayout
{
  if (!_textView) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    NSUInteger textLength = self->_textView.textStorage.length;
    if (textLength == 0) {
      return;
    }
    NSRange wholeRange = NSMakeRange(0, textLength);
    NSRange actualRange = NSMakeRange(0, 0);
    [self->_textView.layoutManager invalidateLayoutForCharacterRange:wholeRange actualCharacterRange:&actualRange];
    [self->_textView.layoutManager ensureLayoutForCharacterRange:actualRange];
    [self->_textView.layoutManager invalidateDisplayForCharacterRange:wholeRange];

    CGSize measuredSize = [self measureSize:self->_textView.frame.size.width];
    ENRMSetContentSize(self->_textView, measuredSize);
  });
}

#pragma mark - Window attachment

- (void)didMoveToWindow
{
  [super didMoveToWindow];

  if (self.window) {
    // Don't override the contentView frame set by RCTViewComponentView.
    ENRMRefreshTextViewLayout(_textView);

    [self applyFormatting];
    [self updatePlaceholderVisibility];
    [self requestHeightUpdate];

    const auto &viewProps = *std::static_pointer_cast<EnrichedMarkdownTextInputProps const>(_props);
    if (viewProps.autoFocus) {
      ENRMFocusTextView(_textView);
    }
  }
}

#if TARGET_OS_OSX

#pragma mark - macOS responder chain

- (BOOL)acceptsFirstResponder
{
  return _textView.acceptsFirstResponder;
}

- (BOOL)becomeFirstResponder
{
  return [self.window makeFirstResponder:_textView];
}

- (BOOL)needsPanelToBecomeKey
{
  return YES;
}

- (BOOL)mouseDownCanMoveWindow
{
  return NO;
}

- (void)mouseDown:(NSEvent *)event
{
  [self.window makeFirstResponder:_textView];
  [_textView mouseDown:event];
}

#endif

#if !TARGET_OS_OSX
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];

  if (previousTraitCollection.preferredContentSizeCategory != self.traitCollection.preferredContentSizeCategory) {
    [_formatterStyle invalidateFontCache];

    [self resetBaseTypingAttributes];

    _placeholderLabel.font = _formatterStyle.baseFont;

    [self applyFormatting];
    [self requestHeightUpdate];
  }
}
#endif

#pragma mark - ENRMEditPipelineHost

- (NSString *)plainText
{
  return ENRMGetPlainText(_textView);
}

- (NSTextStorage *)textStorage
{
  return _textView.textStorage;
}

#pragma mark - Placeholder

- (void)updatePlaceholderVisibility
{
  // Hide the placeholder once there's any content OR any block has been started
  // (e.g. an empty bullet/heading line with only a zero-length anchor): the block
  // marker or indent would otherwise overlap the placeholder text.
  BOOL hasText = ENRMGetPlainText(_textView).length > 0;
  BOOL hasBlock = _blockStore.allRanges.count > 0;
  _placeholderLabel.hidden = hasText || hasBlock;
}

#pragma mark - Markdown import

- (void)importMarkdown:(NSString *)markdown
{
  ENRMInputParser *parser = [[ENRMInputParser alloc] init];
  ENRMParseResult *parsed = [parser parseToPlainTextAndRanges:markdown];

  [_editSession enterPhase:ENRMEditPhaseImporting];

  [_editSession enterPhase:ENRMEditPhaseFormatting];
  ENRMSetPlainText(_textView, parsed.plainText);
  [_editSession enterPhase:ENRMEditPhaseImporting];

  [_formattingStore setRanges:parsed.formattingRanges];
  [_blockStore setRanges:parsed.blockRanges];
  _lastTextLength = parsed.plainText.length;
  _lastSelectedRange = _textView.selectedRange;
  [self applyFormatting];
  [self updatePlaceholderVisibility];

  [_editSession exitPhase];
}

- (void)replaceTextInRange:(NSRange)selection
                  withText:(NSString *)text
          formattingRanges:(NSArray<ENRMFormattingRange *> *)ranges
               blockRanges:(NSArray<ENRMBlockRange *> *)blockRanges
{
  NSUInteger editLocation = selection.location;

  [_editSession enterPhase:ENRMEditPhaseFormatting];
  ENRMReplaceTextInRange(_textView, text, selection);
  [_editSession exitPhase];

  NSString *plainText = [self adjustStoresForEditAtLocation:editLocation
                                              deletedLength:selection.length
                                             insertedLength:text.length];

  for (ENRMFormattingRange *range in ranges) {
    NSRange shifted = NSMakeRange(range.range.location + editLocation, range.range.length);
    [_formattingStore addRange:[ENRMFormattingRange rangeWithType:range.type range:shifted url:range.url]];
  }

  for (ENRMBlockRange *block in blockRanges) {
    NSRange shifted = NSMakeRange(block.range.location + editLocation, block.range.length);
    [_blockStore setBlockType:block.type level:block.level forParagraphRange:shifted inText:plainText];
  }

  _lastTextLength = plainText.length;
  _lastSelectedRange = _textView.selectedRange;

  [self applyFormatting];

  [_detectorPipeline processTextChange:plainText modificationRange:NSMakeRange(editLocation, text.length)];

  [self updatePlaceholderVisibility];
  [self emitOnChangeText];
  [self emitOnChangeSelection];
  [self emitFormattingChanged];
  [self requestHeightUpdate];
  [self scheduleRelayoutIfNeeded];
}

- (void)replaceTextInRange:(NSRange)selection
                  withText:(NSString *)text
          formattingRanges:(NSArray<ENRMFormattingRange *> *)ranges
{
  [self replaceTextInRange:selection withText:text formattingRanges:ranges blockRanges:@[]];
}

- (void)replaceSelectedTextWith:(NSString *)text formattingRanges:(NSArray<ENRMFormattingRange *> *)ranges
{
  [self replaceTextInRange:_textView.selectedRange withText:text formattingRanges:ranges];
}

- (void)pasteMarkdown:(NSString *)markdown
{
  ENRMInputParser *parser = [[ENRMInputParser alloc] init];
  ENRMParseResult *parsed = [parser parseToPlainTextAndRanges:markdown];
  [self replaceTextInRange:_textView.selectedRange
                  withText:parsed.plainText
          formattingRanges:parsed.formattingRanges
               blockRanges:parsed.blockRanges];
}

#pragma mark - Formatting

- (void)resetBaseTypingAttributes
{
  ENRMSetDefaultTypingAttributes(_textView, @{
    NSFontAttributeName : _formatterStyle.baseFont,
    NSForegroundColorAttributeName : _formatterStyle.baseTextColor,
  });
}

- (void)applyFormatting
{
  [self applyFormattingScopedToRange:NSMakeRange(0, ENRMGetPlainText(_textView).length)];
}

/// Per-keystroke variant: re-applies inline and block attributes only on the
/// line(s) touched by the edit, mirroring Android's applyFormattingScopedToEdit.
- (void)applyFormattingScopedToEditAtLocation:(NSUInteger)editLocation insertedLength:(NSUInteger)insertedLength
{
  NSString *plainText = ENRMGetPlainText(_textView);
  NSUInteger textLength = plainText.length;
  if (textLength == 0) {
    [self applyFormatting];
    return;
  }

  NSUInteger rawStart = MIN(editLocation, textLength);
  NSUInteger rawEnd = MIN(editLocation + insertedLength, textLength);
  rawEnd = MAX(rawEnd, rawStart);
  NSRange scope = [plainText lineRangeForRange:NSMakeRange(rawStart, rawEnd - rawStart)];
  [self applyFormattingScopedToRange:scope];
}

- (void)applyFormattingScopedToRange:(NSRange)scope
{
  if (_editSession.shouldSuppressFormatting) {
    return;
  }
  if (_editSession.isComposing) {
    return;
  }
  [_editSession enterPhase:ENRMEditPhaseFormatting];

  NSRange savedSelection = _textView.selectedRange;

  [_formatter applyFormattingRanges:_formattingStore.allRanges
                         toTextView:_textView
                              style:_formatterStyle
                      scopedToRange:scope];
  [_formatter applyBlockRanges:_blockStore.allRanges toTextView:_textView style:_formatterStyle scopedToRange:scope];
  [_detectorPipeline refreshAllStyling];
  [self applyWritingDirection];

  NSUInteger textLen = ENRMGetPlainText(_textView).length;
  if (savedSelection.location + savedSelection.length <= textLen) {
    _textView.selectedRange = savedSelection;
  }

  [_editSession exitPhase];
}

- (void)applyWritingDirection
{
  NSTextStorage *textStorage = _textView.textStorage;
  if (textStorage.length == 0) {
    return;
  }
  [textStorage beginEditing];
  ENRMApplyWritingDirectionMode(textStorage, _writingDirectionMode, _resolvedLayoutDirection);
  [textStorage endEditing];
}

#pragma mark - Commands

- (void)focus
{
  ENRMFocusTextView(_textView);
}

- (void)blur
{
  ENRMBlurTextView(_textView);
}

- (void)setValue:(NSString *)markdown
{
  [self importMarkdown:markdown];
  _lastSelectedRange = _textView.selectedRange;
  [self emitOnChangeText];
  [self emitOnChangeSelection];
  [self emitOnChangeState];
  [self requestHeightUpdate];
}

- (void)setSelection:(NSInteger)start end:(NSInteger)end
{
  NSInteger textLen = (NSInteger)ENRMGetPlainText(_textView).length;
  NSInteger clampedStart = MIN(MAX(start, 0), textLen);
  NSInteger clampedEnd = MIN(MAX(end, clampedStart), textLen);
  _textView.selectedRange = NSMakeRange((NSUInteger)clampedStart, (NSUInteger)(clampedEnd - clampedStart));
  [self emitOnChangeSelection];
  [self emitOnChangeState];
}

- (void)toggleBold
{
  [self toggleInlineStyle:ENRMInputStyleTypeStrong];
}

- (void)toggleItalic
{
  [self toggleInlineStyle:ENRMInputStyleTypeEmphasis];
}

- (void)toggleUnderline
{
  [self toggleInlineStyle:ENRMInputStyleTypeUnderline];
}

- (void)toggleStrikethrough
{
  [self toggleInlineStyle:ENRMInputStyleTypeStrikethrough];
}

- (void)toggleSpoiler
{
  [self toggleInlineStyle:ENRMInputStyleTypeSpoiler];
}

- (void)toggleInlineStyle:(ENRMInputStyleType)styleType
{
  id<ENRMStyleHandler> handler = [_formatter handlerForStyleType:styleType];
  if (!handler) {
    return;
  }
  ENRMStyleMergingConfig *mergingConfig = handler.mergingConfig;

  NSRange selection = _textView.selectedRange;
  NSUInteger cursor = selection.location;
  NSNumber *key = @(styleType);

  // Check blocking rules: if any blocking style is active, refuse to toggle on.
  if (mergingConfig.blockingStyles.count > 0) {
    BOOL isCurrentlyActive = [_formattingStore isStyleActive:styleType atPosition:cursor];
    if (!isCurrentlyActive) {
      for (NSNumber *blockerNum in mergingConfig.blockingStyles) {
        if ([_formattingStore isStyleActive:(ENRMInputStyleType)blockerNum.integerValue atPosition:cursor]) {
          return;
        }
      }
    }
  }

  if (selection.length > 0) {
    BOOL fullyStyled = YES;
    NSUInteger pos = selection.location;
    NSUInteger selEnd = NSMaxRange(selection);
    while (pos < selEnd) {
      ENRMFormattingRange *match = [_formattingStore rangeOfType:styleType containingPosition:pos];
      if (match == nil) {
        fullyStyled = NO;
        break;
      }
      pos = NSMaxRange(match.range);
    }
    if (fullyStyled) {
      [_formattingStore removeType:styleType inRange:selection];
    } else {
      // Remove conflicting styles from the range before applying.
      for (NSNumber *conflictNum in mergingConfig.conflictingStyles) {
        [_formattingStore removeType:(ENRMInputStyleType)conflictNum.integerValue inRange:selection];
      }
      ENRMFormattingRange *newRange = [ENRMFormattingRange rangeWithType:styleType range:selection];
      [_formattingStore addRange:newRange];
    }
    [_pendingStyles removeObject:key];
    [_pendingStyleRemovals removeObject:key];
  } else {
    BOOL isInsideRange = [_formattingStore isStyleActive:styleType atPosition:cursor];

    if ([_pendingStyleRemovals containsObject:key]) {
      [_pendingStyleRemovals removeObject:key];
    } else if ([_pendingStyles containsObject:key]) {
      [_pendingStyles removeObject:key];
    } else if (isInsideRange) {
      [_pendingStyleRemovals addObject:key];
    } else {
      [_pendingStyles addObject:key];
    }
  }

  [self applyFormatting];
  [self syncTypingAttributesWithPendingStyles];
  [self emitFormattingChanged];
}

- (void)toggleHeading:(NSInteger)level
{
  if (level < 1 || level > 6) {
    return;
  }
  [self toggleBlockType:ENRMBlockTypeForHeadingLevel(level) level:level];
}

/// Block counterpart to toggleInlineStyle:: sets the block on the paragraph(s)
/// the selection touches, or clears it back to a plain paragraph when already
/// active. Syncs typing attributes so the toggled line renders immediately.
- (void)toggleBlockType:(ENRMInputBlockType)type level:(NSInteger)level
{
  NSString *text = ENRMGetPlainText(_textView);
  NSRange paragraphRange = [text paragraphRangeForRange:_textView.selectedRange];

  // Match by line start, not containment: an empty block line carries a
  // zero-length anchor that a containment check would miss.
  ENRMBlockRange *current = [_blockStore blockStartingAtLocation:paragraphRange.location];
  BOOL alreadyActive = current != nil && current.type == type;

  if (alreadyActive) {
    [_blockStore removeBlockInParagraphRange:paragraphRange inText:text];
    // Strip the stored block paragraph style directly: an empty item's line has no
    // stamped block-marker attribute (zero-length ranges are never stamped), so the
    // applyFormatting reset below — which is keyed off that marker — cannot reach it.
    // The manual strip de-indents the line to a plain paragraph regardless.
    NSTextStorage *storage = _textView.textStorage;
    NSRange clamped = NSIntersectionRange(paragraphRange, NSMakeRange(0, storage.length));
    if (clamped.length > 0) {
      [storage beginEditing];
      [storage removeAttribute:NSParagraphStyleAttributeName range:clamped];
      [storage endEditing];
    }
  } else if (paragraphRange.length == 0) {
    // Switching unordered <-> ordered keeps the item's nesting depth.
    NSInteger resolvedLevel = level;
    if (ENRMBlockTypeIsListItem(type) && current != nil && ENRMBlockTypeIsListItem(current.type)) {
      resolvedLevel = current.level;
    }
    [_blockStore setBlockType:type level:resolvedLevel forParagraphRange:paragraphRange inText:text];
  } else {
    // Blocks are single-paragraph: set one range per paragraph the selection
    // touches, not one range spanning them all — otherwise the next edit's
    // line normalization would clip the block to its first line.
    [text
        enumerateSubstringsInRange:paragraphRange
                           options:NSStringEnumerationByParagraphs | NSStringEnumerationSubstringNotRequired
                        usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                          // Switching unordered <-> ordered keeps each line's nesting depth.
                          NSInteger paragraphLevel = level;
                          if (ENRMBlockTypeIsListItem(type)) {
                            ENRMBlockRange *existing = [self listBlockForParagraphAtPosition:substringRange.location];
                            if (existing != nil) {
                              paragraphLevel = existing.level;
                            }
                          }
                          [self->_blockStore setBlockType:type
                                                    level:paragraphLevel
                                        forParagraphRange:substringRange
                                                   inText:text];
                        }];
  }

  [_blockStore normalizeToLineBoundsInText:text];
  [self applyFormatting];
  [self syncTypingAttributesWithCursorBlock];
  [self updatePlaceholderVisibility];
  if (alreadyActive) {
    // The just-cleared line is a plain paragraph now; drop any list indent the
    // typing attributes carried so the next typed character isn't indented.
    [self clearListParagraphStyleFromTypingAttributes];
  }
  [self updateEmptyBulletMarker];
  [self emitFormattingChanged];
}

- (void)toggleUnorderedList
{
  [self toggleBlockType:ENRMInputBlockTypeUnorderedListItem level:0];
}

- (void)toggleOrderedList
{
  [self toggleBlockType:ENRMInputBlockTypeOrderedListItem level:0];
}

- (void)indentList
{
  [self changeListDepthBy:1];
}

- (void)outdentList
{
  [self changeListDepthBy:-1];
}

/// Adjusts the nesting depth of the cursor's list item by `delta`, clamped to
/// [0, kENRMMaxListDepth] and preserving the item's list type. QoL on the
/// boundaries: indent on a non-list paragraph starts a depth-0 bullet (ignored
/// on headings), and outdent past depth 0 removes the marker.
- (void)changeListDepthBy:(NSInteger)delta
{
  ENRMBlockRange *listBlock = [self listBlockForCursorParagraph];
  if (listBlock == nil) {
    if (delta > 0 && [self headingLevelForCursorParagraph] == 0) {
      [self toggleUnorderedList];
    }
    return;
  }

  if (delta < 0 && listBlock.level == 0) {
    [self toggleBlockType:listBlock.type level:0];
    return;
  }

  NSString *text = ENRMGetPlainText(_textView);
  NSRange paragraphRange = [text paragraphRangeForRange:_textView.selectedRange];

  // Adjust every selected paragraph that is a list item, each clamped from its
  // own depth (mirrors Android's forEachSelectedLine and toggleBlockType's
  // paragraph enumeration — one range per line, so normalize can't clip the
  // block to the selection's first line).
  if (paragraphRange.length == 0) {
    NSInteger newDepth = MIN(MAX(listBlock.level + delta, (NSInteger)0), kENRMMaxListDepth);
    [_blockStore setBlockType:listBlock.type level:newDepth forParagraphRange:paragraphRange inText:text];
  } else {
    [text
        enumerateSubstringsInRange:paragraphRange
                           options:NSStringEnumerationByParagraphs | NSStringEnumerationSubstringNotRequired
                        usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                          ENRMBlockRange *block = [self listBlockForParagraphAtPosition:substringRange.location];
                          if (block == nil) {
                            return;
                          }
                          NSInteger newDepth = MIN(MAX(block.level + delta, (NSInteger)0), kENRMMaxListDepth);
                          [self->_blockStore setBlockType:block.type
                                                    level:newDepth
                                        forParagraphRange:substringRange
                                                   inText:text];
                        }];
  }

  [_blockStore normalizeToLineBoundsInText:text];
  [self applyFormatting];
  [self syncTypingAttributesWithCursorBlock];
  [self updateEmptyBulletMarker];
  [self emitFormattingChanged];
}

/// The list block owning the caret's paragraph (matched by line start, so empty
/// anchors and line-end carets register), or nil.
- (nullable ENRMBlockRange *)listBlockForCursorParagraph
{
  return [self listBlockForParagraphAtPosition:_textView.selectedRange.location];
}

- (nullable ENRMBlockRange *)listBlockForParagraphAtPosition:(NSUInteger)position
{
  ENRMBlockRange *block = [self blockForParagraphAtPosition:position];
  return (block != nil && ENRMBlockTypeIsListItem(block.type)) ? block : nil;
}

/// The block (of any type) whose line starts at the paragraph containing
/// `position`, or nil. Single choke point over the store's O(log n) lookup —
/// callers that want only a list item or only a heading filter the result.
- (nullable ENRMBlockRange *)blockForParagraphAtPosition:(NSUInteger)position
{
  NSString *text = _textView.textStorage.string;
  if (position > text.length) {
    return nil;
  }
  NSRange paragraph = [text paragraphRangeForRange:NSMakeRange(position, 0)];
  return [_blockStore blockStartingAtLocation:paragraph.location];
}

/// Whether the caret's paragraph is a list item of `type`, writing its depth
/// into `outDepth` when non-NULL. Mirrors headingLevelForCursorParagraph.
- (BOOL)listStateOfType:(ENRMInputBlockType)type forCursorParagraphDepth:(nullable NSInteger *)outDepth
{
  ENRMBlockRange *block = [self listBlockForCursorParagraph];
  BOOL match = block != nil && block.type == type;
  if (outDepth) {
    *outDepth = match ? block.level : 0;
  }
  return match;
}

/// Records the block kind/level of the line being edited before the change, so a
/// Return that continues a list can recover the previous item's depth and an
/// in-line replacement (autocorrect/paste) that wipes the line can heal it.
- (void)capturePreEditBlockForRange:(NSRange)range
{
  ENRMBlockRange *block = [self blockForParagraphAtPosition:range.location];
  _preEditBlockType = block != nil ? block.type : ENRMInputBlockTypeParagraph;
  _preEditBlockLevel = block != nil ? block.level : 0;
}

/// Whether `range` of the current (pre-edit) text contains a line break. Scans
/// only the replaced run, mirroring Android's editTouchedNewline.
- (BOOL)replacedRangeTouchesNewline:(NSRange)range
{
  NSString *text = _textView.textStorage.string;
  if (range.length == 0 || range.location >= text.length) {
    return NO;
  }
  NSRange clamped = NSMakeRange(range.location, MIN(range.length, text.length - range.location));
  return [text rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:0 range:clamped].location !=
         NSNotFound;
}

/// Whether the caret's paragraph had no glyph content at the start of the edit
/// (an empty line). Used to decide whether Return continues or exits the list.
- (BOOL)preEditParagraphWasEmpty:(NSRange)range
{
  NSString *text = _textView.textStorage.string;
  if (text.length == 0) {
    return YES;
  }
  NSRange paragraph = [text paragraphRangeForRange:range];
  if (paragraph.length == 0) {
    return YES;
  }
  return [[text substringWithRange:paragraph] isEqualToString:@"\n"];
}

/// Intercepts Tab (indent) and Backspace at a bullet item's start (outdent, then
/// un-list at depth 0). Returns YES when handled, suppressing the default edit.
/// Keyed off the caret's own paragraph (NSMaxRange(range)), not range.location —
/// a backspace at a line start targets the previous line's newline, and using the
/// caret's line lets the next Backspace after un-listing fall through to a merge.
- (BOOL)handleListKeyForReplacementRange:(NSRange)range replacementText:(NSString *)text
{
  NSUInteger caret = NSMaxRange(range);
  NSInteger depth;
  if (![self listStateForParagraphAtPosition:caret depth:&depth]) {
    return NO;
  }

  // Tab indents the current item.
  if ([text isEqualToString:@"\t"]) {
    [self indentList];
    return YES;
  }

  // Backspace at the very start of the caret's own item: outdent, or remove the
  // marker entirely once at depth 0 (de-indenting the line to a plain paragraph).
  if (text.length == 0 && range.length == 1) {
    NSString *plainText = ENRMGetPlainText(_textView);
    NSRange paragraphRange = [plainText paragraphRangeForRange:NSMakeRange(caret, 0)];
    BOOL atItemStart = caret == paragraphRange.location;
    if (atItemStart) {
      if (depth > 0) {
        [self outdentList];
      } else {
        ENRMBlockRange *listBlock = [self listBlockForParagraphAtPosition:caret];
        [self toggleBlockType:listBlock != nil ? listBlock.type : ENRMInputBlockTypeUnorderedListItem level:0];
      }
      return YES;
    }
  }

  return NO;
}

/// Backspace at the document start (caret at 0) never fires the text-change
/// delegate — nothing precedes the caret — so the first line's bullet has to be
/// outdented/removed here. Returns YES when handled.
- (BOOL)handleBackspaceAtDocumentStart
{
  NSRange selection = _textView.selectedRange;
  if (selection.location != 0 || selection.length != 0) {
    return NO;
  }
  ENRMBlockRange *listBlock = [self listBlockForCursorParagraph];
  if (listBlock == nil) {
    return NO;
  }
  if (listBlock.level > 0) {
    [self outdentList];
  } else {
    [self toggleBlockType:listBlock.type level:0];
  }
  return YES;
}

/// listBlockForCursorParagraph for an arbitrary position — the caret hasn't
/// moved yet when a replacement is intercepted.
- (BOOL)listStateForParagraphAtPosition:(NSUInteger)position depth:(NSInteger *)outDepth
{
  ENRMBlockRange *block = [self listBlockForParagraphAtPosition:position];
  if (block != nil) {
    if (outDepth) {
      *outDepth = block.level;
    }
    return YES;
  }
  return NO;
}

/// Drives the layout manager's empty-line bullet: an empty bullet line has no
/// character to anchor the marker to, so the manager is told its location/depth
/// explicitly; cleared when the caret isn't on an empty bullet line.
- (void)updateEmptyBulletMarker
{
  NSString *text = ENRMGetPlainText(_textView);
  NSRange selection = _textView.selectedRange;
  BOOL show = NO;
  NSUInteger location = 0;
  NSInteger depth = 0;

  BOOL ordered = NO;
  NSInteger ordinal = 1;
  ENRMBlockRange *cursorListBlock = selection.length == 0 ? [self listBlockForCursorParagraph] : nil;
  if (cursorListBlock != nil) {
    NSInteger cursorDepth = cursorListBlock.level;
    ordered = cursorListBlock.type == ENRMInputBlockTypeOrderedListItem;
    ordinal = cursorListBlock.ordinal;
    NSRange paragraphRange = text.length == 0 ? NSMakeRange(0, 0) : [text paragraphRangeForRange:selection];
    NSString *paragraphText = text.length == 0 ? @"" : [text substringWithRange:paragraphRange];
    BOOL empty = paragraphText.length == 0 || [paragraphText isEqualToString:@"\n"];
    if (empty) {
      show = YES;
      location = paragraphRange.location;
      depth = cursorDepth;

      // A mid-document empty bullet line has no paragraph style and lays out
      // flush left; stamp the list style so caret and marker indent immediately.
      // (A trailing empty line uses the extra line fragment instead.)
      if (paragraphRange.length > 0) {
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        CGFloat indent = (depth + 1) * kENRMListIndentPerDepth;
        paragraph.firstLineHeadIndent = indent;
        paragraph.headIndent = indent;
        paragraph.paragraphSpacingBefore = _formatterStyle.listItemSpacing;
        NSTextStorage *storage = _textView.textStorage;
        [storage beginEditing];
        [storage addAttribute:NSParagraphStyleAttributeName value:paragraph range:paragraphRange];
        [storage endEditing];
      }
    }
  }

  _layoutManager.emptyBulletDepth = show ? depth : -1;
  _layoutManager.emptyBulletOrdered = ordered;
  _layoutManager.emptyBulletOrdinal = ordinal;
  _layoutManager.emptyBulletLocation = location;
  _layoutManager.emptyBulletFont = _formatterStyle.baseFont;
  _layoutManager.emptyBulletColor = _formatterStyle.baseTextColor;
  _layoutManager.emptyBulletRTL = [self emptyListLineIsRTL];
  _layoutManager.listItemSpacing = _formatterStyle.listItemSpacing;

  // An empty editor never runs the formatter (it early-returns at length 0), so
  // the trailing/extra line fragment the marker draws into isn't laid out yet —
  // force it so the bullet appears before the first keystroke.
  if (show && text.length == 0) {
    [_layoutManager ensureLayoutForTextContainer:_textView.textContainer];
  }
  ENRMSetNeedsDisplay(_textView);

  // The empty-editor bullet would otherwise overlap the placeholder.
  [self updatePlaceholderVisibility];
}

/// Writing direction the empty list line resolves to, for mirroring its marker.
/// An empty line has no strong character, so Auto and FirstStrong fall back the
/// same way the formatter's direction pass would.
- (BOOL)emptyListLineIsRTL
{
  switch (_writingDirectionMode) {
    case ENRMWritingDirectionModeLTR:
      return NO;
    case ENRMWritingDirectionModeRTL:
      return YES;
    case ENRMWritingDirectionModeFirstStrong:
      return _resolvedLayoutDirection == NSWritingDirectionRightToLeft;
    case ENRMWritingDirectionModeAuto:
    default:
      return ENRMParagraphIsRTL(nil);
  }
}

/// Heading level (1-6, or 0) of the caret's paragraph, matched by line start so
/// line-end carets and empty-line anchors register (mirrors inline isActive).
- (NSInteger)headingLevelForCursorParagraph
{
  ENRMBlockRange *block = [self blockForParagraphAtPosition:_textView.selectedRange.location];
  return block != nil ? ENRMHeadingLevelForBlockType(block.type) : 0;
}

/// Syncs typing attributes so text typed at the caret on a block-styled line
/// (e.g. a heading) adopts that block's font rather than the base font. Inline
/// pending traits (bold/italic) are unioned on top, matching the inline pass.
- (void)syncTypingAttributesWithCursorBlock
{
  UIFontDescriptorSymbolicTraits traits = 0;
  if ([_pendingStyles containsObject:@(ENRMInputStyleTypeStrong)]) {
    traits |= UIFontDescriptorTraitBold;
  }
  if ([_pendingStyles containsObject:@(ENRMInputStyleTypeEmphasis)]) {
    traits |= UIFontDescriptorTraitItalic;
  }

  NSInteger headingLevel = [self headingLevelForCursorParagraph];

  UIFont *font;
  if (headingLevel >= 1 && headingLevel <= 6) {
    UIFont *headingFont = [_formatterStyle headingFontForLevel:headingLevel];
    UIFontDescriptorSymbolicTraits merged = headingFont.fontDescriptor.symbolicTraits | traits;
    UIFontDescriptor *descriptor = [headingFont.fontDescriptor fontDescriptorWithSymbolicTraits:merged];
    font = descriptor ? [UIFont fontWithDescriptor:descriptor size:0] : headingFont;
  } else {
    font = [_formatterStyle fontForTraits:traits];
  }

  NSMutableDictionary *attrs = [_textView.typingAttributes mutableCopy];
  attrs[NSFontAttributeName] = font;
  RCTUIColor *headingColor = headingLevel >= 1 ? [_formatterStyle headingColorForLevel:headingLevel] : nil;
  attrs[NSForegroundColorAttributeName] = headingColor ?: _formatterStyle.baseTextColor;

  // On a bullet line, carry the list paragraph style in the typing attributes so
  // the caret sits at the marker indent and the bullet draws before the first
  // keystroke. Headings need no paragraph style here, so clear it.
  ENRMBlockRange *typingListBlock = [self listBlockForCursorParagraph];
  if (typingListBlock != nil) {
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    CGFloat indent = (typingListBlock.level + 1) * kENRMListIndentPerDepth;
    paragraph.firstLineHeadIndent = indent;
    paragraph.headIndent = indent;
    paragraph.paragraphSpacingBefore = _formatterStyle.listItemSpacing;
    attrs[NSParagraphStyleAttributeName] = paragraph;
  } else {
    [attrs removeObjectForKey:NSParagraphStyleAttributeName];
  }

  _textView.typingAttributes = attrs;
}

- (NSString *)adjustStoresForEditAtLocation:(NSUInteger)editLocation
                              deletedLength:(NSUInteger)deletedLength
                             insertedLength:(NSUInteger)insertedLength
{
  return [_editPipeline adjustStoresForEditAtLocation:editLocation
                                        deletedLength:deletedLength
                                       insertedLength:insertedLength];
}

/// Drops any paragraph style from the caret's typing attributes so a list indent
/// left over from a just-exited bullet doesn't indent the next typed character.
- (void)clearListParagraphStyleFromTypingAttributes
{
  if (_textView.typingAttributes[NSParagraphStyleAttributeName] == nil) {
    return;
  }
  NSMutableDictionary *attrs = [_textView.typingAttributes mutableCopy];
  [attrs removeObjectForKey:NSParagraphStyleAttributeName];
  _textView.typingAttributes = attrs;
}

- (void)setLink:(NSString *)url
{
  NSRange selection = _textView.selectedRange;
  NSUInteger cursor = selection.location;

  ENRMFormattingRange *activeLink = [_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:cursor];

  if (activeLink != nil) {
    activeLink.url = url;
    [_autoLinkDetector clearAutoLinkInRange:activeLink.range];
  } else if (selection.length > 0) {
    ENRMFormattingRange *linkRange = [ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink range:selection url:url];
    [_formattingStore addRange:linkRange];
    [_autoLinkDetector clearAutoLinkInRange:selection];
  } else {
    return;
  }

  [self applyFormatting];
  [self emitFormattingChanged];
}

- (void)insertLink:(NSString *)text url:(NSString *)url
{
  NSString *displayText = text.length > 0 ? text : url;
  NSRange linkRange = NSMakeRange(0, displayText.length);
  ENRMFormattingRange *range = [ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink
                                                            range:linkRange
                                                              url:[self sanitizeLinkURL:url]];
  [self replaceSelectedTextWith:displayText formattingRanges:@[ range ]];
}

- (NSString *)sanitizeLinkURL:(NSString *)url
{
  NSString *result = [url stringByReplacingOccurrencesOfString:@"(" withString:@"%28"];
  return [result stringByReplacingOccurrencesOfString:@")" withString:@"%29"];
}

- (void)startMention:(NSString *)indicator
{
  if (indicator.length == 0 || ![_mentionIndicators containsObject:indicator]) {
    return;
  }

  [self replaceSelectedTextWith:indicator formattingRanges:@[]];
  [self updateActiveMention];
}

- (void)insertMention:(NSString *)displayText url:(NSString *)url
{
  if (displayText.length == 0 || _activeMentionIndicator == nil || _activeMentionRange.location == NSNotFound) {
    return;
  }

  NSString *plainText = ENRMGetPlainText(_textView);
  NSUInteger rangeEnd = NSMaxRange(_activeMentionRange);
  if (rangeEnd > plainText.length) {
    return;
  }
  BOOL nextCharIsWhitespace = rangeEnd < plainText.length && [[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                                                 characterIsMember:[plainText
                                                                                       characterAtIndex:rangeEnd]];
  NSString *replacement = nextCharIsWhitespace ? displayText : [displayText stringByAppendingString:@" "];
  ENRMFormattingRange *linkRange = [ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink
                                                                range:NSMakeRange(0, displayText.length)
                                                                  url:[self sanitizeLinkURL:url]];
  NSString *indicator = _activeMentionIndicator;
  NSRange mentionRange = _activeMentionRange;

  [self clearActiveMention:indicator];
  [self replaceTextInRange:mentionRange withText:replacement formattingRanges:@[ linkRange ]];
  _textView.selectedRange = NSMakeRange(mentionRange.location + replacement.length, 0);
  [self emitOnChangeSelection];
}

- (void)removeLink
{
  NSUInteger cursor = _textView.selectedRange.location;
  ENRMFormattingRange *activeLink = [_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:cursor];
  if (activeLink == nil) {
    return;
  }

  [_formattingStore removeRange:activeLink];
  [self applyFormatting];
  [self emitFormattingChanged];
}

- (void)showLinkPrompt
{
  NSUInteger cursor = _textView.selectedRange.location;
  ENRMFormattingRange *activeLink = [_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:cursor];
  NSString *existingURL = activeLink != nil ? activeLink.url : nil;

  __weak EnrichedMarkdownTextInput *weakSelf = self;
  ENRMShowLinkPrompt(self, existingURL, ^(NSString *url) { [weakSelf setLink:url]; });
}

/// Serializes plain text with inline + block formatting, resolving each block's
/// markdown line prefix through its registered handler. With no block handlers
/// registered the prefix provider is never consulted productively and output
/// equals the inline-only serialization.
- (NSString *)serializeText:(NSString *)text
                     ranges:(NSArray<ENRMFormattingRange *> *)ranges
                blockRanges:(NSArray<ENRMBlockRange *> *)blockRanges
{
  // The provider runs synchronously inside the serializer call, so capturing
  // the formatter directly is safe — no escaping closure, no retain cycle.
  ENRMInputFormatter *formatter = _formatter;
  return [ENRMMarkdownSerializer serializePlainText:text
                                             ranges:ranges
                                        blockRanges:blockRanges
                                blockPrefixProvider:^NSString *(ENRMBlockRange *blockRange) {
                                  id<ENRMBlockHandler> handler = [formatter handlerForBlockType:blockRange.type];
                                  return [handler markdownLinePrefixForBlockRange:blockRange];
                                }];
}

- (nullable NSString *)markdownForSelectedRange
{
  NSRange selection = _textView.selectedRange;
  if (selection.length == 0) {
    return nil;
  }

  NSString *fullText = ENRMGetPlainText(_textView);
  NSString *selectedText = [fullText substringWithRange:selection];
  NSUInteger selEnd = NSMaxRange(selection);

  NSMutableArray<ENRMFormattingRange *> *clippedRanges = [NSMutableArray array];
  for (ENRMFormattingRange *range in [self allRangesIncludingTransient]) {
    NSUInteger rangeStart = range.range.location;
    NSUInteger rangeEnd = NSMaxRange(range.range);

    if (rangeEnd <= selection.location || rangeStart >= selEnd) {
      continue;
    }

    NSUInteger clippedStart = MAX(rangeStart, selection.location);
    NSUInteger clippedEnd = MIN(rangeEnd, selEnd);
    NSRange shifted = NSMakeRange(clippedStart - selection.location, clippedEnd - clippedStart);

    [clippedRanges addObject:[ENRMFormattingRange rangeWithType:range.type range:shifted url:range.url]];
  }

  NSMutableArray<ENRMBlockRange *> *clippedBlockRanges = [NSMutableArray array];
  for (ENRMBlockRange *blockRange in _blockStore.allRanges) {
    NSUInteger rangeStart = blockRange.range.location;
    NSUInteger rangeEnd = NSMaxRange(blockRange.range);

    if (rangeEnd <= selection.location || rangeStart >= selEnd) {
      continue;
    }

    NSUInteger clippedStart = MAX(rangeStart, selection.location);
    NSUInteger clippedEnd = MIN(rangeEnd, selEnd);
    NSRange shifted = NSMakeRange(clippedStart - selection.location, clippedEnd - clippedStart);

    [clippedBlockRanges addObject:[ENRMBlockRange rangeWithType:blockRange.type range:shifted level:blockRange.level]];
  }

  return [self serializeText:selectedText ranges:clippedRanges blockRanges:clippedBlockRanges];
}

- (void)copyToClipboard
{
  NSString *plainText = ENRMGetPlainText(_textView);
  if (plainText.length == 0) {
    return;
  }
  NSString *markdown = [self serializeText:plainText
                                    ranges:[self allRangesIncludingTransient]
                               blockRanges:_blockStore.allRanges];
  NSMutableDictionary *items = [NSMutableDictionary dictionary];
  items[kUTIPlainText] = plainText;
  if (markdown.length > 0) {
    items[kENRMMarkdownPasteboardType] = markdown;
  }
  copyItemsToPasteboard(items);
}

- (void)requestMarkdown:(NSInteger)requestId
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  NSString *markdown = [self serializeText:ENRMGetPlainText(_textView)
                                    ranges:[self allRangesIncludingTransient]
                               blockRanges:_blockStore.allRanges];
  emitter->onRequestMarkdownResult({
      .requestId = static_cast<int>(requestId),
      .markdown = std::string([markdown UTF8String] ?: ""),
  });
}

- (CGRect)computeCaretRect
{
  CGRect caretRect = CGRectZero;
#if !TARGET_OS_OSX
  UITextRange *selectedRange = _textView.selectedTextRange;
  if (selectedRange != nil) {
    caretRect = [_textView caretRectForPosition:selectedRange.start];
  }
#else
  NSRange selection = _textView.selectedRange;
  if (selection.location != NSNotFound) {
    NSRange glyphRange = [_textView.layoutManager glyphRangeForCharacterRange:NSMakeRange(selection.location, 0)
                                                         actualCharacterRange:NULL];
    caretRect = [_textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:_textView.textContainer];
    caretRect.origin.x += _textView.textContainerInset.left;
    caretRect.origin.y += _textView.textContainerInset.top;
  }
#endif
  return caretRect;
}

- (void)requestCaretRect:(NSInteger)requestId
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }

  CGRect caretRect = [self computeCaretRect];
  emitter->onRequestCaretRectResult({
      .requestId = static_cast<int>(requestId),
      .x = caretRect.origin.x,
      .y = caretRect.origin.y,
      .width = caretRect.size.width,
      .height = caretRect.size.height,
  });
}

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
  RCTEnrichedMarkdownTextInputHandleCommand(self, commandName, args);
}

#pragma mark - Style state query

- (BOOL)isEffectiveStyleActive:(ENRMInputStyleType)type atPosition:(NSUInteger)position
{
  BOOL inRange = [_formattingStore isStyleActive:type atPosition:position];
  NSNumber *key = @(type);
  if ([_pendingStyleRemovals containsObject:key]) {
    return NO;
  }
  if ([_pendingStyles containsObject:key]) {
    return YES;
  }
  return inRange;
}

- (void)syncTypingAttributesWithPendingStyles
{
  UIFontDescriptorSymbolicTraits traits = 0;
  if ([_pendingStyles containsObject:@(ENRMInputStyleTypeStrong)]) {
    traits |= UIFontDescriptorTraitBold;
  }
  if ([_pendingStyles containsObject:@(ENRMInputStyleTypeEmphasis)]) {
    traits |= UIFontDescriptorTraitItalic;
  }

  NSMutableDictionary *attrs = [_textView.typingAttributes mutableCopy];
  attrs[NSFontAttributeName] = [_formatterStyle fontForTraits:traits];
  _textView.typingAttributes = attrs;
}

- (void)resetPendingStylesForSelectionChange
{
  if (_editSession.isPostEditGracePeriod) {
    return;
  }
  [_pendingStyles removeAllObjects];
  [_pendingStyleRemovals removeAllObjects];
  [self rebuildPendingStylesFromContext];
  [self syncTypingAttributesWithCursorBlock];
}

- (void)rebuildPendingStylesFromContext
{
  NSUInteger cursor = _textView.selectedRange.location;
  if (_textView.selectedRange.length > 0 || cursor == 0) {
    return;
  }

  static const ENRMInputStyleType inlineStyles[] = {
      ENRMInputStyleTypeStrong,        ENRMInputStyleTypeEmphasis, ENRMInputStyleTypeUnderline,
      ENRMInputStyleTypeStrikethrough, ENRMInputStyleTypeSpoiler,
  };

  for (NSUInteger i = 0; i < sizeof(inlineStyles) / sizeof(inlineStyles[0]); i++) {
    ENRMInputStyleType type = inlineStyles[i];
    if ([_formattingStore isStyleAdjacentBefore:type position:cursor]) {
      [_pendingStyles addObject:@(type)];
    }
  }
}

#pragma mark - Event emitters

- (void)emitFormattingChanged
{
  [self emitOnChangeState];
  if (_emitMarkdown) {
    [self emitOnChangeMarkdown];
  }
}

- (std::shared_ptr<EnrichedMarkdownTextInputEventEmitter const>)getEventEmitter
{
  if (_eventEmitter == nullptr || _editSession.shouldSuppressEvents) {
    return nullptr;
  }
  return std::static_pointer_cast<EnrichedMarkdownTextInputEventEmitter const>(_eventEmitter);
}

- (NSArray<ENRMFormattingRange *> *)allRangesIncludingTransient
{
  NSArray<ENRMFormattingRange *> *transient = [_detectorPipeline allTransientFormattingRanges];
  if (transient.count == 0) {
    return _formattingStore.allRanges;
  }
  NSMutableArray<ENRMFormattingRange *> *merged = [_formattingStore.allRanges mutableCopy];
  [merged addObjectsFromArray:transient];
  return merged;
}

- (void)clearActiveMention:(nullable NSString *)indicatorOverride
{
  NSString *indicator = indicatorOverride ?: _activeMentionIndicator;
  _activeMentionIndicator = nil;
  _activeMentionRange = NSMakeRange(NSNotFound, 0);
  _activeMentionText = @"";

  if (indicator.length > 0) {
    [self emitOnEndMention:indicator];
  }
}

- (nullable ENRMInputMentionCandidate *)mentionCandidateAtCursor
{
  NSRange selectedRange = _textView.selectedRange;
  if (_mentionIndicators.count == 0 || selectedRange.length != 0) {
    return nil;
  }

  NSString *plainText = ENRMGetPlainText(_textView);
  NSUInteger cursor = selectedRange.location;
  if (cursor > plainText.length) {
    return nil;
  }

  NSUInteger start = [ENRMWordsUtils tokenStartInText:plainText beforePosition:cursor];
  NSString *token = [plainText substringWithRange:NSMakeRange(start, cursor - start)];
  NSString *matchedIndicator = nil;
  for (NSString *indicator in _mentionIndicators) {
    if ([token hasPrefix:indicator]) {
      matchedIndicator = indicator;
      break;
    }
  }
  if (matchedIndicator == nil) {
    return nil;
  }

  if ([_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:start] != nil) {
    return nil;
  }

  return [ENRMInputMentionCandidate candidateWithIndicator:matchedIndicator
                                                     start:start
                                                       end:cursor
                                                      text:[token substringFromIndex:matchedIndicator.length]];
}

- (void)updateActiveMention
{
  ENRMInputMentionCandidate *candidate = [self mentionCandidateAtCursor];
  if (candidate == nil) {
    [self clearActiveMention:nil];
    return;
  }

  NSString *indicator = candidate.indicator;
  NSUInteger start = candidate.start;
  NSUInteger end = candidate.end;
  NSString *query = candidate.text;

  if (_activeMentionIndicator == nil || ![_activeMentionIndicator isEqualToString:indicator] ||
      _activeMentionRange.location != start) {
    if (_activeMentionIndicator != nil) {
      [self emitOnEndMention:_activeMentionIndicator];
    }
    _activeMentionIndicator = indicator;
    [self emitOnStartMention:indicator];
  }
  _activeMentionRange = NSMakeRange(start, end - start);

  if (![_activeMentionText isEqualToString:query]) {
    _activeMentionText = query;
    [self emitOnChangeMentionWithIndicator:indicator text:query];
  }
}

- (BOOL)deleteLinkForReplacementRange:(NSRange)range replacementText:(NSString *)text
{
  if (text.length > 0) {
    return NO;
  }

  NSUInteger lookupPosition;
  if (range.length > 0) {
    lookupPosition = range.location;
  } else if (range.location > 0) {
    lookupPosition = range.location - 1;
  } else {
    return NO;
  }

  ENRMFormattingRange *linkRange = [_formattingStore rangeOfType:ENRMInputStyleTypeLink
                                              containingPosition:lookupPosition];
  if (linkRange == nil) {
    return NO;
  }

  [self replaceTextInRange:linkRange.range withText:@"" formattingRanges:@[]];
  [self clearActiveMention:nil];
  return YES;
}

- (void)emitOnChangeText
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  NSString *plainText = ENRMGetPlainText(_textView);
  emitter->onChangeText({.value = std::string([plainText UTF8String] ?: "")});
}

- (void)emitOnChangeMarkdown
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  NSString *markdown = [self serializeText:ENRMGetPlainText(_textView)
                                    ranges:[self allRangesIncludingTransient]
                               blockRanges:_blockStore.allRanges];
  emitter->onChangeMarkdown({.value = std::string([markdown UTF8String] ?: "")});
}

- (void)emitOnChangeSelection
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  NSRange selection = _textView.selectedRange;
  emitter->onChangeSelection({
      .start = static_cast<int>(selection.location),
      .end = static_cast<int>(NSMaxRange(selection)),
  });
}

- (void)emitOnChangeState
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }

  NSUInteger cursor = _textView.selectedRange.location;
  BOOL boldActive = [self isEffectiveStyleActive:ENRMInputStyleTypeStrong atPosition:cursor];
  BOOL italicActive = [self isEffectiveStyleActive:ENRMInputStyleTypeEmphasis atPosition:cursor];
  BOOL underlineActive = [self isEffectiveStyleActive:ENRMInputStyleTypeUnderline atPosition:cursor];
  BOOL strikethroughActive = [self isEffectiveStyleActive:ENRMInputStyleTypeStrikethrough atPosition:cursor];
  BOOL spoilerActive = [self isEffectiveStyleActive:ENRMInputStyleTypeSpoiler atPosition:cursor];
  BOOL linkActive = [self isEffectiveStyleActive:ENRMInputStyleTypeLink atPosition:cursor];

  NSInteger headingLevel = [self headingLevelForCursorParagraph];

  NSInteger listDepth = 0;
  ENRMBlockRange *emitListBlock = [self listBlockForCursorParagraph];
  BOOL unorderedListActive = emitListBlock != nil && emitListBlock.type == ENRMInputBlockTypeUnorderedListItem;
  BOOL orderedListActive = emitListBlock != nil && emitListBlock.type == ENRMInputBlockTypeOrderedListItem;
  if (emitListBlock != nil) {
    listDepth = emitListBlock.level;
  }

  if (_prevState.initialized && _prevState.bold == boldActive && _prevState.italic == italicActive &&
      _prevState.underline == underlineActive && _prevState.strikethrough == strikethroughActive &&
      _prevState.spoiler == spoilerActive && _prevState.link == linkActive && _prevState.headingLevel == headingLevel &&
      _prevState.unorderedList == unorderedListActive && _prevState.unorderedListDepth == listDepth &&
      _prevState.orderedList == orderedListActive && _prevState.orderedListDepth == listDepth) {
    return;
  }

  _prevState.bold = boldActive;
  _prevState.italic = italicActive;
  _prevState.underline = underlineActive;
  _prevState.strikethrough = strikethroughActive;
  _prevState.spoiler = spoilerActive;
  _prevState.link = linkActive;
  _prevState.headingLevel = headingLevel;
  _prevState.unorderedList = unorderedListActive;
  _prevState.unorderedListDepth = listDepth;
  _prevState.orderedList = orderedListActive;
  _prevState.orderedListDepth = listDepth;
  _prevState.initialized = YES;

  emitter->onChangeState({
      .bold = {.isActive = boldActive},
      .italic = {.isActive = italicActive},
      .underline = {.isActive = underlineActive},
      .strikethrough = {.isActive = strikethroughActive},
      .spoiler = {.isActive = spoilerActive},
      .link = {.isActive = linkActive},
      .heading = {.isActive = headingLevel > 0, .level = static_cast<int>(headingLevel)},
      .unorderedList = {.isActive = unorderedListActive,
                        .depth = static_cast<int>(unorderedListActive ? listDepth : 0)},
      .orderedList = {.isActive = orderedListActive, .depth = static_cast<int>(orderedListActive ? listDepth : 0)},
  });
}

- (void)emitCaretRectChangeIfNeeded
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }

  CGRect caretRect = [self computeCaretRect];

  if (_prevCaretRect.has_value() && CGRectEqualToRect(_prevCaretRect.value(), caretRect)) {
    return;
  }

  _prevCaretRect = caretRect;

  emitter->onCaretRectChange({
      .x = caretRect.origin.x,
      .y = caretRect.origin.y,
      .width = caretRect.size.width,
      .height = caretRect.size.height,
  });
}

- (NSArray<NSString *> *)contextMenuItemTexts
{
  return _contextMenuItemTexts ?: @[];
}

- (NSArray<NSString *> *)contextMenuItemIcons
{
  return _contextMenuItemIcons ?: @[];
}

- (ENRMInputSelectionMenuConfig)inputSelectionMenuConfig
{
  return _inputSelectionMenuConfig;
}

- (ENRMFormatMenuConfig)formatMenuConfig
{
  return _formatMenuConfig;
}

- (void)emitContextMenuItemPress:(NSString *)itemText
{
  auto eventEmitter = [self getEventEmitter];
  if (eventEmitter == nullptr) {
    return;
  }

  NSRange selectedRange = _textView.selectedRange;
  NSString *selectedText =
      selectedRange.length > 0 ? [_textView.textStorage.string substringWithRange:selectedRange] : @"";

  auto isActive = [&](ENRMInputStyleType type) -> BOOL {
    if (selectedRange.length > 0) {
      return [_formattingStore isStyleActive:type inRange:selectedRange];
    }
    return [self isEffectiveStyleActive:type atPosition:selectedRange.location];
  };

  BOOL boldActive = isActive(ENRMInputStyleTypeStrong);
  BOOL italicActive = isActive(ENRMInputStyleTypeEmphasis);
  BOOL underlineActive = isActive(ENRMInputStyleTypeUnderline);
  BOOL strikethroughActive = isActive(ENRMInputStyleTypeStrikethrough);
  BOOL spoilerActive = isActive(ENRMInputStyleTypeSpoiler);
  BOOL linkActive = isActive(ENRMInputStyleTypeLink);
  NSInteger headingLevel = [self headingLevelForCursorParagraph];
  NSInteger listDepth = 0;
  ENRMBlockRange *emitListBlock = [self listBlockForCursorParagraph];
  BOOL unorderedListActive = emitListBlock != nil && emitListBlock.type == ENRMInputBlockTypeUnorderedListItem;
  BOOL orderedListActive = emitListBlock != nil && emitListBlock.type == ENRMInputBlockTypeOrderedListItem;
  if (emitListBlock != nil) {
    listDepth = emitListBlock.level;
  }

  eventEmitter->onContextMenuItemPress({
      .itemText = std::string(itemText.UTF8String),
      .selectedText = std::string(selectedText.UTF8String),
      .selectionStart = static_cast<int>(selectedRange.location),
      .selectionEnd = static_cast<int>(NSMaxRange(selectedRange)),
      .styleState =
          {
              .bold = {.isActive = boldActive},
              .italic = {.isActive = italicActive},
              .underline = {.isActive = underlineActive},
              .strikethrough = {.isActive = strikethroughActive},
              .spoiler = {.isActive = spoilerActive},
              .link = {.isActive = linkActive},
              .heading = {.isActive = headingLevel > 0, .level = static_cast<int>(headingLevel)},
              .unorderedList = {.isActive = unorderedListActive,
                                .depth = static_cast<int>(unorderedListActive ? listDepth : 0)},
              .orderedList = {.isActive = orderedListActive,
                              .depth = static_cast<int>(orderedListActive ? listDepth : 0)},
          },
  });
}

- (void)emitOnFocus
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  emitter->onInputFocus({});
}

- (void)emitOnBlur
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  emitter->onInputBlur({});
}

- (void)emitOnLinkDetectedWithText:(NSString *)text url:(NSString *)url range:(NSRange)range
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  emitter->onLinkDetected({
      .text = std::string([text UTF8String] ?: ""),
      .url = std::string([url UTF8String] ?: ""),
      .start = static_cast<int>(range.location),
      .end = static_cast<int>(range.location + range.length),
  });
}

- (void)emitOnStartMention:(NSString *)indicator
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  emitter->onStartMention({.indicator = std::string([indicator UTF8String] ?: "")});
}

- (void)emitOnChangeMentionWithIndicator:(NSString *)indicator text:(NSString *)text
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  emitter->onChangeMention({
      .indicator = std::string([indicator UTF8String] ?: ""),
      .text = std::string([text UTF8String] ?: ""),
  });
}

- (void)emitOnEndMention:(NSString *)indicator
{
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  emitter->onEndMention({.indicator = std::string([indicator UTF8String] ?: "")});
}

#pragma mark - Text edit tracking

- (void)handleTextChanged
{
  if (_editSession.isComposing) {
    return;
  }

  NSUInteger newLength = ENRMGetPlainText(_textView).length;
  NSRange selection = _textView.selectedRange;

  NSRange preEditSelection = _preEditSelectedRange;
  NSUInteger editLocation = preEditSelection.location;
  NSUInteger deletedLength = 0;
  NSUInteger insertedLength = 0;

  if (newLength >= _lastTextLength) {
    NSUInteger netInserted = newLength - _lastTextLength;
    deletedLength = preEditSelection.length;
    insertedLength = deletedLength + netInserted;
  } else {
    NSUInteger netDeleted = _lastTextLength - newLength;
    if (preEditSelection.length > 0) {
      deletedLength = preEditSelection.length;
      insertedLength = deletedLength > netDeleted ? deletedLength - netDeleted : 0;
    } else {
      deletedLength = netDeleted;
      insertedLength = 0;
      if (selection.location < editLocation) {
        editLocation = selection.location;
      }
    }
  }

  ENRMEditContext *context = [[ENRMEditContext alloc] initWithEditLocation:editLocation
                                                             deletedLength:deletedLength
                                                            insertedLength:insertedLength
                                                    preEditReplacedNewline:_preEditReplacedNewline
                                                          preEditBlockType:_preEditBlockType
                                                         preEditBlockLevel:_preEditBlockLevel
                                                  preEditParagraphWasEmpty:_preEditParagraphWasEmpty
                                                             pendingStyles:[_pendingStyles copy]
                                                      pendingStyleRemovals:[_pendingStyleRemovals copy]];

  BOOL touchedNewline = [_editPipeline processTextChangeWithContext:context];

  // Consumed: clear pre-edit state so stale values can't leak to the next edit.
  _preEditBlockType = ENRMInputBlockTypeParagraph;
  _preEditBlockLevel = 0;
  _preEditParagraphWasEmpty = NO;
  _preEditReplacedNewline = NO;

  _lastTextLength = newLength;

#if !TARGET_OS_OSX
  if (newLength == 0) {
    if ([self headingLevelForCursorParagraph] > 0 || [self listBlockForCursorParagraph] != nil) {
      [self syncTypingAttributesWithCursorBlock];
    } else {
      [self resetBaseTypingAttributes];
    }
  }
#endif

  if (touchedNewline) {
    [self applyFormatting];
  } else {
    [self applyFormattingScopedToEditAtLocation:editLocation insertedLength:insertedLength];
  }

  if (_textView.selectedRange.length == 0) {
    [self syncTypingAttributesWithCursorBlock];
  }

  if ([self listBlockForCursorParagraph] != nil) {
    [self syncTypingAttributesWithCursorBlock];
  } else if (_textView.typingAttributes[NSParagraphStyleAttributeName] != nil) {
    [self clearListParagraphStyleFromTypingAttributes];
  }

  [_editPipeline detectLinksAtLocation:editLocation insertedLength:insertedLength];

  [self updatePlaceholderVisibility];
  [self emitOnChangeText];
  [self emitOnChangeSelection];
  [self emitFormattingChanged];
  [self updateActiveMention];
  [self emitCaretRectChangeIfNeeded];
  [self requestHeightUpdate];
  [self scheduleRelayoutIfNeeded];
  [self updateEmptyBulletMarker];
}

#pragma mark - Text view delegate

#if !TARGET_OS_OSX

- (void)stripLinkTypingAttributes
{
  NSMutableDictionary *attrs = [_textView.typingAttributes mutableCopy];
  BOOL changed = NO;

  UIColor *linkColor = _formatterStyle.linkColor;
  UIColor *currentColor = attrs[NSForegroundColorAttributeName];
  if (currentColor != nil && linkColor != nil && [currentColor isEqual:linkColor]) {
    attrs[NSForegroundColorAttributeName] = _formatterStyle.baseTextColor;
    changed = YES;
  }

  if (attrs[NSUnderlineStyleAttributeName] != nil) {
    [attrs removeObjectForKey:NSUnderlineStyleAttributeName];
    changed = YES;
  }

  if (attrs[NSLinkAttributeName] != nil) {
    [attrs removeObjectForKey:NSLinkAttributeName];
    changed = YES;
  }

  if (changed) {
    _textView.typingAttributes = attrs;
  }
}

- (void)manageSelectionBasedChanges
{
  [self stripLinkTypingAttributes];

  if (_textView.selectedRange.length == 0 && _editSession.phase == ENRMEditPhaseIdle) {
    NSString *text = ENRMGetPlainText(_textView);
    if (text.length > 0) {
      NSRange paragraphRange = [text paragraphRangeForRange:_textView.selectedRange];
      NSString *paragraphText = [text substringWithRange:paragraphRange];
      BOOL isEmpty = paragraphText.length == 0 || [paragraphText isEqualToString:@"\n"];
      if (isEmpty) {
        if ([self headingLevelForCursorParagraph] > 0 || [self listBlockForCursorParagraph] != nil) {
          [self syncTypingAttributesWithCursorBlock];
        } else {
          NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
          attrs[NSFontAttributeName] = _formatterStyle.baseFont;
          attrs[NSForegroundColorAttributeName] = _formatterStyle.baseTextColor;
          _textView.typingAttributes = attrs;
        }
      }
    }
  }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
  if ([self deleteLinkForReplacementRange:range replacementText:text]) {
    return NO;
  }
  if ([self handleListKeyForReplacementRange:range replacementText:text]) {
    return NO;
  }
  _preEditSelectedRange = _lastSelectedRange;
  [self capturePreEditBlockForRange:range];
  _preEditParagraphWasEmpty = [self preEditParagraphWasEmpty:range];
  _preEditReplacedNewline = [self replacedRangeTouchesNewline:range];
  [_editSession enterPhase:ENRMEditPhaseProcessing];
  [self stripLinkTypingAttributes];
  return YES;
}

- (void)textViewDidChange:(UITextView *)textView
{
  if (_editSession.shouldSuppressFormatting) {
    return;
  }
  [self handleTextChanged];
  [_editSession exitPhase];
  [_editSession recordTextChange];
  _lastSelectedRange = textView.selectedRange;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
  [self emitOnFocus];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
  [self clearActiveMention:nil];
  [self emitOnBlur];
}

- (void)textViewDidChangeSelection:(UITextView *)textView
{
  NSRange newSelection = textView.selectedRange;
  if (!_editSession.shouldSuppressSelectionSideEffects && !_editSession.isComposing) {
    NSRange adjusted = [_formattingStore selectionAdjustedForAtomicLinks:newSelection];
    if (!NSEqualRanges(adjusted, newSelection)) {
      _textView.selectedRange = adjusted;
      return;
    }
  }
  NSRange previousSelection = _lastSelectedRange;
  _lastSelectedRange = newSelection;

  if (_editSession.shouldSuppressSelectionSideEffects) {
    return;
  }

  if (_editSession.isComposing) {
    return;
  }

  BOOL selectionMoved =
      newSelection.location != previousSelection.location || newSelection.length != previousSelection.length;

  if (selectionMoved) {
    [self resetPendingStylesForSelectionChange];
  }

  [self manageSelectionBasedChanges];

  [self emitOnChangeSelection];
  [self updateActiveMention];
  [self emitOnChangeState];
  [self emitCaretRectChangeIfNeeded];
  [self updateEmptyBulletMarker];
}

#else

#pragma mark - RCTBackedTextInputDelegate (macOS)

- (BOOL)textInputShouldBeginEditing
{
  return YES;
}

- (void)textInputDidBeginEditing
{
  [self emitOnFocus];
}

- (BOOL)textInputShouldEndEditing
{
  return YES;
}

- (void)textInputDidEndEditing
{
  [self clearActiveMention:nil];
  [self emitOnBlur];
}

- (BOOL)textInputShouldReturn
{
  return NO;
}

- (void)textInputDidReturn
{
}

- (BOOL)textInputShouldSubmitOnReturn
{
  return NO;
}

- (nullable NSString *)textInputShouldChangeText:(NSString *)text inRange:(NSRange)range
{
  if ([self deleteLinkForReplacementRange:range replacementText:text]) {
    return nil;
  }
  _preEditSelectedRange = _lastSelectedRange;
  // Capture the same pre-edit block state the iOS path does — otherwise these
  // ivars carry stale values from a previous edit into reconcileBlockContinuation.
  [self capturePreEditBlockForRange:range];
  _preEditParagraphWasEmpty = [self preEditParagraphWasEmpty:range];
  _preEditReplacedNewline = [self replacedRangeTouchesNewline:range];
  [_editSession enterPhase:ENRMEditPhaseProcessing];
  return text;
}

- (void)textInputDidChange
{
  if (_editSession.shouldSuppressFormatting) {
    [_editSession exitPhase];
    return;
  }
  [self handleTextChanged];
  [_editSession exitPhase];
  [_editSession recordTextChange];
  _lastSelectedRange = _textView.selectedRange;
}

- (void)textInputDidChangeSelection
{
  NSRange newSelection = _textView.selectedRange;
  if (!_editSession.shouldSuppressSelectionSideEffects && !_editSession.isComposing) {
    NSRange adjusted = [_formattingStore selectionAdjustedForAtomicLinks:newSelection];
    if (!NSEqualRanges(adjusted, newSelection)) {
      _textView.selectedRange = adjusted;
      return;
    }
  }
  NSRange previousSelection = _lastSelectedRange;
  _lastSelectedRange = newSelection;

  if (_editSession.shouldSuppressSelectionSideEffects) {
    return;
  }

  if (_editSession.isComposing) {
    return;
  }

  BOOL selectionMoved =
      newSelection.location != previousSelection.location || newSelection.length != previousSelection.length;

  if (selectionMoved) {
    [self resetPendingStylesForSelectionChange];
  }

  [self emitOnChangeSelection];
  [self updateActiveMention];
  [self emitOnChangeState];
  [self emitCaretRectChangeIfNeeded];
}

// @required stubs for RCTBackedTextInputDelegate — RCTUITextView's internal adapter
// calls these via textInputDelegate; omitting any causes silent failures or crashes.

- (BOOL)textInputShouldHandleDeleteBackward:(id<RCTBackedTextInputViewProtocol>)sender
{
  return YES;
}

- (BOOL)textInputShouldHandleDeleteForward:(id<RCTBackedTextInputViewProtocol>)sender
{
  return YES;
}

- (BOOL)textInputShouldHandleKeyEvent:(NSEvent *)event
{
  return YES;
}

- (BOOL)hasKeyDownEventOrKeyUpEvent:(NSString *)key
{
  return NO;
}

- (NSDragOperation)textInputDraggingEntered:(id<NSDraggingInfo>)draggingInfo
{
  return NSDragOperationNone;
}

- (void)textInputDraggingExited:(id<NSDraggingInfo>)draggingInfo
{
}

- (BOOL)textInputShouldHandleDragOperation:(id<NSDraggingInfo>)draggingInfo
{
  return YES;
}

- (void)textInputDidCancel
{
}

- (BOOL)textInputShouldHandlePaste:(id<RCTBackedTextInputViewProtocol>)sender
{
  return YES;
}

- (void)automaticSpellingCorrectionDidChange:(BOOL)enabled
{
}

- (void)continuousSpellCheckingDidChange:(BOOL)enabled
{
}

- (void)grammarCheckingDidChange:(BOOL)enabled
{
}

- (void)submitOnKeyDownIfNeeded:(NSEvent *)event
{
}

#endif

@end

Class<RCTComponentViewProtocol> EnrichedMarkdownTextInputCls(void)
{
  return EnrichedMarkdownTextInput.class;
}
