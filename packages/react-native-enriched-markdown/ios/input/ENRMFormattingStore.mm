#import "ENRMFormattingStore.h"
#import "ENRMRangeEditAdjustment.h"
#import "ENRMRangeStoreUtils.h"

#pragma mark - Character classes

static NSUInteger ENRMCodePointLengthAt(NSString *text, NSUInteger position)
{
  return position + 1 < text.length && CFStringIsSurrogateHighCharacter([text characterAtIndex:position]) &&
                 CFStringIsSurrogateLowCharacter([text characterAtIndex:position + 1])
             ? 2
             : 1;
}

static NSUInteger ENRMCodePointLengthBefore(NSString *text, NSUInteger position)
{
  return position >= 2 && CFStringIsSurrogateLowCharacter([text characterAtIndex:position - 1]) &&
                 CFStringIsSurrogateHighCharacter([text characterAtIndex:position - 2])
             ? 2
             : 1;
}

static UTF32Char ENRMCodePointAt(NSString *text, NSUInteger position)
{
  unichar high = [text characterAtIndex:position];
  if (ENRMCodePointLengthAt(text, position) == 2) {
    return CFStringGetLongCharacterForSurrogatePair(high, [text characterAtIndex:position + 1]);
  }
  return high;
}

// md4c's character classes: a word character is neither whitespace nor Unicode punctuation (P) or
// symbol (S), so an emoji counts as punctuation.
static BOOL ENRMIsWordCodePoint(UTF32Char codePoint)
{
  static NSCharacterSet *nonWord;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    NSMutableCharacterSet *set = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
    [set formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
    [set formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
    nonWord = [set copy];
  });
  return ![nonWord longCharacterIsMember:codePoint];
}

static BOOL ENRMIsWordAt(NSString *text, NSUInteger position)
{
  return position < text.length && ENRMIsWordCodePoint(ENRMCodePointAt(text, position));
}

static BOOL ENRMIsWordBefore(NSString *text, NSUInteger position)
{
  return position > 0 && ENRMIsWordAt(text, position - ENRMCodePointLengthBefore(text, position));
}

static BOOL ENRMIsWhitespaceAt(NSString *text, NSUInteger position)
{
  return position < text.length && [[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                       characterIsMember:[text characterAtIndex:position]];
}

static BOOL ENRMIsWhitespaceBefore(NSString *text, NSUInteger position)
{
  return position > 0 && ENRMIsWhitespaceAt(text, position - 1);
}

#pragma mark - Underline separators

/// Where another style's delimiter, written between an underline's `_` and the letter beside it,
/// already makes the `_` readable, so the underline needs no growth there (every delimiter character
/// is punctuation to md4c). Growth follows one rule: it never changes an underline whose markdown
/// reads back, along with the styles beside it, and fixes one that doesn't. So it follows where
/// ENRMMarkdownSerializer writes delimiters:
/// - At one position closings come before openings, so a style ending where an underline starts, or
///   starting where one ends, separates them: `*foo*_bar_`, `_foo_**bar**`.
/// - A style starting (or ending) along with the underline separates only when it nests outside it,
///   and only a link or spoiler would, as on web. Here links and spoilers nest inside
///   (`foo_[bar](u)_`), so none does. Italic and bold nest outside, but between a letter and `_`
///   md4c reads `*` and `**` as text (`foo**_bar_**`), so the underline takes the whole word and
///   both read back: `_foo**bar**_`.
/// The ranges are collected once per call, and no underline is among them, so they stay valid while
/// the underlines grow. A style md4c can't read at its other edge, as a strikethrough starting
/// inside a word, still counts.
@interface ENRMUnderlineSeparators : NSObject
- (instancetype)initWithRanges:(NSArray<ENRMFormattingRange *> *)ranges;
/// An underline starting at `position` needs no growth before it.
- (BOOL)separatesStart:(NSUInteger)position;
/// An underline ending at `position` needs no growth after it.
- (BOOL)separatesEnd:(NSUInteger)position;
@end

@implementation ENRMUnderlineSeparators {
  NSMutableIndexSet *_starts;
  NSMutableIndexSet *_ends;
}

- (instancetype)initWithRanges:(NSArray<ENRMFormattingRange *> *)ranges
{
  if (self = [super init]) {
    _starts = [NSMutableIndexSet indexSet];
    _ends = [NSMutableIndexSet indexSet];
    for (ENRMFormattingRange *range in ranges) {
      if (range.type == ENRMInputStyleTypeUnderline || range.range.length == 0) {
        continue;
      }
      [_starts addIndex:range.range.location];
      [_ends addIndex:NSMaxRange(range.range)];
    }
  }
  return self;
}

- (BOOL)separatesStart:(NSUInteger)position
{
  return [_ends containsIndex:position];
}

- (BOOL)separatesEnd:(NSUInteger)position
{
  return [_starts containsIndex:position];
}

@end

@implementation ENRMFormattingStore {
  NSMutableArray<ENRMFormattingRange *> *_ranges;
}

- (instancetype)init
{
  if (self = [super init]) {
    _ranges = [NSMutableArray array];
  }
  return self;
}

- (NSArray<ENRMFormattingRange *> *)allRanges
{
  return [_ranges copy];
}

- (NSArray<ENRMFormattingRange *> *)rangesOfType:(ENRMInputStyleType)type
{
  NSMutableArray<ENRMFormattingRange *> *result = [NSMutableArray array];
  for (ENRMFormattingRange *formattingRange in _ranges) {
    if (formattingRange.type == type) {
      [result addObject:formattingRange];
    }
  }
  return result;
}

- (void)setRanges:(NSArray<ENRMFormattingRange *> *)ranges
{
  _ranges =
      [[ranges sortedArrayUsingComparator:^NSComparisonResult(ENRMFormattingRange *first, ENRMFormattingRange *second) {
        if (first.range.location < second.range.location)
          return NSOrderedAscending;
        if (first.range.location > second.range.location)
          return NSOrderedDescending;
        return NSOrderedSame;
      }] mutableCopy];
}

- (void)clearAll
{
  [_ranges removeAllObjects];
}

- (nullable ENRMFormattingRange *)rangeOfType:(ENRMInputStyleType)type containingPosition:(NSUInteger)position
{
  for (ENRMFormattingRange *formattingRange in _ranges) {
    if (formattingRange.type != type)
      continue;
    if (position >= formattingRange.range.location && position < NSMaxRange(formattingRange.range)) {
      return formattingRange;
    }
  }
  return nil;
}

- (NSRange)selectionAdjustedForAtomicLinks:(NSRange)selection
{
  if (selection.length > 0) {
    NSUInteger start = selection.location;
    NSUInteger end = NSMaxRange(selection);
    ENRMFormattingRange *startLink = [self rangeOfType:ENRMInputStyleTypeLink containingPosition:start];
    if (startLink != nil) {
      start = MIN(start, startLink.range.location);
    }
    if (end > 0) {
      ENRMFormattingRange *endLink = [self rangeOfType:ENRMInputStyleTypeLink containingPosition:(end - 1)];
      if (endLink != nil) {
        end = MAX(end, NSMaxRange(endLink.range));
      }
    }
    return NSMakeRange(start, end - start);
  }
  ENRMFormattingRange *caretLink = [self rangeOfType:ENRMInputStyleTypeLink containingPosition:selection.location];
  if (caretLink != nil && selection.location > caretLink.range.location &&
      selection.location < NSMaxRange(caretLink.range)) {
    return NSMakeRange(NSMaxRange(caretLink.range), 0);
  }
  return selection;
}

- (BOOL)isStyleActive:(ENRMInputStyleType)type atPosition:(NSUInteger)position
{
  return [self rangeOfType:type containingPosition:position] != nil;
}

- (BOOL)isStyleActive:(ENRMInputStyleType)type inRange:(NSRange)range
{
  for (ENRMFormattingRange *formattingRange in _ranges) {
    if (formattingRange.type == type && NSIntersectionRange(formattingRange.range, range).length > 0) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)isStyleAdjacentBefore:(ENRMInputStyleType)type position:(NSUInteger)position
{
  if (position == 0) {
    return NO;
  }
  return [self rangeOfType:type containingPosition:position] != nil || [self rangeOfType:type
                                                                           containingPosition:position - 1] != nil;
}

- (BOOL)isStyleFullyActive:(ENRMInputStyleType)type inRange:(NSRange)range
{
  NSUInteger pos = range.location;
  NSUInteger end = NSMaxRange(range);
  while (pos < end) {
    ENRMFormattingRange *match = [self rangeOfType:type containingPosition:pos];
    if (match == nil) {
      return NO;
    }
    pos = NSMaxRange(match.range);
  }
  return YES;
}

- (BOOL)toggleStyle:(ENRMInputStyleType)type
              inRange:(NSRange)range
    conflictingStyles:(NSSet<NSNumber *> *)conflictingStyles
{
  BOOL wasActive;
  if (range.length > 0) {
    wasActive = [self isStyleFullyActive:type inRange:range];
    if (wasActive) {
      [self removeType:type inRange:range];
    } else {
      [self addStyle:type inRange:range conflictingStyles:conflictingStyles];
    }
  } else {
    wasActive = [self isStyleActive:type atPosition:range.location];
  }
  return wasActive;
}

- (void)addStyle:(ENRMInputStyleType)type
              inRange:(NSRange)range
    conflictingStyles:(NSSet<NSNumber *> *)conflictingStyles
{
  for (NSNumber *conflict in conflictingStyles) {
    [self removeType:(ENRMInputStyleType)conflict.integerValue inRange:range];
  }
  [self addRange:[ENRMFormattingRange rangeWithType:type range:range]];
}

- (NSRange)wholeWordRangeForStyle:(ENRMInputStyleType)type inText:(NSString *)text range:(NSRange)range
{
  if (type != ENRMInputStyleTypeUnderline) {
    return range;
  }
  if (range.length == 0 && !ENRMIsWordBefore(text, range.location) && !ENRMIsWordAt(text, range.location)) {
    return range;
  }
  return [self rangeGrownToWords:range
                          inText:text
                           grows:range.length == 0
                      separators:[[ENRMUnderlineSeparators alloc] initWithRanges:_ranges]];
}

/// `grows` makes both edges grow, as a caret does; otherwise an edge next to whitespace inside the
/// range stays put.
- (NSRange)rangeGrownToWords:(NSRange)range
                      inText:(NSString *)text
                       grows:(BOOL)grows
                  separators:(ENRMUnderlineSeparators *)separators
{
  NSUInteger start = range.location;
  NSUInteger end = NSMaxRange(range);
  NSUInteger newStart = start;
  if (grows || !ENRMIsWhitespaceAt(text, start)) {
    while (ENRMIsWordBefore(text, newStart) && ![separators separatesStart:newStart]) {
      newStart -= ENRMCodePointLengthBefore(text, newStart);
    }
  }
  NSUInteger newEnd = end;
  if (grows || !ENRMIsWhitespaceBefore(text, end)) {
    while (ENRMIsWordAt(text, newEnd) && ![separators separatesEnd:newEnd]) {
      newEnd += ENRMCodePointLengthAt(text, newEnd);
    }
  }
  return NSMakeRange(newStart, newEnd - newStart);
}

- (void)growToWholeWordsInText:(NSString *)text touchingRange:(NSRange)editRange
{
  NSMutableArray<ENRMFormattingRange *> *touching = [NSMutableArray array];
  for (ENRMFormattingRange *existing in _ranges) {
    NSRange range = existing.range;
    if (existing.type == ENRMInputStyleTypeUnderline && range.length > 0 && NSMaxRange(range) <= text.length &&
        range.location <= NSMaxRange(editRange) && NSMaxRange(range) >= editRange.location) {
      [touching addObject:existing];
    }
  }
  if (touching.count == 0) {
    return;
  }
  ENRMUnderlineSeparators *separators = [[ENRMUnderlineSeparators alloc] initWithRanges:_ranges];
  for (ENRMFormattingRange *existing in touching) {
    NSRange grown = [self rangeGrownToWords:existing.range inText:text grows:NO separators:separators];
    if (!NSEqualRanges(grown, existing.range)) {
      [self addRange:[ENRMFormattingRange rangeWithType:existing.type range:grown]];
    }
  }
}

- (BOOL)isStyleActive:(ENRMInputStyleType)type atCaret:(NSUInteger)position inText:(NSString *)text
{
  if ([self isStyleActive:type atPosition:position]) {
    return YES;
  }
  if (type != ENRMInputStyleTypeUnderline || position > text.length || !ENRMIsWordBefore(text, position)) {
    return NO;
  }
  for (ENRMFormattingRange *existing in _ranges) {
    if (existing.type == ENRMInputStyleTypeUnderline && NSMaxRange(existing.range) == position) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)isToggleBlocked:(ENRMInputStyleType)type
             atPosition:(NSUInteger)position
         blockingStyles:(NSSet<NSNumber *> *)blockingStyles
{
  if (blockingStyles.count == 0) {
    return NO;
  }
  if ([self isStyleActive:type atPosition:position]) {
    return NO;
  }
  for (NSNumber *blocker in blockingStyles) {
    if ([self isStyleActive:(ENRMInputStyleType)blocker.integerValue atPosition:position]) {
      return YES;
    }
  }
  return NO;
}

- (void)addRange:(ENRMFormattingRange *)newRange
{
  NSMutableIndexSet *mergeIndexes = [NSMutableIndexSet indexSet];
  NSUInteger mergedStart = newRange.range.location;
  NSUInteger mergedEnd = NSMaxRange(newRange.range);

  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    ENRMFormattingRange *existing = _ranges[idx];
    if (existing.type != newRange.type)
      continue;

    NSUInteger existingEnd = NSMaxRange(existing.range);
    if (existing.range.location <= mergedEnd && existingEnd >= mergedStart) {
      mergedStart = MIN(mergedStart, existing.range.location);
      mergedEnd = MAX(mergedEnd, existingEnd);
      [mergeIndexes addIndex:idx];
    }
  }

  ENRMRemoveIndexesInReverse(_ranges, mergeIndexes);

  ENRMFormattingRange *merged = [ENRMFormattingRange rangeWithType:newRange.type
                                                             range:NSMakeRange(mergedStart, mergedEnd - mergedStart)
                                                               url:newRange.url];

  NSUInteger insertAt = ENRMSortedInsertionIndex(
      _ranges, merged.range.location, ^NSUInteger(id range) { return ((ENRMFormattingRange *)range).range.location; });
  [_ranges insertObject:merged atIndex:insertAt];
}

- (void)removeType:(ENRMInputStyleType)type inRange:(NSRange)removeRange
{
  NSMutableArray<ENRMFormattingRange *> *remainders = [NSMutableArray array];
  NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];

  NSUInteger removeStart = removeRange.location;
  NSUInteger removeEnd = NSMaxRange(removeRange);

  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    ENRMFormattingRange *existing = _ranges[idx];
    if (existing.type != type)
      continue;

    NSUInteger existingStart = existing.range.location;
    NSUInteger existingEnd = NSMaxRange(existing.range);

    if (existingEnd <= removeStart || existingStart >= removeEnd) {
      continue;
    }

    [indexesToRemove addIndex:idx];

    if (existingStart < removeStart) {
      [remainders addObject:[ENRMFormattingRange rangeWithType:type
                                                         range:NSMakeRange(existingStart, removeStart - existingStart)
                                                           url:existing.url]];
    }
    if (existingEnd > removeEnd) {
      [remainders addObject:[ENRMFormattingRange rangeWithType:type
                                                         range:NSMakeRange(removeEnd, existingEnd - removeEnd)
                                                           url:existing.url]];
    }
  }

  ENRMRemoveIndexesInReverse(_ranges, indexesToRemove);

  // Remainders are fragments of a just-removed range and cannot overlap others.
  for (ENRMFormattingRange *remainder in remainders) {
    NSUInteger insertAt = ENRMSortedInsertionIndex(_ranges, remainder.range.location, ^NSUInteger(id range) {
      return ((ENRMFormattingRange *)range).range.location;
    });
    [_ranges insertObject:remainder atIndex:insertAt];
  }
}

- (void)removeRange:(ENRMFormattingRange *)range
{
  [_ranges removeObject:range];
}

- (void)adjustForEditAtLocation:(NSUInteger)editLocation
                  deletedLength:(NSUInteger)deletedLength
                 insertedLength:(NSUInteger)insertedLength
{
  if (deletedLength == 0 && insertedLength == 0)
    return;

  NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];

  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    ENRMFormattingRange *formattingRange = _ranges[idx];
    BOOL inheritsReplacement = formattingRange.type != ENRMInputStyleTypeLink;
    ENRMAdjustedRange adjusted = ENRMAdjustRangeForEdit(formattingRange.range, editLocation, deletedLength,
                                                        insertedLength, inheritsReplacement, NO);
    formattingRange.range = adjusted.range;
    if (adjusted.shouldRemove) {
      [indexesToRemove addIndex:idx];
    }
  }

  ENRMRemoveIndexesInReverse(_ranges, indexesToRemove);

  NSMutableIndexSet *emptyIndexes = [NSMutableIndexSet indexSet];
  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    if (_ranges[idx].range.length == 0) {
      [emptyIndexes addIndex:idx];
    }
  }
  if (emptyIndexes.count > 0) {
    ENRMRemoveIndexesInReverse(_ranges, emptyIndexes);
  }

  [self coalesceAdjacentSameTypeRanges];
}

/// Merge same-type (and same-url) ranges left adjacent or overlapping by an
/// edit — e.g. deleting the space in "**foo** **bar**" leaves two touching
/// bold ranges that would serialize as "**foo****bar**". `addRange:` keeps
/// this invariant on insert; the edit path must too.
- (void)coalesceAdjacentSameTypeRanges
{
  for (NSUInteger idx = 0; idx < _ranges.count; idx++) {
    ENRMFormattingRange *current = _ranges[idx];
    NSUInteger next = idx + 1;
    while (next < _ranges.count && _ranges[next].range.location <= NSMaxRange(current.range)) {
      ENRMFormattingRange *candidate = _ranges[next];
      BOOL sameUrl = (current.url == candidate.url) || [current.url isEqualToString:candidate.url];
      if (candidate.type == current.type && sameUrl) {
        NSUInteger mergedEnd = MAX(NSMaxRange(current.range), NSMaxRange(candidate.range));
        current.range = NSMakeRange(current.range.location, mergedEnd - current.range.location);
        [_ranges removeObjectAtIndex:next];
      } else {
        next++;
      }
    }
  }
}

@end
