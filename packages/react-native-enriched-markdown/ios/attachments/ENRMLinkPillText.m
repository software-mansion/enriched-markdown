#import "ENRMLinkPillText.h"
#import "ENRMLinkIconAttachment.h"
#import "ENRMLinkPillAttachment.h"

#if !TARGET_OS_OSX

static const unichar kWordJoiner = 0x2060;

static BOOL ENRMIsIconJoiner(NSAttributedString *text, NSUInteger index)
{
  return index < text.length && [text.string characterAtIndex:index] == kWordJoiner &&
         [text attribute:ENRMLinkIconJoinerAttributeName atIndex:index effectiveRange:NULL] != nil;
}

/// Inline parents (strong, emphasis) restyle the placeholder's font after the pill was created; carry that over.
static UIFont *ENRMFontAddingTraits(UIFont *font, UIFontDescriptorSymbolicTraits traits)
{
  UIFontDescriptorSymbolicTraits current = font.fontDescriptor.symbolicTraits;
  if ((current & traits) == traits)
    return font;
  UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorWithSymbolicTraits:current | traits];
  return descriptor ? [UIFont fontWithDescriptor:descriptor size:font.pointSize] : font;
}

static NSAttributedString *ENRMExpandedLinkPill(ENRMLinkPillAttachment *pill, NSDictionary *placeholderAttributes)
{
  NSMutableAttributedString *expanded = [pill.originalText mutableCopy];
  NSRange all = NSMakeRange(0, expanded.length);
  // The placeholder started with the font of the link's first character, so only traits it has
  // gained since come from an enclosing parent.
  UIFont *placeholderFont = placeholderAttributes[NSFontAttributeName];
  UIFont *firstFont = all.length > 0 ? [expanded attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] : nil;
  UIFontDescriptorSymbolicTraits inherited = placeholderFont.fontDescriptor.symbolicTraits &
                                             ~firstFont.fontDescriptor.symbolicTraits &
                                             (UIFontDescriptorTraitBold | UIFontDescriptorTraitItalic);
  [placeholderAttributes enumerateKeysAndObjectsUsingBlock:^(NSAttributedStringKey key, id value, BOOL *stop) {
    if ([key isEqualToString:NSAttachmentAttributeName])
      return;
    BOOL isFont = [key isEqualToString:NSFontAttributeName];
    [pill.originalText enumerateAttribute:key
                                  inRange:all
                                  options:0
                               usingBlock:^(id existing, NSRange range, BOOL *innerStop) {
                                 if (!existing) {
                                   [expanded addAttribute:key value:value range:range];
                                 } else if (isFont && inherited != 0) {
                                   [expanded addAttribute:key
                                                    value:ENRMFontAddingTraits(existing, inherited)
                                                    range:range];
                                 }
                               }];
  }];
  return expanded;
}

#endif

void ENRMLinkPillsAdoptPlaceholderFonts(NSAttributedString *text)
{
#if !TARGET_OS_OSX
  [text enumerateAttribute:NSAttachmentAttributeName
                   inRange:NSMakeRange(0, text.length)
                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  if ([value isKindOfClass:ENRMLinkPillAttachment.class] ||
                      [value isKindOfClass:ENRMLinkIconAttachment.class])
                    [value adoptFont:[text attribute:NSFontAttributeName atIndex:range.location effectiveRange:NULL]];
                }];
#endif
}

NSAttributedString *ENRMAttributedStringByExpandingLinkPills(NSAttributedString *text, NSRange *ioRange)
{
#if TARGET_OS_OSX
  return text;
#else
  if (text.length == 0)
    return text;
  NSMutableArray<NSValue *> *ranges = nil;
  // Per range, the pill it expands to, or NSNull for an icon (or a lone joiner) that is removed.
  NSMutableArray *replaced = nil;
  NSRange all = NSMakeRange(0, text.length);
  NSRange cursor = NSMakeRange(0, 0);
  // A range cut between an icon and its word joiner starts with the joiner alone.
  if (ENRMIsIconJoiner(text, 0)) {
    ranges = [NSMutableArray arrayWithObject:[NSValue valueWithRange:NSMakeRange(0, 1)]];
    replaced = [NSMutableArray arrayWithObject:NSNull.null];
    cursor = NSMakeRange(1, 0);
  }
  while (NSMaxRange(cursor) < text.length) {
    id value = [text attribute:NSAttachmentAttributeName
                       atIndex:NSMaxRange(cursor)
         longestEffectiveRange:&cursor
                       inRange:all];
    if ([value isKindOfClass:ENRMLinkIconAttachment.class]) {
      // The word joiner after the icon goes with it.
      if (ENRMIsIconJoiner(text, NSMaxRange(cursor)))
        cursor.length += 1;
      value = NSNull.null;
    } else if (![value isKindOfClass:ENRMLinkPillAttachment.class]) {
      continue;
    }
    if (!replaced) {
      ranges = [NSMutableArray new];
      replaced = [NSMutableArray new];
    }
    [ranges addObject:[NSValue valueWithRange:cursor]];
    [replaced addObject:value];
  }
  if (!replaced)
    return text;

  NSMutableAttributedString *result = [text mutableCopy];
  NSRange range = ioRange ? *ioRange : NSMakeRange(0, 0);
  NSInteger start = (NSInteger)range.location;
  NSInteger end = (NSInteger)NSMaxRange(range);
  // Back to front, so earlier ranges stay valid while the string changes length.
  for (NSInteger i = (NSInteger)replaced.count - 1; i >= 0; i--) {
    NSRange placeholder = ranges[i].rangeValue;
    NSAttributedString *expanded =
        [replaced[i] isKindOfClass:ENRMLinkPillAttachment.class]
            ? ENRMExpandedLinkPill((ENRMLinkPillAttachment *)replaced[i], [text attributesAtIndex:placeholder.location
                                                                                   effectiveRange:NULL])
            : [NSAttributedString new];
    [result replaceCharactersInRange:placeholder withAttributedString:expanded];
    NSInteger growth = (NSInteger)expanded.length - (NSInteger)placeholder.length;
    // A bound inside a removed icon moves to where the icon was.
    NSInteger from = (NSInteger)placeholder.location;
    NSInteger to = (NSInteger)NSMaxRange(placeholder);
    start = start <= from ? start : (start >= to ? start + growth : from);
    end = end <= from ? end : (end >= to ? end + growth : from + (NSInteger)expanded.length);
  }
  if (ioRange)
    *ioRange = NSMakeRange((NSUInteger)start, (NSUInteger)MAX(0, end - start));
  return result;
#endif
}

NSString *ENRMStringByExpandingLinkPills(NSAttributedString *text)
{
  return ENRMAttributedStringByExpandingLinkPills(text, NULL).string;
}

NSString *ENRMStringByExpandingLinkPillsAtIndex(NSAttributedString *text, NSUInteger *ioIndex)
{
  NSRange range = NSMakeRange(*ioIndex, 0);
  NSString *expanded = ENRMAttributedStringByExpandingLinkPills(text, &range).string;
  *ioIndex = range.location;
  return expanded;
}
