#import "ENRMLinkPillAttachment.h"
#import "ENRMLinkPillIconCache.h"
#import "ENRMLinkPillTextStorage.h"
#import "StyleConfig.h"
#import <objc/runtime.h>

#if !TARGET_OS_OSX

@implementation ENRMLinkPillAttachment {
  NSString *_label;
  NSString *_originalLinkText;
  LinkVariantConfig *_variant;
  UIFont *_font;
  UIImage *_icon;
}

- (instancetype)initWithLinkText:(NSString *)originalLinkText variant:(LinkVariantConfig *)variant font:(UIFont *)font
{
  self = [super initWithData:nil ofType:nil];
  if (self) {
    _variant = variant;
    _originalLinkText = [originalLinkText copy];
    _font = font ?: [UIFont systemFontOfSize:16];
    NSString *label = variant.label.length > 0 ? variant.label : originalLinkText;
    _label = [[label stringByReplacingOccurrencesOfString:@"\n"
                                               withString:@" "] stringByReplacingOccurrencesOfString:@"\r"
                                                                                          withString:@" "];
    _icon = ENRMLoadLinkPillIcon(variant.iconUri);
  }
  return self;
}

- (NSString *)linkAccessibilityLabel
{
  return [_label isEqualToString:_originalLinkText] ? _originalLinkText
                                                    : [NSString stringWithFormat:@"%@, %@", _label, _originalLinkText];
}

- (CGFloat)boxHeight
{
  return ceil(_font.ascender - _font.descender + 2 * (_variant.paddingVertical + _variant.borderWidth));
}

- (CGFloat)widthForLimit:(CGFloat)available
{
  CGFloat iconWidth = _icon ? _font.pointSize * 1.25 : 0;
  CGFloat natural = ceil([_label sizeWithAttributes:@{NSFontAttributeName : _font}].width + iconWidth +
                         2 * (_variant.paddingHorizontal + _variant.borderWidth));
  CGFloat limit = _variant.maxWidth > 0 ? MIN(available, _variant.maxWidth) : available;
  return MAX(1, MIN(natural, limit));
}

- (BOOL)startsAttachmentInTextContainer:(NSTextContainer *)container characterIndex:(NSUInteger)index
{
  NSTextStorage *storage = container.layoutManager.textStorage;
  if (!storage)
    return YES;
  if (index >= storage.length)
    return NO;
  NSRange range;
  id attachment = [storage attribute:NSAttachmentAttributeName
                             atIndex:index
               longestEffectiveRange:&range
                             inRange:NSMakeRange(0, storage.length)];
  return attachment == self && index == range.location;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)container
                      proposedLineFragment:(CGRect)lineFragment
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)characterIndex
{
  // TextKit can query attachments directly, bypassing the glyph delegate for
  // attachment characters. Only the first source character owns the pill box.
  if (![self startsAttachmentInTextContainer:container characterIndex:characterIndex])
    return CGRectZero;
  // Use the full container width, not the remainder of the current line. TextKit then moves
  // the whole attachment to the next line if it doesn't fit the remainder.
  NSParagraphStyle *paragraph = [container.layoutManager.textStorage attribute:NSParagraphStyleAttributeName
                                                                       atIndex:characterIndex
                                                                effectiveRange:NULL];
  CGFloat indent = MAX(paragraph.firstLineHeadIndent, paragraph.headIndent);
  CGFloat tailInset = paragraph.tailIndent < 0 ? -paragraph.tailIndent : 0;
  CGFloat available = MAX(1, container.size.width - 2 * container.lineFragmentPadding - indent - tailInset);
  CGFloat inset = _variant.paddingVertical + _variant.borderWidth;
  return CGRectMake(0, _font.descender - inset, [self widthForLimit:available], self.boxHeight);
}

- (UIImage *)imageForBounds:(CGRect)bounds textContainer:(NSTextContainer *)container characterIndex:(NSUInteger)index
{
  if (bounds.size.width <= 0 || bounds.size.height <= 0 ||
      ![self startsAttachmentInTextContainer:container characterIndex:index])
    return nil;
  CGSize size = bounds.size;
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.opaque = NO;
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    CGRect rect = (CGRect){CGPointZero, size};
    UIBezierPath *background = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:_variant.borderRadius];
    [_variant.backgroundColor ?: UIColor.clearColor setFill];
    [background fill];
    if (_variant.borderWidth > 0) {
      UIBezierPath *border =
          [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, _variant.borderWidth / 2, _variant.borderWidth / 2)
                                     cornerRadius:_variant.borderRadius];
      border.lineWidth = _variant.borderWidth;
      [_variant.borderColor setStroke];
      [border stroke];
    }
    [background addClip];
    CGFloat left = _variant.paddingHorizontal + _variant.borderWidth;
    CGFloat right = size.width - left;
    if (_icon && right - left >= _font.pointSize) {
      CGFloat side = _font.pointSize;
      CGFloat scale = side / MAX(_icon.size.width, _icon.size.height);
      CGSize iconSize = CGSizeMake(_icon.size.width * scale, _icon.size.height * scale);
      CGRect iconRect = CGRectMake(left + (side - iconSize.width) / 2, (size.height - iconSize.height) / 2,
                                   iconSize.width, iconSize.height);
      UIImage *presentedIcon = _variant.iconTintColor ? [_icon imageWithTintColor:_variant.iconTintColor
                                                                    renderingMode:UIImageRenderingModeAlwaysOriginal]
                                                      : _icon;
      [presentedIcon drawInRect:iconRect];
      left += side * 1.25;
    }
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary *attributes = @{
      NSFontAttributeName : _font,
      NSForegroundColorAttributeName : _variant.color,
      NSUnderlineStyleAttributeName : @(_variant.underline ? NSUnderlineStyleSingle : NSUnderlineStyleNone),
      NSParagraphStyleAttributeName : paragraph,
    };
    [_label drawInRect:CGRectMake(left, _variant.paddingVertical + _variant.borderWidth, MAX(0, right - left),
                                  size.height)
        withAttributes:attributes];
  }];
}
@end

@interface ENRMPillGlyphTail : NSObject
@property (nonatomic) NSUInteger glyphEnd;
@property (nonatomic) NSUInteger characterIndex;
@end
@implementation ENRMPillGlyphTail
@end

static char ENRMPillGlyphTailKey;

// Pills require TextKit 1: substitute glyphs without replacing source characters.
// testOriginalLabelUsesSameAttachmentGeometryAsRealReplacementCharacter guards
// equivalence to native U+FFFC attachment layout when TextKit behavior changes.
@implementation ENRMLinkPillLayoutDelegate
+ (instancetype)shared
{
  static ENRMLinkPillLayoutDelegate *delegate;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ delegate = [[self alloc] init]; });
  return delegate;
}

- (NSUInteger)layoutManager:(NSLayoutManager *)manager
       shouldGenerateGlyphs:(const CGGlyph *)glyphs
                 properties:(const NSGlyphProperty *)properties
           characterIndexes:(const NSUInteger *)indexes
                       font:(UIFont *)font
              forGlyphRange:(NSRange)glyphRange
{
  NSUInteger count = glyphRange.length;
  if (count == 0)
    return 0;
  ENRMPillGlyphTail *tail = objc_getAssociatedObject(manager, &ENRMPillGlyphTailKey);
  BOOL continuesFirstCharacter = tail && tail.glyphEnd == glyphRange.location && tail.characterIndex == indexes[0];
  if (!tail) {
    tail = [ENRMPillGlyphTail new];
    objc_setAssociatedObject(manager, &ENRMPillGlyphTailKey, tail, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  // Remember only the immediately preceding callback. Querying surrounding glyphs
  // during generation can recurse into this delegate before those glyphs exist.
  tail.glyphEnd = NSMaxRange(glyphRange);
  tail.characterIndex = indexes[count - 1];
  NSMutableData *glyphData = nil;
  NSMutableData *propertyData = nil;
  CGGlyph *replacement = NULL;
  NSGlyphProperty *replacementProperties = NULL;
  for (NSUInteger i = 0; i < count; i++) {
    id attachment = [manager.textStorage attribute:NSAttachmentAttributeName atIndex:indexes[i] effectiveRange:NULL];
    if (![attachment isKindOfClass:ENRMLinkPillAttachment.class])
      continue;
    NSRange range;
    // Attribute runs may split at every source character after UIKit fixes fonts/colors.
    // The pill starts at the longest range of the attachment alone, not the current run.
    [manager.textStorage attribute:NSAttachmentAttributeName
                           atIndex:indexes[i]
             longestEffectiveRange:&range
                           inRange:NSMakeRange(0, manager.textStorage.length)];
    if (!glyphData) {
      glyphData = [NSMutableData dataWithBytes:glyphs length:count * sizeof(CGGlyph)];
      propertyData = [NSMutableData dataWithBytes:properties length:count * sizeof(NSGlyphProperty)];
      replacement = glyphData.mutableBytes;
      replacementProperties = propertyData.mutableBytes;
    }
    // A character can have multiple glyphs, even across font/callback boundaries.
    BOOL startsAttachment = indexes[i] == range.location;
    BOOL continuesCharacter = startsAttachment && (i > 0 ? indexes[i - 1] == indexes[i] : continuesFirstCharacter);
    if (startsAttachment && !continuesCharacter) {
      // TextKit's attachment glyph exists only in the glyph buffer, never in text storage.
      replacement[i] = 0xFFFC;
      replacementProperties[i] = 0;
    } else {
      replacement[i] = 0;
      replacementProperties[i] = NSGlyphPropertyNull;
    }
  }
  if (!glyphData)
    return 0;
  [manager setGlyphs:replacement
            properties:replacementProperties
      characterIndexes:indexes
                  font:font
         forGlyphRange:glyphRange];
  return count;
}

- (BOOL)layoutManager:(NSLayoutManager *)manager shouldBreakLineByWordBeforeCharacterAtIndex:(NSUInteger)index
{
  if (index >= manager.textStorage.length)
    return YES;
  id attachment = [manager.textStorage attribute:NSAttachmentAttributeName atIndex:index effectiveRange:NULL];
  if (![attachment isKindOfClass:ENRMLinkPillAttachment.class])
    return YES;
  NSRange range;
  [manager.textStorage attribute:NSAttachmentAttributeName
                         atIndex:index
           longestEffectiveRange:&range
                         inRange:NSMakeRange(0, manager.textStorage.length)];
  return index == range.location;
}
@end

static NSLayoutManager *ENRMPillLayout(NSAttributedString *text, CGSize size, NSTextStorage **storageOut,
                                       NSTextContainer **containerOut)
{
  NSTextStorage *storage = [[ENRMLinkPillTextStorage alloc] initWithAttributedString:text];
  NSLayoutManager *manager = [[NSLayoutManager alloc] init];
  manager.delegate = ENRMLinkPillLayoutDelegate.shared;
  manager.allowsNonContiguousLayout = NO;
  manager.usesFontLeading = NO;
  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:size];
  container.lineFragmentPadding = 0;
  [storage addLayoutManager:manager];
  [manager addTextContainer:container];
  [manager ensureLayoutForTextContainer:container];
  *storageOut = storage;
  *containerOut = container;
  return manager;
}

static BOOL ENRMHasLinkPill(NSAttributedString *text)
{
  __block BOOL found = NO;
  [text enumerateAttribute:NSAttachmentAttributeName
                   inRange:NSMakeRange(0, text.length)
                   options:0
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  if ([value isKindOfClass:ENRMLinkPillAttachment.class]) {
                    found = YES;
                    *stop = YES;
                  }
                }];
  return found;
}

CGRect ENRMLinkPillTextBounds(NSAttributedString *text, CGFloat width)
{
  if (!ENRMHasLinkPill(text))
    return [text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                              options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                              context:nil];
  // NSLayoutManager does not own its storage. Keep it alive through measurement/drawing under ARC.
  __attribute__((objc_precise_lifetime)) NSTextStorage *storage;
  NSTextContainer *container;
  NSLayoutManager *manager = ENRMPillLayout(text, CGSizeMake(width, CGFLOAT_MAX), &storage, &container);
  return [manager usedRectForTextContainer:container];
}

void ENRMDrawLinkPillText(NSAttributedString *text, CGRect rect)
{
  if (!ENRMHasLinkPill(text)) {
    [text drawWithRect:rect options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil];
    return;
  }
  // NSLayoutManager does not own its storage. Keep it alive through measurement/drawing under ARC.
  __attribute__((objc_precise_lifetime)) NSTextStorage *storage;
  NSTextContainer *container;
  NSLayoutManager *manager = ENRMPillLayout(text, rect.size, &storage, &container);
  NSRange glyphs = [manager glyphRangeForTextContainer:container];
  [manager drawBackgroundForGlyphRange:glyphs atPoint:rect.origin];
  [manager drawGlyphsForGlyphRange:glyphs atPoint:rect.origin];
}
#endif
