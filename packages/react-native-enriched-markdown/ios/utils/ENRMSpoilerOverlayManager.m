#import "ENRMSpoilerOverlayManager.h"
#import "ENRMSpoilerOverlayView.h"
#import "ENRMSpoilerTapUtils.h"

static NSString *overlayKey(NSRange charRange, CGRect frame)
{
  return [NSString stringWithFormat:@"%lu-%lu-%.0f-%.0f-%.0f-%.0f", (unsigned long)charRange.location,
                                    (unsigned long)charRange.length, frame.origin.x, frame.origin.y, frame.size.width,
                                    frame.size.height];
}

@interface ENRMSpoilerTextViewLayout : NSObject <ENRMSpoilerTextLayout>
@property (nonatomic, weak) ENRMPlatformTextView *textView;
@end

@implementation ENRMSpoilerTextViewLayout
- (NSTextStorage *)textStorage
{
  return _textView.textStorage;
}
- (NSLayoutManager *)layoutManager
{
  return _textView.layoutManager;
}
- (NSTextContainer *)textContainer
{
  return _textView.textContainer;
}
- (RCTUIView *)spoilerOverlayHost
{
  return _textView;
}
- (CGPoint)spoilerTextOrigin
{
  UIEdgeInsets inset = _textView.textContainerInset;
  return CGPointMake(inset.left, inset.top);
}
- (BOOL)spoilerLayoutReady
{
  return _textView && _textView.bounds.size.width > 0;
}
@end

@implementation ENRMSpoilerOverlayManager {
  __weak id<ENRMSpoilerTextLayout> _layout;
  ENRMSpoilerTextViewLayout *_ownedLayout;
  StyleConfig *_config;
  NSMutableDictionary<NSString *, ENRMSpoilerOverlayView *> *_overlaysByKey;
  BOOL _needsUpdate;
}

- (void)setSpoilerOverlay:(ENRMSpoilerOverlay)spoilerOverlay
{
  if (_spoilerOverlay == spoilerOverlay)
    return;
  _spoilerOverlay = spoilerOverlay;
  [self rebuildOverlays];
}

- (void)rebuildOverlays
{
  for (ENRMSpoilerOverlayView *overlay in _overlaysByKey.allValues) {
    [overlay removeFromSuperview];
  }
  [_overlaysByKey removeAllObjects];
  _needsUpdate = YES;
  [self updateIfNeeded];
}

- (instancetype)initWithTextView:(ENRMPlatformTextView *)textView config:(StyleConfig *)config
{
  ENRMSpoilerTextViewLayout *layout = [ENRMSpoilerTextViewLayout new];
  layout.textView = textView;
  if (self = [self initWithLayout:layout config:config]) {
    _ownedLayout = layout;
  }
  return self;
}

- (instancetype)initWithLayout:(id<ENRMSpoilerTextLayout>)layout config:(StyleConfig *)config
{
  if (self = [super init]) {
    _layout = layout;
    _config = config;
    _overlaysByKey = [NSMutableDictionary new];
  }
  return self;
}

#pragma mark - Public

- (void)setNeedsUpdate
{
  _needsUpdate = YES;
}

- (void)updateIfNeeded
{
  if (!_needsUpdate)
    return;
  // Intentionally keep _needsUpdate=YES when the text has no width yet:
  // the update will be retried on the next layout pass.
  if (!_layout.spoilerLayoutReady)
    return;
  [self updateOverlays];
}

- (void)removeOverlaysForCharRange:(NSRange)charRange
{
  NSMutableArray<NSString *> *keysToReveal = [NSMutableArray new];
  [_overlaysByKey enumerateKeysAndObjectsUsingBlock:^(NSString *key, ENRMSpoilerOverlayView *overlay, BOOL *stop) {
    if (NSIntersectionRange(overlay.charRange, charRange).length > 0) {
      [keysToReveal addObject:key];
    }
  }];

  // Keep revealing overlays in _overlaysByKey so updateOverlays won't create
  // duplicates during the animation. They are removed on completion.
  for (NSString *key in keysToReveal) {
    ENRMSpoilerOverlayView *overlay = _overlaysByKey[key];
    NSMutableDictionary *dict = _overlaysByKey;
    [overlay animateRevealWithCompletion:^{ [dict removeObjectForKey:key]; }];
  }
}

- (void)removeAllOverlays
{
  NSTextStorage *storage = _layout.textStorage;
  if (storage.length > 0) {
    ENRMRestoreSpoilerTextColors(storage, NSMakeRange(0, storage.length));
  }
  for (ENRMSpoilerOverlayView *overlay in _overlaysByKey.allValues) {
    [overlay removeFromSuperview];
  }
  [_overlaysByKey removeAllObjects];
}

#pragma mark - Private

- (void)updateOverlays
{
  _needsUpdate = NO;

  RCTUIView *host = _layout.spoilerOverlayHost;
  if (!host) {
    [self removeAllOverlays];
    return;
  }

  NSTextStorage *textStorage = _layout.textStorage;
  if (!textStorage || textStorage.length == 0) {
    [self removeAllOverlays];
    return;
  }

  NSLayoutManager *layoutManager = _layout.layoutManager;
  NSTextContainer *textContainer = _layout.textContainer;
  [layoutManager ensureLayoutForTextContainer:textContainer];

  CGPoint origin = _layout.spoilerTextOrigin;
  RCTUIColor *backgroundColor =
      [_layout respondsToSelector:@selector(spoilerBackgroundColor)] ? _layout.spoilerBackgroundColor : nil;

  NSMutableSet<NSString *> *desiredKeys = [NSMutableSet new];

  [textStorage
      enumerateAttribute:SpoilerAttributeName
                 inRange:NSMakeRange(0, textStorage.length)
                 options:0
              usingBlock:^(id value, NSRange charRange, BOOL *stop) {
                if (!value || charRange.length == 0)
                  return;

                NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
                if (glyphRange.location == NSNotFound || glyphRange.length == 0)
                  return;

                [layoutManager
                    enumerateLineFragmentsForGlyphRange:glyphRange
                                             usingBlock:^(CGRect lineRect, CGRect usedRect, NSTextContainer *container,
                                                          NSRange lineGlyphRange, BOOL *lineStop) {
                                               NSRange intersect = NSIntersectionRange(lineGlyphRange, glyphRange);
                                               if (intersect.length == 0)
                                                 return;

                                               CGRect textRect =
                                                   [layoutManager boundingRectForGlyphRange:intersect
                                                                            inTextContainer:textContainer];
                                               CGRect frame = CGRectMake(textRect.origin.x + origin.x,
                                                                         textRect.origin.y + origin.y,
                                                                         textRect.size.width, textRect.size.height);
                                               if (frame.size.width <= 0 || frame.size.height <= 0)
                                                 return;

                                               NSString *key = overlayKey(charRange, frame);
                                               [desiredKeys addObject:key];

                                               ENRMSpoilerOverlayView *existing = self->_overlaysByKey[key];
                                               if (existing && !existing.revealing)
                                                 return;

                                               ENRMSpoilerOverlayView *overlay =
                                                   [ENRMSpoilerOverlayView overlayWithMode:self->_spoilerOverlay
                                                                                    config:self->_config
                                                                                 charRange:charRange];
                                               overlay.underlyingBackgroundColor = backgroundColor;
                                               overlay.frame = frame;
                                               [host addSubview:overlay];
                                               self->_overlaysByKey[key] = overlay;
                                             }];
              }];

  NSMutableArray<NSString *> *staleKeys = [NSMutableArray new];
  [_overlaysByKey enumerateKeysAndObjectsUsingBlock:^(NSString *key, ENRMSpoilerOverlayView *overlay, BOOL *stop) {
    if (![desiredKeys containsObject:key] && !overlay.revealing) {
      [staleKeys addObject:key];
    }
  }];
  for (NSString *key in staleKeys) {
    ENRMSpoilerOverlayView *overlay = _overlaysByKey[key];
    [overlay removeFromSuperview];
    [_overlaysByKey removeObjectForKey:key];
  }
}

@end
