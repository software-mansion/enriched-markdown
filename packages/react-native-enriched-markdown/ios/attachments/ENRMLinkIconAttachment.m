#import "ENRMLinkIconAttachment.h"
#import "ENRMImageAttachment.h"
#import "ENRMLinkPillIconCache.h"
#import "ENRMSpoilerTapUtils.h"
#import "RuntimeKeys.h"
#import <objc/runtime.h>

#if !TARGET_OS_OSX

// The icon is a square of the font size; the slot adds a quarter of it as the gap to the text.
static const CGFloat kIconSlotRatio = 1.25;

@implementation ENRMLinkIconAttachment {
  UIImage *_icon;
  UIColor *_iconTint;
  UIFont *_font;
  // Space for the icon is held while a remote icon is still loading, so its arrival only needs a redraw.
  BOOL _reservesIconSlot;
  __weak NSTextContainer *_textContainer;
  // TextKit asks for the image on every draw; streaming redraws often.
  UIImage *_rendered;
  CGSize _renderedSize;
  BOOL _renderedRightToLeft;
}

- (instancetype)initWithIconUri:(NSString *)iconUri
                  iconTintColor:(UIColor *)iconTintColor
                           font:(UIFont *)font
                 requestHeaders:(NSDictionary<NSString *, NSString *> *)requestHeaders
{
  self = [super initWithData:nil ofType:nil];
  if (self) {
    _iconTint = iconTintColor;
    _font = font ?: [UIFont systemFontOfSize:16];
    _icon = ENRMLoadLinkPillIcon(iconUri) ?: ENRMCachedLinkPillIcon(iconUri, requestHeaders);
    _reservesIconSlot = _icon != nil;
    if (!_icon && !ENRMLinkPillIconDidFail(iconUri, requestHeaders)) {
      _reservesIconSlot = YES;
      __weak typeof(self) weakSelf = self;
      ENRMLoadLinkPillIconAsync(iconUri, requestHeaders, ^(UIImage *icon) { [weakSelf iconDidSettle:icon]; });
    }
  }
  return self;
}

- (void)adoptFont:(UIFont *)font
{
  if (font)
    _font = font;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)container
                      proposedLineFragment:(CGRect)lineFragment
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)characterIndex
{
  if (container)
    _textContainer = container;
  if (!_reservesIconSlot)
    return CGRectZero;
  CGFloat side = _font.pointSize;
  // Centred on the capitals, as the label next to it is.
  return CGRectMake(0, round((_font.capHeight - side) / 2), ceil(side * kIconSlotRatio), side);
}

- (UIImage *)imageForBounds:(CGRect)bounds textContainer:(NSTextContainer *)container characterIndex:(NSUInteger)index
{
  if (container)
    _textContainer = container;
  if (!_icon || bounds.size.width <= 0 || bounds.size.height <= 0)
    return nil;
  BOOL rightToLeft = NO;
  if (container) {
    NSTextStorage *storage = container.layoutManager.textStorage;
    // The spoiler hides text by clearing its color, which this drawing does not use.
    if (index < storage.length && [storage attribute:SpoilerAttributeName atIndex:index effectiveRange:NULL])
      return nil;
    NSParagraphStyle *paragraph = index < storage.length ? [storage attribute:NSParagraphStyleAttributeName
                                                                      atIndex:index
                                                               effectiveRange:NULL]
                                                         : nil;
    rightToLeft = paragraph.baseWritingDirection == NSWritingDirectionRightToLeft;
  }
  if (_rendered && CGSizeEqualToSize(_renderedSize, bounds.size) && _renderedRightToLeft == rightToLeft)
    return _rendered;
  CGFloat side = bounds.size.height;
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.opaque = NO;
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:bounds.size format:format];
  _rendered = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    CGFloat scale = side / MAX(_icon.size.width, _icon.size.height);
    CGSize iconSize = CGSizeMake(_icon.size.width * scale, _icon.size.height * scale);
    // The gap faces the text that follows, which sits to the left in a right-to-left paragraph.
    CGFloat slotX = rightToLeft ? bounds.size.width - side : 0;
    CGRect iconRect =
        CGRectMake(slotX + (side - iconSize.width) / 2, (side - iconSize.height) / 2, iconSize.width, iconSize.height);
    UIImage *presented =
        _iconTint ? [_icon imageWithTintColor:_iconTint renderingMode:UIImageRenderingModeAlwaysOriginal] : _icon;
    [presented drawInRect:iconRect];
  }];
  _renderedSize = bounds.size;
  _renderedRightToLeft = rightToLeft;
  return _rendered;
}

- (void)iconDidSettle:(UIImage *)icon
{
  _icon = icon;
  _rendered = nil;
  BOOL slotReleased = icon == nil;
  if (slotReleased)
    _reservesIconSlot = NO;

  if (self.onIconLoaded)
    self.onIconLoaded();

  NSTextContainer *container = _textContainer;
  ENRMPlatformTextView *textView = container ? objc_getAssociatedObject(container, kTextViewKey) : nil;
  if (!textView)
    return;
  NSRange range = [self rangeInText:textView.textStorage];
  if (range.location == NSNotFound)
    return;
  [textView.layoutManager invalidateDisplayForCharacterRange:range];
  if (!slotReleased)
    return;
  // The slot is gone, so lines can reflow: lay out again and let the host re-measure.
  [textView.layoutManager invalidateLayoutForCharacterRange:range actualCharacterRange:NULL];
  id<ENRMImageLayoutObserver> observer = [textView enrm_imageLayoutObserver];
  if (observer)
    dispatch_async(dispatch_get_main_queue(), ^{ [observer imageAttachmentDidResolveLayout]; });
}

- (NSRange)rangeInText:(NSAttributedString *)text
{
  __block NSRange found = NSMakeRange(NSNotFound, 0);
  [text enumerateAttribute:NSAttachmentAttributeName
                   inRange:NSMakeRange(0, text.length)
                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  if (value == self) {
                    found = range;
                    *stop = YES;
                  }
                }];
  return found;
}
@end

#endif
