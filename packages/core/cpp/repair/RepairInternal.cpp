// Counterpart of the reference's utils.ts and code-block-utils.ts.
// Attribution is in MarkdownRepair.hpp.
#include "RepairInternal.hpp"

#include <algorithm>

#include "UnicodeTables.hpp"

namespace Markdown::RepairInternal {

// --- UTF-8 -----------------------------------------------------------------

namespace {
constexpr uint32_t kReplacementChar = 0xFFFD; // what malformed UTF-8 decodes to
}

Decoded decodeAt(std::string_view text, size_t i) {
  const auto lead = static_cast<unsigned char>(text[i]);
  if (lead < 0x80) {
    return {lead, 1};
  }
  size_t length = 0;
  uint32_t codePoint = 0;
  if ((lead & 0xE0) == 0xC0) {
    length = 2;
    codePoint = lead & 0x1F;
  } else if ((lead & 0xF0) == 0xE0) {
    length = 3;
    codePoint = lead & 0x0F;
  } else if ((lead & 0xF8) == 0xF0) {
    length = 4;
    codePoint = lead & 0x07;
  } else {
    return {kReplacementChar, 1}; // stray continuation or invalid lead byte
  }
  if (i + length > text.size()) {
    return {kReplacementChar, 1};
  }
  for (size_t k = 1; k < length; ++k) {
    const auto c = static_cast<unsigned char>(text[i + k]);
    if ((c & 0xC0) != 0x80) {
      return {kReplacementChar, 1};
    }
    codePoint = (codePoint << 6) | (c & 0x3F);
  }
  return {codePoint, length};
}

uint32_t codePointAt(std::string_view text, size_t i) {
  return i < text.size() ? decodeAt(text, i).codePoint : kNoCodePoint;
}

size_t codePointStartBefore(std::string_view text, size_t i) {
  size_t j = i - 1;
  size_t steps = 0;
  while (j > 0 && steps < 3 && (static_cast<unsigned char>(text[j]) & 0xC0) == 0x80) {
    --j;
    ++steps;
  }
  return j;
}

uint32_t codePointBefore(std::string_view text, size_t i) {
  if (i == 0) {
    return kNoCodePoint;
  }
  const size_t start = codePointStartBefore(text, i);
  const Decoded d = decodeAt(text, start);
  return start + d.length == i ? d.codePoint : kReplacementChar;
}

// --- JS character classes --------------------------------------------------

bool isWordCharUnit(uint32_t codePoint) {
  return codePoint <= 0xFFFF && isWordChar(codePoint);
}

bool isJsWhitespace(uint32_t codePoint) {
  switch (codePoint) {
    case 0x09:
    case 0x0A:
    case 0x0B:
    case 0x0C:
    case 0x0D:
    case 0x20:
    case 0xA0:
    case 0x1680:
    case 0x2028:
    case 0x2029:
    case 0x202F:
    case 0x205F:
    case 0x3000:
    case 0xFEFF:
      return true;
    default:
      return codePoint >= 0x2000 && codePoint <= 0x200A;
  }
}

bool isSpaceTabNewline(uint32_t codePoint) {
  return codePoint == ' ' || codePoint == '\t' || codePoint == '\n';
}

bool isAsciiDigit(char c) {
  return c >= '0' && c <= '9';
}

bool isAsciiLetterOrSlash(char c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '/';
}

std::string_view jsTrimStart(std::string_view text) {
  size_t i = 0;
  while (i < text.size()) {
    const Decoded d = decodeAt(text, i);
    if (!isJsWhitespace(d.codePoint)) {
      break;
    }
    i += d.length;
  }
  return text.substr(i);
}

std::string_view jsTrimEnd(std::string_view text) {
  size_t end = text.size();
  while (end > 0 && isJsWhitespace(codePointBefore(text, end))) {
    end = codePointStartBefore(text, end);
  }
  return text.substr(0, end);
}

std::string_view jsTrim(std::string_view text) {
  return jsTrimEnd(jsTrimStart(text));
}

bool isWhitespaceOrMarkersOnly(std::string_view text) {
  size_t i = 0;
  while (i < text.size()) {
    const auto [codePoint, length] = decodeAt(text, i);
    if (!(isJsWhitespace(codePoint) || codePoint == '_' || codePoint == '~' || codePoint == '*' || codePoint == '`')) {
      return false;
    }
    i += length;
  }
  return true;
}

bool isListItemMarkerLine(std::string_view line) {
  std::string_view rest = jsTrimStart(line);
  if (rest.empty() || (rest[0] != '-' && rest[0] != '*' && rest[0] != '+')) {
    return false;
  }
  rest.remove_prefix(1);
  return !rest.empty() && jsTrimStart(rest).empty();
}

// --- Plain string helpers --------------------------------------------------

bool startsWith(std::string_view text, std::string_view prefix) {
  return text.size() >= prefix.size() && text.substr(0, prefix.size()) == prefix;
}

bool endsWith(std::string_view text, std::string_view suffix) {
  return text.size() >= suffix.size() && text.substr(text.size() - suffix.size()) == suffix;
}

bool isEscaped(std::string_view text, size_t i) {
  size_t backslashes = 0;
  while (i > backslashes && text[i - backslashes - 1] == '\\') {
    ++backslashes;
  }
  return backslashes % 2 == 1;
}

bool isTripleAt(std::string_view text, size_t i) {
  return i + 3 <= text.size() && text[i] == '`' && text[i + 1] == '`' && text[i + 2] == '`';
}

namespace {
size_t fenceRunAt(std::string_view text, size_t i) {
  const char c = text[i];
  if (c != '`' && c != '~') {
    return 0;
  }
  size_t end = i + 1;
  while (end < text.size() && text[end] == c) {
    ++end;
  }
  if (end - i < 3) {
    return 0;
  }
  if (c == '~') {
    size_t lineStart = i;
    while (lineStart > 0 && (text[lineStart - 1] == ' ' || text[lineStart - 1] == '\t' || text[lineStart - 1] == '>')) {
      --lineStart; // indentation and blockquote markers
    }
    if (lineStart > 0 && text[lineStart - 1] != '\n') {
      return 0;
    }
  }
  return end - i;
}
} // namespace

bool consumeFence(std::string_view text, size_t &i, Fence &fence) {
  const size_t run = fenceRunAt(text, i);
  if (run == 0) {
    return false;
  }
  if (fence.c == 0) {
    fence = {text[i], run};
  } else if (fence.c == text[i] && run >= fence.length) {
    fence = {};
  } else {
    return false;
  }
  i += run - 1;
  return true;
}

Fence unclosedFence(std::string_view text) {
  Fence fence;
  for (size_t i = 0; i < text.size(); ++i) {
    consumeFence(text, i, fence);
  }
  return fence;
}

bool endsInsideFence(std::string_view text) {
  return unclosedFence(text).c != 0;
}

size_t countDoubleMarkers(std::string_view text, char c, const MathLookup &math) {
  size_t count = 0;
  scanOutsideFences(text, [&](size_t &i) {
    if (text[i] == c && i + 1 < text.size() && text[i + 1] == c) {
      if (!math.inside(i)) {
        ++count;
      }
      ++i;
    }
    return false;
  });
  return count;
}

size_t countNonOverlapping(std::string_view text, std::string_view needle) {
  size_t count = 0;
  for (size_t pos = text.find(needle); pos != npos; pos = text.find(needle, pos + needle.size())) {
    ++count;
  }
  return count;
}

std::string_view lineBefore(std::string_view text, size_t index) {
  const size_t newline = text.substr(0, index).rfind('\n');
  const size_t lineStart = newline == npos ? 0 : newline + 1;
  return text.substr(lineStart, index - lineStart);
}

std::string_view lineAt(std::string_view text, size_t index) {
  const size_t before = text.substr(0, index).rfind('\n');
  const size_t lineStart = before == npos ? 0 : before + 1;
  const size_t after = text.find('\n', index);
  const size_t lineEnd = after == npos ? text.size() : after;
  return text.substr(lineStart, lineEnd - lineStart);
}

size_t skipListMarker(std::string_view line) {
  if (!line.empty() && (line[0] == '-' || line[0] == '*' || line[0] == '+')) {
    return 1;
  }
  size_t i = 0;
  while (i < line.size() && isAsciiDigit(line[i])) {
    ++i;
  }
  if (i == 0 || i >= line.size() || (line[i] != '.' && line[i] != ')')) {
    return npos;
  }
  return i + 1;
}

// --- Regex stand-ins -------------------------------------------------------

// Every `c` before the marker's end must be inside the marker itself, so the
// marker can only start at lastC + 1 - len or, when it overlaps the allowed
// trailing `c`, one position later. The loop therefore runs at most a couple
// of iterations; it is written as a scan only to keep it obviously correct.
std::optional<std::string_view> matchTrailingMarker(std::string_view text, std::string_view marker, char c,
                                                    bool allowTrailingSingle) {
  const size_t n = text.size();
  const size_t len = marker.size();
  if (n < len) {
    return std::nullopt;
  }
  const size_t cleanEnd = (allowTrailingSingle && n > 0 && text[n - 1] == c) ? n - 1 : n;
  const size_t lastC = text.substr(0, cleanEnd).rfind(c);
  size_t p = (lastC != npos && lastC + 1 > len) ? lastC + 1 - len : 0;
  for (; p + len <= n; ++p) {
    if (text.substr(p, len) == marker) {
      return text.substr(p + len);
    }
  }
  return std::nullopt;
}

bool matchHalfCompleteMarker(std::string_view text, std::string_view marker, char c) {
  const size_t n = text.size();
  const size_t len = marker.size();
  if (n < len + 2 || text[n - 1] != c) {
    return false;
  }
  const size_t lastC = text.substr(0, n - 1).rfind(c);
  size_t p = (lastC != npos && lastC + 1 > len) ? lastC + 1 - len : 0;
  for (; p + len + 1 < n; ++p) { // leaves >= 1 char between marker and final c
    if (text.substr(p, len) == marker) {
      return true;
    }
  }
  return false;
}

// --- Context lookups -------------------------------------------------------

// buildCodeBlockLookup()
CodeLookup::CodeLookup(std::string_view text) : insideAt_(text.size() + 1, 0) {
  const size_t n = text.size();
  bool inInline = false;
  Fence fence;
  size_t i = 0;
  while (i < n) {
    if (text[i] == '\\' && i + 1 < n && text[i + 1] == '`') {
      const uint8_t state = (inInline || fence.c != 0) ? 1 : 0;
      insideAt_[i + 1] = state;
      insideAt_[i + 2] = state;
      i += 2;
      continue;
    }
    size_t marker = i;
    if (consumeFence(text, marker, fence)) {
      const uint8_t state = (inInline || fence.c != 0) ? 1 : 0;
      for (size_t p = i + 1; p <= marker + 1; ++p) {
        insideAt_[p] = state;
      }
      i = marker + 1;
      continue;
    }
    if (fence.c == 0 && text[i] == '`') {
      inInline = !inInline;
    }
    insideAt_[i + 1] = (inInline || fence.c != 0) ? 1 : 0;
    ++i;
  }
}

bool CodeLookup::inside(size_t position) const {
  return insideAt_[std::min(position, insideAt_.size() - 1)] != 0;
}

namespace {

bool isAsciiPunctuation(uint32_t codePoint) {
  return (codePoint >= 0x21 && codePoint <= 0x2F) || (codePoint >= 0x3A && codePoint <= 0x40) ||
         (codePoint >= 0x5B && codePoint <= 0x60) || (codePoint >= 0x7B && codePoint <= 0x7E);
}

bool startsNewBlock(std::string_view text, size_t newline, size_t &depth);

} // namespace

bool inRanges(uint32_t codePoint, const UnicodeTables::Range *ranges, size_t count) {
  const auto *end = ranges + count;
  const auto *it = std::upper_bound(ranges, end, codePoint,
                                    [](uint32_t value, const UnicodeTables::Range &r) { return value < r.first; });
  return it != ranges && codePoint <= (it - 1)->last;
}

bool isUnicodePunctuation(uint32_t codePoint) {
  if (codePoint < 0x80) {
    return isAsciiPunctuation(codePoint);
  }
  return inRanges(codePoint, UnicodeTables::kPunctuationRanges, UnicodeTables::kPunctuationRangeCount);
}

DollarRun dollarRunAt(std::string_view text, size_t i) {
  size_t end = i + 1;
  while (end < text.size() && text[end] == '$') {
    ++end;
  }
  const uint32_t before = codePointBefore(text, i);
  const uint32_t after = codePointAt(text, end);
  const bool flanksBefore = before == kNoCodePoint || isJsWhitespace(before) || isUnicodePunctuation(before);
  const bool flanksAfter = after == kNoCodePoint || isJsWhitespace(after) || isUnicodePunctuation(after);
  const size_t length = end - i;
  const bool currency =
      length == 1 && (after == kNoCodePoint || isJsWhitespace(after) || (after >= '0' && after <= '9'));
  return {length, flanksBefore && !currency, flanksAfter};
}

// isWithinMathBlock(), evaluated once for every position.
MathLookup::MathLookup(std::string_view text, bool inlineDollar, const CodeLookup *code)
    : hasDelimiters_(text.find('$') != npos || text.find("\\(") != npos || text.find("\\[") != npos) {
  if (!hasDelimiters_) {
    return;
  }
  enum class Context : uint8_t { None, InlineDollar, BlockDollar, InlineLatex, BlockLatex };
  const size_t n = text.size();
  insideAt_.assign(n + 1, 0);
  Context ctx = Context::None;
  auto mark = [&](size_t from, size_t to) {
    const uint8_t state = ctx != Context::None ? 1 : 0;
    for (size_t p = from; p <= to && p <= n; ++p) {
      insideAt_[p] = state;
    }
  };
  struct Opener {
    size_t index;
    size_t length;
  };
  std::vector<Opener> openers;
  size_t depth = 0;
  if (code != nullptr) {
    stripBlockquotes(lineAt(text, 0), depth);
  }
  size_t i = 0;
  while (i < n) {
    const char c = text[i];
    const char next = i + 1 < n ? text[i + 1] : '\0';
    if (c == '\\' && next == '$') { // escaped dollar
      mark(i + 1, i + 2);
      i += 2;
      continue;
    }
    if (c == '\\') {
      // getLatexMathContext(): only these four transitions consume the pair
      bool handled = true;
      if (next == '[' && ctx == Context::None) {
        ctx = Context::BlockLatex;
      } else if (next == ']' && ctx == Context::BlockLatex) {
        ctx = Context::None;
      } else if (next == '(' && ctx == Context::None) {
        ctx = Context::InlineLatex;
      } else if (next == ')' && ctx == Context::InlineLatex) {
        ctx = Context::None;
      } else {
        handled = false;
      }
      if (handled) {
        mark(i + 1, i + 2);
        i += 2;
        continue;
      }
    }
    if (code != nullptr && ctx != Context::InlineLatex && ctx != Context::BlockLatex) {
      if (c == '\n') {
        if (startsNewBlock(text, i, depth)) {
          openers.clear();
        }
      } else if (c == '$') {
        const DollarRun run = code->inside(i) ? DollarRun{1, false, false} : dollarRunAt(text, i);
        if (run.length <= 2 && run.canClose && !openers.empty() && openers.back().length == run.length) {
          std::fill(insideAt_.begin() + static_cast<std::ptrdiff_t>(openers.back().index + 1),
                    insideAt_.begin() + static_cast<std::ptrdiff_t>(i + 1), 1);
          openers.clear();
        } else if (run.length <= 2 && run.canOpen && (run.length == 2 || inlineDollar)) {
          openers.push_back({i, run.length});
        }
        i += run.length;
        continue;
      }
    }
    if (c == '$' && ctx != Context::InlineLatex && ctx != Context::BlockLatex) {
      if (next == '$') {
        ctx = ctx == Context::BlockDollar ? Context::None : Context::BlockDollar;
        mark(i + 1, i + 2);
        i += 2;
        continue;
      }
      if (ctx != Context::BlockDollar && inlineDollar) {
        ctx = ctx == Context::InlineDollar ? Context::None : Context::InlineDollar;
      }
    }
    mark(i + 1, i + 1);
    ++i;
  }
}

bool MathLookup::inside(size_t position) const {
  return hasDelimiters_ && insideAt_[std::min(position, insideAt_.size() - 1)] != 0;
}

CompleteInlineCodeLookup::CompleteInlineCodeLookup(std::string_view text) : insideAt_(text.size() + 1, 0) {
  const size_t n = text.size();
  Fence fence;
  size_t spanStart = npos;
  for (size_t i = 0; i < n; ++i) {
    if (text[i] == '\\' && i + 1 < n && text[i + 1] == '`') {
      ++i;
      continue;
    }
    if (consumeFence(text, i, fence) || fence.c != 0 || text[i] != '`') {
      continue;
    }
    if (spanStart == npos) {
      spanStart = i;
      continue;
    }
    for (size_t p = spanStart + 1; p < i; ++p) { // strictly between the backticks
      insideAt_[p] = 1;
    }
    spanStart = npos;
  }
}

bool CompleteInlineCodeLookup::inside(size_t position) const {
  return position < insideAt_.size() && insideAt_[position] != 0;
}

// One forward pass. Link URLs need care because the backward scan in
// isWithinLinkOrImageUrl() answers for the nearest preceding paren only, and
// only when a `)` follows on the same line. So parens are collected as
// segments since the last `)` or newline, and when a `)` arrives every
// segment that started with a `](` is marked, up to the next paren.
LineContextLookup::LineContextLookup(std::string_view text) : flags_(text.size() + 1, 0) {
  struct Segment {
    size_t start; // index of the paren
    bool isLinkOpen;
  };
  std::vector<Segment> segments;
  bool inTag = false;
  const size_t n = text.size();
  for (size_t i = 0; i < n; ++i) {
    if (inTag) {
      flags_[i] |= kHtmlTag;
    }
    switch (text[i]) {
      case '(':
        segments.push_back({i, i > 0 && text[i - 1] == ']'});
        break;
      case ')':
        for (size_t k = 0; k < segments.size(); ++k) {
          if (!segments[k].isLinkOpen) {
            continue;
          }
          const size_t end = k + 1 < segments.size() ? segments[k + 1].start : i; // inclusive
          for (size_t p = segments[k].start + 1; p <= end; ++p) {
            flags_[p] |= kLinkUrl;
          }
        }
        segments.clear();
        break;
      case '\n':
        segments.clear();
        inTag = false;
        break;
      case '<':
        inTag = i + 1 < n && isAsciiLetterOrSlash(text[i + 1]);
        break;
      case '>':
        inTag = false;
        break;
      default:
        break;
    }
  }
  if (inTag) {
    flags_[n] |= kHtmlTag;
  }
}

bool LineContextLookup::insideLinkUrl(size_t position) const {
  return position < flags_.size() && (flags_[position] & kLinkUrl) != 0;
}

bool LineContextLookup::insideHtmlTag(size_t position) const {
  return position < flags_.size() && (flags_[position] & kHtmlTag) != 0;
}

namespace {

// Where a marker bracket could sit on `line`, which ends at byte `lineEnd`
// of the whole text. `rest` is always a suffix of the line, so a position is
// lineEnd - rest.size().
LineMarkers markersOf(std::string_view line, size_t lineEnd) {
  LineMarkers markers{npos, npos};
  std::string_view rest = jsTrimStart(line);
  bool inBlockquote = false;
  while (!rest.empty() && rest[0] == '>') {
    rest = jsTrimStart(rest.substr(1));
    inBlockquote = true;
  }
  if (inBlockquote) {
    markers.admonitionBracket = lineEnd - rest.size();
  }
  const size_t marker = skipListMarker(rest);
  if (marker != npos) {
    const std::string_view afterMarker = rest.substr(marker);
    const std::string_view content = jsTrimStart(afterMarker);
    if (content.size() < afterMarker.size()) { // at least one whitespace after the marker
      markers.checkboxBracket = lineEnd - content.size();
    }
  }
  return markers;
}

} // namespace

LineMarkerLookup::LineMarkerLookup(std::string_view text) {
  size_t lineStart = 0;
  for (;;) {
    const size_t newline = text.find('\n', lineStart);
    const size_t lineEnd = newline == npos ? text.size() : newline;
    lineStarts_.push_back(lineStart);
    lines_.push_back(markersOf(text.substr(lineStart, lineEnd - lineStart), lineEnd));
    if (newline == npos) {
      return;
    }
    lineStart = newline + 1;
  }
}

const LineMarkers &LineMarkerLookup::lineFor(size_t position) const {
  const auto next = std::upper_bound(lineStarts_.begin(), lineStarts_.end(), position);
  return lines_[static_cast<size_t>(next - lineStarts_.begin()) - 1];
}

bool isBracketNotALink(std::string_view text, size_t idx, const LineMarkerLookup &markers) {
  const char next = idx + 1 < text.size() ? text[idx + 1] : '\0';
  const char prev = idx > 0 ? text[idx - 1] : '\0';
  if (next == '^' || prev == ']' || isEscaped(text, idx)) {
    return true;
  }
  const LineMarkers &line = markers.lineFor(idx);
  if (idx == line.admonitionBracket && next == '!') {
    return true; // > [!NOTE]
  }
  if (idx != line.checkboxBracket) {
    return false;
  }
  const bool checkbox = (next == 'x' || next == 'X') && (idx + 2 >= text.size() || text[idx + 2] == ']');
  return next == '\0' || next == ' ' || next == ']' || checkbox; // task-list checkbox
}

const CodeLookup &RepairContext::code() {
  if (!code_) {
    code_.emplace(text_);
  }
  return *code_;
}

const MathLookup &RepairContext::math() {
  if (!math_) {
    math_.emplace(text_, inlineMath_, parserMath_ ? &code() : nullptr);
  }
  return *math_;
}

const LineContextLookup &RepairContext::lines() {
  if (!lines_) {
    lines_.emplace(textBeforeClosers());
  }
  return *lines_;
}

const LineMarkerLookup &RepairContext::markers() {
  if (!markers_) {
    markers_.emplace(text_);
  }
  return *markers_;
}

bool RepairContext::insideAnyCode(size_t position) {
  if (code().inside(position)) {
    return true;
  }
  if (!completeInline_) {
    completeInline_.emplace(text_);
  }
  return completeInline_->inside(position);
}

void RepairContext::append(std::string_view suffix) {
  text_.append(suffix);
  invalidate();
}

void RepairContext::append(char c) {
  text_.push_back(c);
  invalidate();
}

void RepairContext::erase(size_t position, size_t count) {
  text_.erase(position, count);
  invalidate();
}

void RepairContext::assign(std::string &&replacement) {
  text_ = std::move(replacement);
  invalidate();
}

std::string_view stripBlockquotes(std::string_view line, size_t &depth) {
  depth = 0;
  for (;;) {
    size_t i = 0;
    while (i < line.size() && i < 3 && line[i] == ' ') {
      ++i;
    }
    if (i < line.size() && line[i] == '>') {
      ++depth;
      line = line.substr(i + 1);
      if (!line.empty() && line[0] == ' ') {
        line.remove_prefix(1);
      }
      continue;
    }
    return line.substr(i);
  }
}

namespace {

bool isTrailingWhitespace(char c) {
  return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}

// /^ {0,3}#{1,6}[ \t]/ : the line is an ATX heading
bool isAtxHeadingLine(std::string_view line) {
  size_t i = 0;
  while (i < line.size() && i < 3 && line[i] == ' ') {
    ++i;
  }
  size_t hashes = 0;
  while (i < line.size() && line[i] == '#' && hashes < 7) {
    ++i;
    ++hashes;
  }
  return hashes >= 1 && hashes <= 6 && i < line.size() && (line[i] == ' ' || line[i] == '\t');
}

// A thematic break, or a setext underline when it follows a paragraph;
// either way the paragraph ends there. A lone `-` or `--` is not one here:
// the setext handler has already broken it with a zero-width space.
bool endsParagraphLine(std::string_view line) {
  if (isHorizontalRuleLine(line, '-') || isHorizontalRuleLine(line, '*') || isHorizontalRuleLine(line, '_')) {
    return true;
  }
  const size_t firstEq = line.find('=');
  return firstEq != npos && line.find_first_not_of(" \t\r=") == npos; // `=` underline of any length
}

// True when `line`, with its blockquote markers already stripped, begins a
// block that interrupts a paragraph: a fence, an ATX heading, a thematic
// break, or a list item. Any list number counts: CommonMark lets only `1.`
// interrupt a paragraph, but streamed text is usually already in a list,
// where every sibling marker starts a new item.
bool interruptsParagraph(std::string_view line) {
  if (startsWith(line, "```") || startsWith(line, "~~~") || isAtxHeadingLine(line) || endsParagraphLine(line)) {
    return true;
  }
  const size_t marker = skipListMarker(line);
  return marker != npos && marker < line.size() && (line[marker] == ' ' || line[marker] == '\t');
}

bool isBlankLine(std::string_view content) {
  return content.find_first_not_of(" \t\r") == npos;
}

// The newline separates two blocks: the line it ends is blank or a heading,
// or the line it starts is blank, quoted deeper than the block (opening a
// blockquote) or one that interrupts a paragraph. A line quoted shallower is
// a lazy continuation that leaves the block's depth as it is.
bool startsNewBlock(std::string_view text, size_t newline, size_t &depth) {
  size_t endedDepth = 0;
  const std::string_view ended = stripBlockquotes(lineAt(text, newline), endedDepth);
  size_t startedDepth = 0;
  const std::string_view started = stripBlockquotes(lineAt(text, newline + 1), startedDepth);
  if (!isBlankLine(ended) && !isAtxHeadingLine(ended) && !isBlankLine(started) && startedDepth <= depth &&
      !interruptsParagraph(started)) {
    return false;
  }
  depth = startedDepth;
  return true;
}

// Start of the last block in `text`. Trailing whitespace is not a blank
// line: closers go in front of it, so it never separates an opener from its
// closer. A heading ends with its line, though, so once the newline after it
// has streamed nothing is left open.
size_t findLastBlockStart(std::string_view text) {
  size_t end = text.size();
  while (end > 0 && isTrailingWhitespace(text[end - 1])) {
    --end;
  }
  const std::string_view body = text.substr(0, end);
  size_t start = 0;
  size_t depth = 0;
  stripBlockquotes(lineAt(body, 0), depth);
  for (size_t nl = body.find('\n'); nl != npos; nl = body.find('\n', nl + 1)) {
    if (startsNewBlock(body, nl, depth)) {
      start = nl + 1;
    }
  }
  const size_t newline = text.find('\n', end);
  size_t lastDepth = 0;
  if (newline != npos && isAtxHeadingLine(stripBlockquotes(lineBefore(body, end), lastDepth))) {
    return newline + 1;
  }
  return start;
}

} // namespace

size_t RepairContext::lastBlockStart() {
  if (!blockStart_) {
    blockStart_ = findLastBlockStart(textBeforeClosers());
  }
  return *blockStart_;
}

bool RepairContext::openerCanStillClose(size_t openerIndex) {
  return openerIndex >= lastBlockStart();
}

void RepairContext::closeAt(size_t openerIndex, std::string_view closer) {
  if (!openerCanStillClose(openerIndex)) {
    return;
  }
  if (closers_.empty()) {
    closersStart_ = text_.size();
    while (closersStart_ > 0 && isTrailingWhitespace(text_[closersStart_ - 1])) {
      --closersStart_;
    }
  }
  // Skip the closers of constructs opened later than ours; ours goes after them.
  size_t position = closersStart_;
  size_t slot = 0;
  while (slot < closers_.size() && closers_[slot].openerIndex >= openerIndex) {
    position += closers_[slot].length;
    ++slot;
  }
  text_.insert(position, closer);
  closers_.insert(closers_.begin() + static_cast<std::ptrdiff_t>(slot), Closer{openerIndex, closer.size()});
  // The lookups are prefix-based and clamp past their end, so inserting into
  // the tail leaves them exact unless the closer itself is a delimiter they
  // track. Rebuilding only then keeps a run with several closers linear.
  if (closer.find('`') != std::string_view::npos) {
    code_.reset();
    completeInline_.reset();
  }
  if (closer.find('$') != std::string_view::npos) {
    math_.reset();
  }
  if (closer.find('\n') != std::string_view::npos) { // display math's own-line closer moves the line starts
    markers_.reset();
  }
}

void RepairContext::dropLookups() {
  code_.reset();
  math_.reset();
  completeInline_.reset();
  lines_.reset();
  markers_.reset();
}

// Any edit other than closeAt() may move the closer tail, so forget it too.
void RepairContext::invalidate() {
  dropLookups();
  closers_.clear();
  blockStart_.reset();
}

bool isWithinHtmlTag(std::string_view text, size_t position) {
  for (size_t i = position; i > 0; --i) {
    const char c = text[i - 1];
    if (c == '>' || c == '\n') {
      return false;
    }
    if (c == '<') {
      return i < text.size() && isAsciiLetterOrSlash(text[i]);
    }
  }
  return false;
}

bool isHorizontalRuleLine(std::string_view line, char marker) {
  size_t markerCount = 0;
  for (const char c : line) {
    if (c == marker) {
      ++markerCount;
    } else if (c != ' ' && c != '\t' && c != '\r') {
      return false;
    }
  }
  return markerCount >= 3;
}

bool isHorizontalRule(std::string_view text, size_t markerIndex, char marker) {
  return isHorizontalRuleLine(lineAt(text, markerIndex), marker);
}

bool isPartOfTriple(std::string_view text, size_t i) {
  return isTripleAt(text, i) || (i >= 1 && isTripleAt(text, i - 1)) || (i >= 2 && isTripleAt(text, i - 2));
}

size_t countSingleBackticks(std::string_view text) {
  size_t count = 0;
  scanOutsideFences(text, [&](size_t &i) {
    if (text[i] == '\\' && i + 1 < text.size() && text[i + 1] == '`') {
      ++i;
    } else if (text[i] == '`' && !isPartOfTriple(text, i)) {
      ++count;
    }
    return false;
  });
  return count;
}

size_t findMatchingOpeningBracket(std::string_view text, size_t closeIndex) {
  size_t depth = 1;
  for (size_t i = closeIndex; i > 0; --i) {
    const char c = text[i - 1];
    if ((c != ']' && c != '[') || isEscaped(text, i - 1)) {
      continue;
    }
    if (c == ']') {
      ++depth;
    } else if (--depth == 0) {
      return i - 1;
    }
  }
  return npos;
}

size_t findMatchingClosingBracket(std::string_view text, size_t openIndex) {
  size_t depth = 1;
  for (size_t i = openIndex + 1; i < text.size(); ++i) {
    if ((text[i] != '[' && text[i] != ']') || isEscaped(text, i)) {
      continue;
    }
    if (text[i] == '[') {
      ++depth;
    } else if (--depth == 0) {
      return i;
    }
  }
  return npos;
}

} // namespace Markdown::RepairInternal
