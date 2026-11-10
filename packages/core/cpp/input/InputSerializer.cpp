#include "InputInternal.hpp"
#include "InputUnicode.hpp"
#include <algorithm>
#include <array>
#include <climits>
#include <cstddef>
#include <string>

// MarkdownSerializer.ts: plain text, formatting ranges and block ranges to
// markdown. Ranges may overlap any way they like, but delimiters have to nest,
// so the writer keeps a stack of open segments and drops what md4c would not
// read back.
namespace Markdown::Input {

namespace {

constexpr size_t kNone = static_cast<size_t>(-1);

const char16_t *openingDelimiter(StyleType type) {
  switch (type) {
    case StyleType::Strong:
      return u"**";
    case StyleType::Em:
      return u"*";
    case StyleType::Underline:
      return u"_";
    case StyleType::Strikethrough:
      return u"~~";
    case StyleType::Link:
      return u"[";
    case StyleType::Spoiler:
      return u"||";
  }
  return u"";
}

bool hasBalancedParens(std::u16string_view url) {
  int depth = 0;
  for (char16_t c : url) {
    if (c == u'(') {
      depth++;
    } else if (c == u')' && --depth < 0) {
      return false;
    }
  }
  return depth == 0;
}

// A bare destination ends at the first whitespace and at an unbalanced ")", so a
// url carrying either goes in angle brackets, where "<" and ">" need escaping as
// well. Backslash escapes are resolved in both forms, so a literal "\" has to be
// doubled before anything else is escaped - left bare, a url ending in one would
// escape the closing delimiter and swallow the rest of the line. No form admits
// a line ending at all, and one reaching the output would also break the
// line-count invariant `serialize` relies on, so line endings are
// percent-encoded rather than passed through.
std::u16string linkDestination(std::u16string_view url) {
  std::u16string escaped;
  escaped.reserve(url.size());
  bool hasWhitespace = false;
  for (char16_t c : url) {
    switch (c) {
      case u'\\':
        escaped += u"\\\\";
        break;
      case u'\r':
        escaped += u"%0D";
        break;
      case u'\n':
        escaped += u"%0A";
        break;
      default:
        hasWhitespace = hasWhitespace || isJsWhitespace(c);
        escaped.push_back(c);
    }
  }
  if (!hasWhitespace && hasBalancedParens(escaped)) {
    return escaped;
  }
  std::u16string wrapped = u"<";
  for (char16_t c : escaped) {
    if (c == u'<' || c == u'>') {
      wrapped.push_back(u'\\');
    }
    wrapped.push_back(c);
  }
  wrapped.push_back(u'>');
  return wrapped;
}

// Among styles covering exactly the same text, lower is outermost. A link or
// spoiler goes outside font styles: "[**docs**](u)s" parses, while
// "**[docs](u)**s" does not - a closing "**" after ")" and before a letter is
// not right-flanking.
int nestingPriority(StyleType type) {
  switch (type) {
    case StyleType::Link:
      return 0;
    case StyleType::Spoiler:
      return 1;
    case StyleType::Em:
      return 2;
    case StyleType::Strong:
      return 3;
    case StyleType::Underline:
      return 4;
    case StyleType::Strikethrough:
      return 5;
  }
  return 6;
}

// The part of a range on one line, trimmed so its delimiters hug non-whitespace:
// an opening "**" before a space or a closing one after it is not flanking, and
// the parser would leave it as text.
struct Segment {
  StyleType type;
  const std::u16string *url;
  size_t start;
  size_t end;
};

// One end of a segment, with the delimiter written there.
struct Event {
  size_t position;
  bool isOpening;
  StyleType type;
  const std::u16string *url;
  size_t segment; // index into the segment list
};

// Of two delimiters opening at one position, the one written first is the outer
// one, so it has to be the one that closes last.
bool opensOutside(const Segment &a, const Segment &b) {
  if (a.end != b.end) {
    return a.end > b.end;
  }
  return nestingPriority(a.type) < nestingPriority(b.type);
}

// Whitespace as `\s` matches it, a unit at a time.
bool isWhitespaceAt(std::u16string_view text, size_t index) {
  return index < text.size() && isJsWhitespace(text[index]);
}

// Leftmost line containing `position`.
size_t lineAt(const std::vector<size_t> &lineStarts, size_t position) {
  size_t low = 0;
  size_t high = lineStarts.size();
  while (low < high) {
    const size_t mid = low + (high - low) / 2;
    const size_t nextStart = mid + 1 < lineStarts.size() ? lineStarts[mid + 1] : kNone;
    if (nextStart < position + 1) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

// Every line is its own block, and no inline run may cross a block boundary:
// "- **a\n- b**" re-parses as two items carrying literal asterisks rather than
// one bold run. Each range is therefore emitted once per line it covers, which
// also splits a link spanning lines into one link per line - the only form the
// block model can express. Sorted by start.
std::vector<Segment> lineSegments(std::u16string_view text, const std::vector<FormattingRange> &ranges,
                                  const std::vector<size_t> &lineStarts) {
  const auto lineEnd = [&](size_t line) { return lineEndOf(text, lineStarts, line); };
  std::vector<Segment> segments;
  bool sorted = true;
  // The line of the last range's start. Ranges come sorted by start, so this
  // walks forward through the lines once; only a range starting behind it is
  // looked up.
  size_t cursor = 0;
  for (const FormattingRange &range : ranges) {
    const size_t rangeEnd = std::min<size_t>(range.end, text.size());
    size_t start = std::min<size_t>(range.start, text.size());
    if (start >= rangeEnd) {
      continue;
    }
    if (start < lineStarts[cursor]) {
      cursor = lineAt(lineStarts, start);
    }
    while (lineEnd(cursor) < start) {
      cursor++;
    }
    for (size_t line = cursor; start < rangeEnd; line++) {
      const size_t end = std::min(lineEnd(line), rangeEnd);
      size_t from = start;
      size_t to = end;
      while (from < to && isWhitespaceAt(text, from)) {
        from++;
      }
      while (to > from && isWhitespaceAt(text, to - 1)) {
        to--;
      }
      if (from < to) {
        sorted = sorted && (segments.empty() || segments.back().start <= from);
        segments.push_back({range.type, &range.url, from, to});
      }
      start = end + 1;
    }
  }
  if (!sorted) {
    // Only a range spanning lines puts a later line's segment ahead of the next
    // range's.
    std::stable_sort(segments.begin(), segments.end(),
                     [](const Segment &a, const Segment &b) { return a.start < b.start; });
  }
  return segments;
}

// The delimiters to write, in output order. Where one segment ends, everything
// opened inside it closes too, and the ones that go on past it reopen right
// after - at the next non-whitespace character, since a delimiter before a space
// does not open. Where several open at once, the one closing last opens first.
std::vector<Event> nestedEvents(std::u16string_view text, const std::vector<Segment> &segments) {
  std::vector<Event> events;
  events.reserve(segments.size() * 2);
  std::vector<size_t> stack;
  std::vector<size_t> opening;
  size_t next = 0;
  while (next < segments.size() || !stack.empty()) {
    size_t position = next < segments.size() ? segments[next].start : kNone;
    size_t deepest = kNone;
    for (size_t i = 0; i < stack.size(); i++) {
      const size_t end = segments[stack[i]].end;
      if (end < position) {
        position = end;
        deepest = i;
      } else if (end == position && deepest == kNone) {
        deepest = i;
      }
    }

    if (deepest != kNone) {
      while (stack.size() > deepest) {
        const size_t index = stack.back();
        stack.pop_back();
        const Segment &segment = segments[index];
        events.push_back({position, false, segment.type, segment.url, index});
        if (segment.end > position) {
          opening.push_back(index);
        }
      }
    }
    while (next < segments.size() && segments[next].start == position) {
      opening.push_back(next++);
    }
    if (opening.empty()) {
      continue;
    }

    // A segment opening here starts on non-whitespace, so this only moves
    // reopened ones, and nothing ends or starts in the whitespace skipped.
    size_t openAt = position;
    while (isWhitespaceAt(text, openAt)) {
      openAt++;
    }
    std::stable_sort(opening.begin(), opening.end(),
                     [&](size_t a, size_t b) { return opensOutside(segments[a], segments[b]); });
    for (size_t index : opening) {
      stack.push_back(index);
      const Segment &segment = segments[index];
      events.push_back({openAt, true, segment.type, segment.url, index});
    }
    opening.clear();
  }
  return events;
}

// "*" and "**" written side by side are one delimiter run to md4c, and a run's
// flanking is decided by what is around the whole run, not by the "*" next to
// each part: "***a***b" is bold italic "a". Any other delimiter in between ends
// the run and is punctuation.
bool isStarDelimiter(StyleType type) {
  return type == StyleType::Em || type == StyleType::Strong;
}

Neighbor neighborBefore(std::u16string_view text, const std::vector<Event> &events, size_t index) {
  const size_t position = events[index].position;
  const bool star = isStarDelimiter(events[index].type);
  for (size_t i = index; i-- > 0 && events[i].position == position;) {
    if (!star || !isStarDelimiter(events[i].type)) {
      return Neighbor::Punctuation;
    }
  }
  if (position == 0 || text[position - 1] == u'\n') {
    return Neighbor::Whitespace;
  }
  // The whole code point, so an emoji is classified as one.
  const bool pairTail = isLowSurrogate(text[position - 1]) && position >= 2;
  const size_t from = pairTail ? position - 2 : position - 1;
  return classify(text.substr(from, position - from));
}

Neighbor neighborAfter(std::u16string_view text, const std::vector<Event> &events, size_t index) {
  const size_t position = events[index].position;
  const bool star = isStarDelimiter(events[index].type);
  for (size_t i = index + 1; i < events.size() && events[i].position == position; i++) {
    if (!star || !isStarDelimiter(events[i].type)) {
      return Neighbor::Punctuation;
    }
  }
  if (position >= text.size() || text[position] == u'\n') {
    return Neighbor::Whitespace;
  }
  const bool pair = isHighSurrogate(text[position]) && position + 1 < text.size() && isLowSurrogate(text[position + 1]);
  return classify(text.substr(position, pair ? 2 : 1));
}

// Whether md4c reads a delimiter between `before` and `after` as the opening (or
// the closing) it stands for. Measured against the parser rather than taken from
// the spec, because "_" (underline here) and "~~" are extensions:
// - "*" / "**": CommonMark flanking. An opener is left-flanking - not before
//   whitespace, and not before punctuation unless whitespace or punctuation
//   precedes it - and a closer the mirror image.
// - "_" / "~~": an opener must not follow a letter or digit, nor a closer
//   precede one: neither works inside a word.
// - "||" and links take any neighbors.
bool isFlanking(StyleType type, bool isOpening, Neighbor before, Neighbor after) {
  const Neighbor inner = isOpening ? after : before;
  const Neighbor outer = isOpening ? before : after;
  switch (type) {
    case StyleType::Em:
    case StyleType::Strong:
      return inner != Neighbor::Whitespace && (inner != Neighbor::Punctuation || outer != Neighbor::Word);
    case StyleType::Underline:
    case StyleType::Strikethrough:
      return inner != Neighbor::Whitespace && outer != Neighbor::Word;
    case StyleType::Spoiler:
    case StyleType::Link:
      return true;
  }
  return true;
}

// The segments whose delimiters md4c would not read as one, by segment index.
std::vector<char> unflankedSegments(std::u16string_view text, const std::vector<Event> &events, size_t segmentCount,
                                    bool &any) {
  std::vector<char> unflanked(segmentCount, 0);
  any = false;
  for (size_t i = 0; i < events.size(); i++) {
    const Event &event = events[i];
    if (event.type != StyleType::Link && event.type != StyleType::Spoiler &&
        !isFlanking(event.type, event.isOpening, neighborBefore(text, events, i), neighborAfter(text, events, i))) {
      unflanked[event.segment] = 1;
      any = true;
    }
  }
  return unflanked;
}

// A segment whose delimiters md4c would not read as one - "**Note:**text",
// underline over half a word - is dropped, and the rest written again without
// it: losing a style beats writing its delimiters into the text, where every
// reload would keep them.
std::vector<Event> inlineEvents(std::u16string_view text, const std::vector<FormattingRange> &ranges,
                                const std::vector<size_t> &lineStarts, std::vector<Segment> &segments) {
  segments = lineSegments(text, ranges, lineStarts);
  while (true) {
    std::vector<Event> events = nestedEvents(text, segments);
    bool any = false;
    const std::vector<char> unreadable = unflankedSegments(text, events, segments.size(), any);
    if (!any) {
      return events;
    }
    std::vector<Segment> kept;
    kept.reserve(segments.size());
    for (size_t i = 0; i < segments.size(); i++) {
      if (!unreadable[i]) {
        kept.push_back(segments[i]);
      }
    }
    segments = std::move(kept);
  }
}

// A "!" written right before a link's "[" turns the link into an image, which
// re-imports as its bare text with the "!" and the url gone. Unlike the other
// escapes this depends on the delimiters, so it is decided here: the "!" ahead of
// a link opening is escaped unless another delimiter is written between them
// ("!**[a](u)**" is no image). Merged into `escapes`, which stays sorted.
std::vector<uint32_t> withImageMarkerEscapes(std::vector<uint32_t> escapes, std::u16string_view text,
                                             const std::vector<Event> &events) {
  std::vector<uint32_t> markers;
  for (size_t i = 0; i < events.size(); i++) {
    const Event &event = events[i];
    if (event.isOpening && event.type == StyleType::Link && event.position >= 1 && event.position - 1 < text.size() &&
        text[event.position - 1] == u'!' && (i == 0 || events[i - 1].position != event.position)) {
      markers.push_back(static_cast<uint32_t>(event.position - 1));
    }
  }
  if (markers.empty()) {
    return escapes;
  }
  std::vector<uint32_t> merged;
  merged.reserve(escapes.size() + markers.size());
  size_t m = 0;
  for (uint32_t at : escapes) {
    for (; m < markers.size() && markers[m] < at; m++) {
      merged.push_back(markers[m]);
    }
    merged.push_back(at);
  }
  for (; m < markers.size(); m++) {
    merged.push_back(markers[m]);
  }
  return merged;
}

// `linePrefixes` is indexed like `lineStarts`, and a line with an empty entry
// gets no marker. A marker lands in front of its line's first character, and so
// in front of any delimiter opening there; no delimiter closes at a line start,
// because a range is split into one segment per line and each segment ends on
// its own line.
std::u16string writeMarkdown(std::u16string_view text, const std::vector<Event> &events,
                             const std::vector<size_t> &lineStarts, const std::vector<std::u16string> &linePrefixes) {
  std::u16string markdown;
  markdown.reserve(text.size() + text.size() / 8 + 16);
  size_t written = 0;
  size_t nextLine = 0;
  const std::vector<uint32_t> escapes = withImageMarkerEscapes(markdownEscapePositions(text), text, events);
  size_t nextEscape = 0;
  const auto copyText = [&](size_t end) {
    for (; nextEscape < escapes.size() && escapes[nextEscape] < end; nextEscape++) {
      const size_t at = escapes[nextEscape];
      markdown.append(text.substr(written, at - written));
      markdown.push_back(u'\\');
      written = at;
    }
    if (end > written) {
      markdown.append(text.substr(written, end - written));
      written = end;
    }
  };
  const auto copyTo = [&](size_t position) {
    for (; nextLine < lineStarts.size() && lineStarts[nextLine] <= position; nextLine++) {
      if (nextLine < linePrefixes.size() && !linePrefixes[nextLine].empty()) {
        copyText(lineStarts[nextLine]);
        markdown.append(linePrefixes[nextLine]);
      }
    }
    copyText(position);
  };

  for (const Event &event : events) {
    copyTo(event.position);
    if (event.isOpening) {
      markdown.append(openingDelimiter(event.type));
    } else if (event.type == StyleType::Link) {
      markdown.append(u"](");
      markdown.append(linkDestination(*event.url));
      markdown.push_back(u')');
    } else {
      markdown.append(openingDelimiter(event.type));
    }
  }
  copyTo(text.size());
  return markdown;
}

std::u16string serializeEvents(std::u16string_view text, const std::vector<FormattingRange> &ranges,
                               const std::vector<size_t> &lineStarts, const std::vector<std::u16string> &linePrefixes) {
  std::vector<Segment> segments;
  const std::vector<Event> events =
      ranges.empty() ? std::vector<Event>() : inlineEvents(text, ranges, lineStarts, segments);
  return writeMarkdown(text, events, lineStarts, linePrefixes);
}

bool isListItem(BlockType type) {
  return type == BlockType::UnorderedListItem || type == BlockType::OrderedListItem;
}

// Width of "- " or "1. ", the narrowest markers a list item can carry.
constexpr int kSingleDigitMarkerWidth = 3;

// A nested item has to be indented to its parent's content column or it de-nests
// on re-parse, and that column is the parent's rendered marker width: "1. " and
// "10. " do not indent their children alike. Depth is clamped the way the block
// store clamps it, so a stray level cannot indent a line far enough to re-parse
// as a code block.
std::u16string listIndent(uint8_t level, int parentContentColumn) {
  const int depth = std::min<int>(level, kMaxListDepth);
  if (depth == 0) {
    return {};
  }
  return std::u16string(
      static_cast<size_t>(parentContentColumn >= 0 ? parentContentColumn : kSingleDigitMarkerWidth * depth), u' ');
}

} // namespace

std::u16string markdownLinePrefix(const BlockRange &block, int parentContentColumn) {
  switch (block.type) {
    case BlockType::Paragraph:
      return {};
    case BlockType::UnorderedListItem:
      return listIndent(block.level, parentContentColumn) + u"- ";
    case BlockType::OrderedListItem: {
      std::u16string prefix = listIndent(block.level, parentContentColumn);
      for (char c : std::to_string(block.ordinal)) {
        prefix.push_back(static_cast<char16_t>(c));
      }
      return prefix + u". ";
    }
    case BlockType::H1:
    case BlockType::H2:
    case BlockType::H3:
    case BlockType::H4:
    case BlockType::H5:
    case BlockType::H6:
      // A heading's level comes from its type rather than from `level`, so the
      // two cannot disagree.
      return std::u16string(static_cast<size_t>(block.type) - static_cast<size_t>(BlockType::H1) + 1, u'#') + u" ";
  }
  return {};
}

std::u16string serializeInline(std::u16string_view text, const std::vector<FormattingRange> &ranges) {
  return serializeEvents(text, ranges, ranges.empty() ? std::vector<size_t>() : lineStartsOf(text), {});
}

// Markers are written during the same sweep as the delimiters, so the output is
// never split back into lines. That relies on delimiters never carrying a line
// ending, which is why link destinations percent-encode theirs.
std::u16string serialize(std::u16string_view plainText, const std::vector<FormattingRange> &formattingRanges,
                         const std::vector<BlockRange> &blockRanges) {
  try {
    if (blockRanges.empty()) {
      return serializeInline(plainText, formattingRanges);
    }

    const std::u16string_view text = plainText;
    const std::vector<size_t> lineStarts = lineStartsOf(text);
    const size_t lineCount = lineStarts.size();
    const auto lineEnd = [&](size_t line) { return lineEndOf(text, lineStarts, line); };
    std::vector<std::u16string> linePrefixes(lineCount);
    // Per line: the depth of its list item, or INT_MAX for a heading; -1 on a
    // paragraph line. Blocks come in line order, so the previous line's entry is
    // in place by the time a line reads it.
    std::vector<int> lineDepths(lineCount, -1);
    // md4c reads a marker-only line as an empty item unless the line right above
    // holds paragraph text it would continue: "a\n-" is a setext underline, "a\n1."
    // paragraph text, and "- a\n  -" an underline inside the item. An empty line, a
    // heading, or an item at least as deep ends that text first.
    const auto startsEmptyItem = [&](size_t line, int depth) {
      return line == 0 || lineEnd(line - 1) == lineStarts[line - 1] || lineDepths[line - 1] >= depth;
    };

    // Content column of the last list item seen at each depth, so a nested item
    // can indent to its parent's marker width. -1 where none has been seen.
    std::array<int, kMaxListDepth + 1> listContentColumns;
    listContentColumns.fill(-1);
    // First line of the last block given a marker.
    size_t cursor = 0;

    for (const BlockRange &block : blockRanges) {
      const bool item = isListItem(block.type);
      const int depth = item ? std::min<int>(block.level, kMaxListDepth) : 0;
      const std::u16string prefix = markdownLinePrefix(block, depth == 0 ? 0 : listContentColumns[depth - 1]);
      if (item) {
        listContentColumns[depth] = static_cast<int>(prefix.size());
      }
      if (prefix.empty()) {
        continue;
      }

      const bool isZeroLength = block.end == block.start;
      // Line ends rise strictly, so the first line reaching the block's start is
      // the block's own first line; its remaining lines follow it. A block
      // starting behind the cursor (callers other than the store need not sort)
      // is looked up instead.
      if (cursor > 0 && lineEnd(cursor - 1) >= block.start) {
        size_t low = 0;
        size_t high = lineCount;
        while (low < high) {
          const size_t mid = low + (high - low) / 2;
          if (lineEnd(mid) < block.start) {
            low = mid + 1;
          } else {
            high = mid;
          }
        }
        cursor = low;
      }
      while (cursor < lineCount && lineEnd(cursor) < block.start) {
        cursor++;
      }
      for (size_t line = cursor; line < lineCount; line++) {
        const size_t lineStart = lineStarts[line];
        const bool overlaps = isZeroLength ? lineStart == block.start : lineStart < block.end;
        if (!overlaps) {
          break;
        }
        lineDepths[line] = item ? depth : INT_MAX;
        // An empty item md4c would not read back as one is left bare. An empty
        // "# " heading is valid ATX and keeps its prefix.
        if (item && lineEnd(line) == lineStart && !startsEmptyItem(line, depth)) {
          continue;
        }
        linePrefixes[line] = prefix + linePrefixes[line];
      }
    }

    return serializeEvents(text, formattingRanges, lineStarts, linePrefixes);
  } catch (...) {
    return std::u16string(plainText);
  }
}

} // namespace Markdown::Input
