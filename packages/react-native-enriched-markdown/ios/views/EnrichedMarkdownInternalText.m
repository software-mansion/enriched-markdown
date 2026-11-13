#import "EnrichedMarkdownInternalText.h"
#import "ENRMAccessibilityLabels.h"
#import "ENRMContextMenuTextView+macOS.h"
#import "ENRMImageAttachment.h"
#import "ENRMMarkdownTextView.h"
#import "ENRMSpoilerOverlayManager.h"
#import "ENRMTextRenderer.h"
#import "ENRMTextViewSetup.h"
#import "ENRMTextViewport.h"
#import "MarkdownAccessibilityElementBuilder.h"
#import "MarkdownExtractor.h"
#import "PasteboardUtils.h"
#import "RenderedMarkdownSegment.h"
#import "RuntimeKeys.h"
#include <TargetConditionals.h>

@interface EnrichedMarkdownInternalText () <ENRMImageLayoutObserver>
@end

@implementation EnrichedMarkdownInternalText {
  ENRMPlatformTextView *_textView;
#if !TARGET_OS_OSX
  NSMutableArray<UIAccessibilityElement *> *_accessibilityElements;
#else
  NSMutableArray *_accessibilityElements;
#endif
  BOOL _accessibilityNeedsRebuild;
  ENRMSpoilerOverlayManager *_spoilerManager;
  ENRMTextViewport *_viewport;
}

@synthesize textView = _textView;
@synthesize spoilerManager = _spoilerManager;

- (instancetype)initWithConfig:(StyleConfig *)config
{
  if (self = [super init]) {
    _config = config;
    _allowTrailingMargin = NO;
    _lastElementMarginBottom = 0;
    [self setupTextView];
  }
  return self;
}

- (void)setupTextView
{
  __weak EnrichedMarkdownInternalText *weakCopyOwner = self;
  void (^copySelectionHandler)(NSRange) = ^(NSRange range) {
    EnrichedMarkdownInternalText *owner = weakCopyOwner;
    if (!owner)
      return;
    NSAttributedString *text = owner->_textView.textStorage;
    ENRMCopySelection([text attributedSubstringFromRange:range], range,
                      extractMarkdownFromAttributedString(text, range), owner -> _config, owner.onSelectionCopy);
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

  [self addSubview:_textView];

  [self setupLayoutManager];

  _spoilerManager = [[ENRMSpoilerOverlayManager alloc] initWithTextView:_textView config:_config];
  _spoilerManager.spoilerOverlay = _spoilerOverlay;

  _viewport = [[ENRMTextViewport alloc] initWithTextView:_textView];
}

- (void)setupLayoutManager
{
  ENRMAttachLayoutManager(_textView, _config);
}

- (void)setSpoilerOverlay:(ENRMSpoilerOverlay)spoilerOverlay
{
  _spoilerOverlay = spoilerOverlay;
  _spoilerManager.spoilerOverlay = spoilerOverlay;
}

- (void)applyAttributedText:(NSMutableAttributedString *)text context:(RenderContext *)context
{
  ENRMSetLayoutManagerConfig(_textView.layoutManager, _config);

  objc_setAssociatedObject(_textView.textContainer, kTextViewKey, _textView, OBJC_ASSOCIATION_ASSIGN);

  _accessibilityElements = nil;
  _accessibilityNeedsRebuild = YES;

  ENRMSetAttributedText(_textView, text);

  [_textView.layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, text.length) actualCharacterRange:NULL];

  [_spoilerManager setNeedsUpdate];
  [self setNeedsLayout];

#if !TARGET_OS_OSX
  [_textView setNeedsLayout];
#endif
  ENRMSetNeedsDisplay(_textView);
}

- (void)applyAttributedTextPatch:(NSAttributedString *)tail from:(NSUInteger)start
{
  _accessibilityElements = nil;
  _accessibilityNeedsRebuild = YES;

  NSTextStorage *storage = _textView.textStorage;
  [storage beginEditing];
  [storage replaceCharactersInRange:NSMakeRange(start, storage.length - start) withAttributedString:tail];
  [storage endEditing];

  [_spoilerManager setNeedsUpdate];
  [self setNeedsLayout];

#if !TARGET_OS_OSX
  [_textView setNeedsLayout];
#endif
  ENRMSetNeedsDisplay(_textView);
}

- (CGFloat)measureHeight:(CGFloat)maxWidth
{
  return [self measureSize:maxWidth].height;
}

- (CGSize)measureSize:(CGFloat)maxWidth
{
  return ENRMMeasureMarkdownText(_viewport, _textView, maxWidth, _config, _allowTrailingMargin,
                                 _lastElementMarginBottom);
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _viewport.contentFrame = self.bounds;

  [_spoilerManager updateIfNeeded];
}

#if !TARGET_OS_OSX
- (void)didMoveToWindow
{
  [super didMoveToWindow];
  [_viewport update];
}
#endif

- (void)setVisibleArea:(ENRMVisibleArea *)visibleArea
{
  _viewport.visibleArea = visibleArea;
}

- (ENRMVisibleArea *)visibleArea
{
  return _viewport.visibleArea;
}

- (void)updateViewport
{
  [_viewport update];
}

- (void)refreshAfterWindowAttach
{
  _viewport.contentFrame = self.bounds;
  [_viewport refreshLayout];
}

// An attachment that settles after render (an image's box, a link pill giving up its icon
// slot) moves the text around it, and the spoiler overlays with it.
- (void)imageAttachmentDidResolveLayout
{
  [_spoilerManager setNeedsUpdate];
  [_spoilerManager updateIfNeeded];
  // VoiceOver's elements hold frames from the old layout.
  _accessibilityNeedsRebuild = YES;
#if !TARGET_OS_OSX
  UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
#endif
  [[self.superview enrm_imageLayoutObserver] imageAttachmentDidResolveLayout];
}

#pragma mark - Accessibility

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

#if TARGET_OS_OSX
- (void)setContextMenuProvider:(ENRMContextMenuProvider)provider
{
  ((ENRMContextMenuTextView *)_textView).contextMenuProvider = provider;
}
#endif

@end

NSIndexSet *ENRMSyncTextRevisions(NSArray<ENRMRenderedSegment *> *segments, NSArray<RCTUIView *> *views)
{
  NSMutableIndexSet *missedPatches = [NSMutableIndexSet indexSet];
  for (NSUInteger i = 0; i < segments.count && i < views.count; i++) {
    ENRMRenderedSegment *segment = segments[i];
    EnrichedMarkdownInternalText *view = (EnrichedMarkdownInternalText *)views[i];
    if (segment.kind != ENRMSegmentKindText || ![view isKindOfClass:[EnrichedMarkdownInternalText class]] ||
        view.renderedRevision == segment.textResult.revision) {
      continue;
    }
    if (segment.textResult.attributedText) {
      view.renderedRevision = segment.textResult.revision;
    } else {
      [missedPatches addIndex:i];
    }
  }
  return missedPatches;
}
