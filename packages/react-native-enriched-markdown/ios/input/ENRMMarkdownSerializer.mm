#import "ENRMMarkdownSerializer.h"

static NSString *openingDelimiterForType(ENRMInputStyleType type)
{
  switch (type) {
    case ENRMInputStyleTypeStrong:
      return @"**";
    case ENRMInputStyleTypeEmphasis:
      return @"*";
    case ENRMInputStyleTypeUnderline:
      return @"_";
    case ENRMInputStyleTypeStrikethrough:
      return @"~~";
    case ENRMInputStyleTypeLink:
      return @"[";
    case ENRMInputStyleTypeSpoiler:
      return @"||";
    default:
      return @"";
  }
}

static NSString *closingDelimiterForType(ENRMInputStyleType type, NSString *url)
{
  switch (type) {
    case ENRMInputStyleTypeStrong:
      return @"**";
    case ENRMInputStyleTypeEmphasis:
      return @"*";
    case ENRMInputStyleTypeUnderline:
      return @"_";
    case ENRMInputStyleTypeStrikethrough:
      return @"~~";
    case ENRMInputStyleTypeLink:
      return [NSString stringWithFormat:@"](%@)", url ?: @""];
    case ENRMInputStyleTypeSpoiler:
      return @"||";
    default:
      return @"";
  }
}

/// Lower value = outermost wrapper. Font styles wrap around structural styles (link).
static int nestingPriorityForType(ENRMInputStyleType type)
{
  switch (type) {
    case ENRMInputStyleTypeEmphasis:
      return 0;
    case ENRMInputStyleTypeStrong:
      return 1;
    case ENRMInputStyleTypeUnderline:
      return 2;
    case ENRMInputStyleTypeStrikethrough:
      return 3;
    case ENRMInputStyleTypeSpoiler:
      return 4;
    case ENRMInputStyleTypeLink:
      return 5;
    default:
      return 99;
  }
}

typedef struct {
  NSUInteger position;
  BOOL isOpening;
  ENRMInputStyleType type;
  NSString *__unsafe_unretained url;
  NSUInteger segment;
} BoundaryEvent;

static int compareBoundaryEvents(const void *first, const void *second)
{
  const BoundaryEvent *eventA = (const BoundaryEvent *)first;
  const BoundaryEvent *eventB = (const BoundaryEvent *)second;

  if (eventA->position != eventB->position) {
    return eventA->position < eventB->position ? -1 : 1;
  }
  // Closing events before opening events at the same position
  if (eventA->isOpening != eventB->isOpening) {
    return eventA->isOpening ? 1 : -1;
  }
  // Among openings: outer first (lower priority emitted first)
  // Among closings: inner first (higher priority emitted first) — LIFO order
  int priorityA = nestingPriorityForType(eventA->type);
  int priorityB = nestingPriorityForType(eventB->type);
  if (eventA->isOpening) {
    return priorityA - priorityB;
  } else {
    return priorityB - priorityA;
  }
}

static NSCharacterSet *whitespaceSet(void)
{
  static NSCharacterSet *set;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ set = [NSCharacterSet whitespaceAndNewlineCharacterSet]; });
  return set;
}

/// Split formatting ranges at paragraph breaks (\n\n) so each segment gets
/// its own delimiters — CommonMark delimiters can't span paragraphs.
/// NOTE: This only handles inline styles (bold, italic, etc.). Block-level
/// elements (lists, blockquotes, headings) are prefix-based and will need
/// a separate serialization path.
static NSArray<ENRMFormattingRange *> *splitRangesAtParagraphBreaks(NSArray<ENRMFormattingRange *> *ranges,
                                                                    NSString *text)
{
  NSMutableArray<ENRMFormattingRange *> *result = [NSMutableArray arrayWithCapacity:ranges.count];

  NSUInteger textLength = text.length;

  for (ENRMFormattingRange *formattingRange in ranges) {
    NSUInteger rangeStart = MIN(formattingRange.range.location, textLength);
    NSUInteger rangeEnd = MIN(NSMaxRange(formattingRange.range), textLength);

    NSUInteger segStart = rangeStart;
    while (segStart < rangeEnd) {
      NSUInteger segEnd = segStart;
      while (segEnd < rangeEnd) {
        if (segEnd + 1 < rangeEnd && [text characterAtIndex:segEnd] == '\n' &&
            [text characterAtIndex:segEnd + 1] == '\n') {
          break;
        }
        segEnd++;
      }

      if (segEnd > segStart) {
        [result addObject:[ENRMFormattingRange rangeWithType:formattingRange.type
                                                       range:NSMakeRange(segStart, segEnd - segStart)
                                                         url:formattingRange.url]];
      }

      segStart = (segEnd < rangeEnd && segEnd + 1 < rangeEnd && [text characterAtIndex:segEnd] == '\n' &&
                  [text characterAtIndex:segEnd + 1] == '\n')
                     ? segEnd + 2
                     : segEnd;
    }
  }

  return result;
}

typedef NS_ENUM(NSInteger, ENRMNeighbor) {
  ENRMNeighborWhitespace,
  ENRMNeighborPunctuation,
  ENRMNeighborWord,
};

// md4c's classes: CommonMark punctuation is Unicode P and S, so an emoji
// counts as punctuation next to "**".
static ENRMNeighbor classifyCharacters(NSString *characters)
{
  static NSCharacterSet *punctuation;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableCharacterSet *set = [NSMutableCharacterSet punctuationCharacterSet];
    [set formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
    punctuation = [set copy];
  });
  if ([characters rangeOfCharacterFromSet:whitespaceSet()].location != NSNotFound) {
    return ENRMNeighborWhitespace;
  }
  return [characters rangeOfCharacterFromSet:punctuation].location != NSNotFound ? ENRMNeighborPunctuation
                                                                                 : ENRMNeighborWord;
}

// "*" and "**" side by side are one delimiter run to md4c, flanked by what is
// around the whole run: "***a***b" is bold italic "a".
static BOOL isStarDelimiter(ENRMInputStyleType type)
{
  return type == ENRMInputStyleTypeStrong || type == ENRMInputStyleTypeEmphasis;
}

// A line's edge reads as whitespace (a block marker ends in a space), and another
// delimiter as punctuation, except a "*" next to a "*", which joins its run.
static ENRMNeighbor neighborBefore(NSString *text, const BoundaryEvent *events, NSUInteger index)
{
  NSUInteger position = events[index].position;
  BOOL star = isStarDelimiter(events[index].type);
  for (NSUInteger i = index; i > 0 && events[i - 1].position == position; i--) {
    if (!star || !isStarDelimiter(events[i - 1].type)) {
      return ENRMNeighborPunctuation;
    }
  }
  if (position == 0 || [text characterAtIndex:position - 1] == '\n') {
    return ENRMNeighborWhitespace;
  }
  return classifyCharacters([text substringWithRange:[text rangeOfComposedCharacterSequenceAtIndex:position - 1]]);
}

static ENRMNeighbor neighborAfter(NSString *text, const BoundaryEvent *events, NSUInteger count, NSUInteger index)
{
  NSUInteger position = events[index].position;
  BOOL star = isStarDelimiter(events[index].type);
  for (NSUInteger i = index + 1; i < count && events[i].position == position; i++) {
    if (!star || !isStarDelimiter(events[i].type)) {
      return ENRMNeighborPunctuation;
    }
  }
  if (position == text.length || [text characterAtIndex:position] == '\n') {
    return ENRMNeighborWhitespace;
  }
  return classifyCharacters([text substringWithRange:[text rangeOfComposedCharacterSequenceAtIndex:position]]);
}

// Measured against md4c, since "_" (underline) and "~~" are extensions:
// "*"/"**" follow CommonMark flanking; "_"/"~~" don't work inside a word.
static BOOL isFlanking(ENRMInputStyleType type, BOOL isOpening, ENRMNeighbor before, ENRMNeighbor after)
{
  ENRMNeighbor inner = isOpening ? after : before;
  ENRMNeighbor outer = isOpening ? before : after;
  switch (type) {
    case ENRMInputStyleTypeStrong:
    case ENRMInputStyleTypeEmphasis:
      return inner != ENRMNeighborWhitespace && (inner != ENRMNeighborPunctuation || outer != ENRMNeighborWord);
    case ENRMInputStyleTypeUnderline:
    case ENRMInputStyleTypeStrikethrough:
      return inner != ENRMNeighborWhitespace && outer != ENRMNeighborWord;
    default:
      return YES;
  }
}

static NSUInteger collectBoundaryEvents(NSString *text, NSArray<ENRMFormattingRange *> *segments, const BOOL *dropped,
                                        BoundaryEvent *events)
{
  NSCharacterSet *ws = whitespaceSet();
  NSUInteger textLength = text.length;
  NSUInteger eventIndex = 0;
  for (NSUInteger segment = 0; segment < segments.count; segment++) {
    if (dropped[segment]) {
      continue;
    }
    ENRMFormattingRange *formattingRange = segments[segment];
    NSUInteger start = MIN(formattingRange.range.location, textLength);
    NSUInteger end = MIN(NSMaxRange(formattingRange.range), textLength);

    while (start < end && [ws characterIsMember:[text characterAtIndex:start]]) {
      start++;
    }
    while (end > start && [ws characterIsMember:[text characterAtIndex:end - 1]]) {
      end--;
    }

    if (start >= end) {
      continue;
    }

    events[eventIndex++] = (BoundaryEvent){
        .position = start,
        .isOpening = YES,
        .type = formattingRange.type,
        .url = formattingRange.url,
        .segment = segment,
    };
    events[eventIndex++] = (BoundaryEvent){
        .position = end,
        .isOpening = NO,
        .type = formattingRange.type,
        .url = formattingRange.url,
        .segment = segment,
    };
  }

  qsort(events, eventIndex, sizeof(BoundaryEvent), compareBoundaryEvents);
  return eventIndex;
}

static BOOL dropUnflankedSegments(NSString *text, const BoundaryEvent *events, NSUInteger count, BOOL *dropped)
{
  BOOL droppedAny = NO;
  for (NSUInteger i = 0; i < count; i++) {
    if (!isFlanking(events[i].type, events[i].isOpening, neighborBefore(text, events, i),
                    neighborAfter(text, events, count, i))) {
      dropped[events[i].segment] = YES;
      droppedAny = YES;
    }
  }
  return droppedAny;
}

static NSString *writeMarkdown(NSString *text, const BoundaryEvent *events, NSUInteger count)
{
  NSUInteger textLength = text.length;
  NSMutableString *markdown = [NSMutableString stringWithCapacity:textLength + count * 4];
  NSUInteger lastPosition = 0;

  for (NSUInteger currentEvent = 0; currentEvent < count; currentEvent++) {
    BoundaryEvent event = events[currentEvent];
    NSUInteger position = MIN(event.position, textLength);

    if (position > lastPosition) {
      [markdown appendString:[text substringWithRange:NSMakeRange(lastPosition, position - lastPosition)]];
      lastPosition = position;
    }

    if (event.isOpening) {
      [markdown appendString:openingDelimiterForType(event.type)];
    } else {
      [markdown appendString:closingDelimiterForType(event.type, event.url)];
    }
  }

  if (lastPosition < textLength) {
    [markdown appendString:[text substringFromIndex:lastPosition]];
  }
  return markdown;
}

@implementation ENRMMarkdownSerializer

// A range md4c would not read back (underline over half a word) is dropped: losing
// a style beats writing its delimiters into the text, where every reload keeps them.
+ (NSString *)serializePlainText:(NSString *)text ranges:(NSArray<ENRMFormattingRange *> *)ranges
{
  if (ranges.count == 0) {
    return text;
  }

  NSArray<ENRMFormattingRange *> *segments = splitRangesAtParagraphBreaks(ranges, text);

  BoundaryEvent *events = (BoundaryEvent *)malloc(sizeof(BoundaryEvent) * segments.count * 2);
  BOOL *dropped = (BOOL *)calloc(segments.count, sizeof(BOOL));
  if (!events || !dropped) {
    free(events);
    free(dropped);
    return text;
  }

  NSUInteger count;
  do {
    count = collectBoundaryEvents(text, segments, dropped, events);
  } while (dropUnflankedSegments(text, events, count, dropped));

  NSString *markdown = writeMarkdown(text, events, count);
  free(events);
  free(dropped);
  return markdown;
}

+ (NSString *)serializePlainText:(NSString *)text
                          ranges:(NSArray<ENRMFormattingRange *> *)ranges
                     blockRanges:(NSArray<ENRMBlockRange *> *)blockRanges
             blockPrefixProvider:(NSString *_Nullable (^_Nullable)(ENRMBlockRange *blockRange))prefixProvider
{
  NSString *inlineMarkdown = [self serializePlainText:text ranges:ranges];

  if (blockRanges.count == 0 || prefixProvider == nil) {
    return inlineMarkdown;
  }

  // Block prefixes attach per line. Inline serialization only inserts inline
  // delimiters (never newlines), so the serialized output has the same line
  // count as the plain text — we map a block's plain-text range to line indices
  // and prefix the corresponding serialized lines.
  NSArray<NSString *> *plainLines = [text componentsSeparatedByString:@"\n"];
  NSMutableArray<NSString *> *markdownLines = [[inlineMarkdown componentsSeparatedByString:@"\n"] mutableCopy];

  // Inline delimiters never cross a newline, so the line partition is preserved.
  // If this ever breaks, prefixes would land on the wrong lines. Contract on
  // both platforms: assert in debug, log and fall back to inline-only output in
  // release — a library must not crash the host app over lost block prefixes.
  NSCAssert(plainLines.count == markdownLines.count,
            @"Block serialization line-count invariant violated: plain=%lu markdown=%lu",
            (unsigned long)plainLines.count, (unsigned long)markdownLines.count);
  if (plainLines.count != markdownLines.count) {
    NSLog(@"[EnrichedMarkdown] Block serialization line-count invariant violated: plain=%lu markdown=%lu",
          (unsigned long)plainLines.count, (unsigned long)markdownLines.count);
    return inlineMarkdown;
  }

  NSMutableArray<NSNumber *> *lineStartOffsets = [NSMutableArray arrayWithCapacity:plainLines.count];
  NSUInteger runningOffset = 0;
  for (NSString *line in plainLines) {
    [lineStartOffsets addObject:@(runningOffset)];
    runningOffset += line.length + 1; // +1 for the '\n' separator
  }

  for (ENRMBlockRange *blockRange in blockRanges) {
    NSString *prefix = prefixProvider(blockRange);
    if (prefix.length == 0) {
      continue;
    }

    NSUInteger blockStart = blockRange.range.location;
    NSUInteger blockEnd = NSMaxRange(blockRange.range);
    BOOL isZeroLength = blockRange.range.length == 0;
    BOOL isListItem = ENRMBlockTypeIsListItem(blockRange.type);

    for (NSUInteger lineIndex = 0; lineIndex < plainLines.count; lineIndex++) {
      NSUInteger lineStart = lineStartOffsets[lineIndex].unsignedIntegerValue;
      NSUInteger lineEnd = lineStart + plainLines[lineIndex].length;
      BOOL overlaps = isZeroLength ? (lineStart == blockStart) : (lineEnd >= blockStart && lineStart < blockEnd);
      if (overlaps) {
        // A marker-only list line ("- " with no content) re-parses as a setext
        // underline for the previous line; emit an empty list line bare. An
        // empty "# " heading is valid ATX and keeps its prefix.
        if (isListItem && plainLines[lineIndex].length == 0) {
          continue;
        }
        markdownLines[lineIndex] = [prefix stringByAppendingString:markdownLines[lineIndex]];
      }
    }
  }

  return [markdownLines componentsJoinedByString:@"\n"];
}

@end
