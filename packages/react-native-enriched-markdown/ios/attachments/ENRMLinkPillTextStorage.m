#import "ENRMLinkPillTextStorage.h"
#import "ENRMLinkPillAttachment.h"

#if !TARGET_OS_OSX
@implementation ENRMLinkPillTextStorage {
  NSMutableAttributedString *_backing;
  NSUInteger _pillCharacters;
}

- (instancetype)init
{
  self = [super init];
  if (self)
    _backing = [[NSMutableAttributedString alloc] init];
  return self;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)text
{
  self = [self init];
  if (self)
    [self setAttributedString:text];
  return self;
}

- (NSString *)string
{
  return _backing.string;
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)range
{
  return [_backing attributesAtIndex:index effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)text
{
  BOOL hadPills = _pillCharacters > 0;
  if (hadPills)
    _pillCharacters -= [self pillCharactersInRange:range];
  [_backing replaceCharactersInRange:range withString:text];
  // Replacement characters can inherit the adjacent attachment attributes.
  if (hadPills)
    _pillCharacters += [self pillCharactersInRange:NSMakeRange(range.location, text.length)];
  [self edited:NSTextStorageEditedCharacters
               range:range
      changeInLength:(NSInteger)text.length - (NSInteger)range.length];
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes range:(NSRange)range
{
  if (_pillCharacters > 0)
    _pillCharacters -= [self pillCharactersInRange:range];
  [_backing setAttributes:attributes range:range];
  if ([attributes[NSAttachmentAttributeName] isKindOfClass:ENRMLinkPillAttachment.class])
    _pillCharacters += range.length;
  [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

- (NSUInteger)pillCharactersInRange:(NSRange)range
{
  __block NSUInteger count = 0;
  [_backing enumerateAttribute:NSAttachmentAttributeName
                       inRange:range
                       options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                    usingBlock:^(id value, NSRange subrange, BOOL *stop) {
                      if ([value isKindOfClass:ENRMLinkPillAttachment.class])
                        count += subrange.length;
                    }];
  return count;
}

/**
 * Pills keep their original source characters, so Foundation strips their
 * attachment attributes during fixing. Collect/restore over the paragraph:
 * fixing may affect a pill outside the edit. Intentionally fix only the
 * requested range; the wider range is exclusively the preservation scope.
 * Restore directly on backing storage within the current edit notification.
 */
- (void)fixAttributesInRange:(NSRange)range
{
  if (_pillCharacters == 0) {
    [_backing fixAttributesInRange:range];
    return;
  }
  NSRange fixingRange = [_backing.string paragraphRangeForRange:range];
  NSMutableArray<NSDictionary *> *pills = [NSMutableArray new];
  [_backing enumerateAttribute:NSAttachmentAttributeName
                       inRange:fixingRange
                       options:0
                    usingBlock:^(id value, NSRange subrange, BOOL *stop) {
                      if ([value isKindOfClass:ENRMLinkPillAttachment.class])
                        [pills addObject:@{@"attachment" : value, @"range" : [NSValue valueWithRange:subrange]}];
                    }];
  [_backing fixAttributesInRange:range];
  for (NSDictionary *pill in pills)
    [_backing addAttribute:NSAttachmentAttributeName value:pill[@"attachment"] range:[pill[@"range"] rangeValue]];
}
@end

UITextView *ENRMCreateMarkdownTextView(void)
{
  ENRMLinkPillTextStorage *storage = [[ENRMLinkPillTextStorage alloc] init];
  NSLayoutManager *manager = [[NSLayoutManager alloc] init];
  manager.delegate = ENRMLinkPillLayoutDelegate.shared;
  [storage addLayoutManager:manager];
  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(0, CGFLOAT_MAX)];
  [manager addTextContainer:container];
  return [[UITextView alloc] initWithFrame:CGRectZero textContainer:container];
}
#endif
