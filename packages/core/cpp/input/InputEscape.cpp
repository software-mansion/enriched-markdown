#include "InputInternal.hpp"

// Backslash escapes, so exported plain text re-imports as typed. Positions
// ignore the surrounding delimiters, which over-escapes in places harmlessly.
namespace Markdown::Input {

namespace {

constexpr char16_t kAmpersand = u'&';
constexpr char16_t kHash = u'#';
constexpr char16_t kDash = u'-';
constexpr char16_t kPlus = u'+';
constexpr char16_t kEquals = u'=';
constexpr char16_t kGreaterThan = u'>';
constexpr char16_t kPeriod = u'.';
constexpr char16_t kCloseParen = u')';
constexpr char16_t kSemicolon = u';';

constexpr size_t kMaxOrderedMarkerDigits = 9;

bool isBlank(char16_t c) {
  return c == u' ' || c == u'\t';
}

bool isDigit(char16_t c) {
  return c >= u'0' && c <= u'9';
}

bool isAlphanumeric(char16_t c) {
  return isDigit(c) || (c >= u'A' && c <= u'Z') || (c >= u'a' && c <= u'z');
}

// Characters that can open or close a span. "&" only when it starts an entity.
bool isInlineSpecial(char16_t c) {
  switch (c) {
    case u'\\':
    case u'`':
    case u'*':
    case u'_':
    case u'~':
    case u'|':
    case u'[':
    case u']':
    case u'<':
    case u'&':
      return true;
    default:
      return false;
  }
}

} // namespace

bool startsEntity(std::u16string_view text, size_t at, size_t end) {
  size_t i = at + 1;
  if (i < end && text[i] == kHash) {
    i++;
  }
  const size_t nameStart = i;
  while (i < end && isAlphanumeric(text[i])) {
    i++;
  }
  return i > nameStart && i < end && text[i] == kSemicolon;
}

namespace {

// The index to escape when the line would read as a block marker (heading,
// bullet, quote, setext underline, "1." / "1)"), however indented, or npos.
size_t lineStartMarkerAt(std::u16string_view text, size_t start, size_t end) {
  size_t i = start;
  while (i < end && isBlank(text[i])) {
    i++;
  }
  if (i == end) {
    return std::u16string_view::npos;
  }
  const char16_t code = text[i];
  if (code == kHash || code == kDash || code == kPlus || code == kEquals || code == kGreaterThan) {
    return i;
  }
  const size_t digitsStart = i;
  while (i < end && i - digitsStart < kMaxOrderedMarkerDigits && isDigit(text[i])) {
    i++;
  }
  if (i == digitsStart || i == end) {
    return std::u16string_view::npos;
  }
  const char16_t delimiter = text[i];
  if (delimiter != kPeriod && delimiter != kCloseParen) {
    return std::u16string_view::npos;
  }
  return i + 1 == end || isBlank(text[i + 1]) ? i : std::u16string_view::npos;
}

// The first "#" of a closing sequence an ATX heading would strip, or npos.
size_t trailingHashesAt(std::u16string_view text, size_t start, size_t end) {
  size_t i = end;
  while (i > start && isBlank(text[i - 1])) {
    i--;
  }
  const size_t runEnd = i;
  while (i > start && text[i - 1] == kHash) {
    i--;
  }
  if (i == runEnd) {
    return std::u16string_view::npos;
  }
  return i == start || isBlank(text[i - 1]) ? i : std::u16string_view::npos;
}

} // namespace

std::vector<uint32_t> markdownEscapePositions(std::u16string_view text) {
  std::vector<uint32_t> positions;
  for (size_t lineStart = 0; lineStart <= text.size();) {
    size_t lineEnd = text.find(u'\n', lineStart);
    if (lineEnd == std::u16string_view::npos) {
      lineEnd = text.size();
    }
    // In index order: the line marker, inline specials, the closing "#" run.
    const size_t marker = lineStartMarkerAt(text, lineStart, lineEnd);
    if (marker != std::u16string_view::npos) {
      positions.push_back(static_cast<uint32_t>(marker));
    }
    for (size_t at = lineStart; at < lineEnd; at++) {
      if (isInlineSpecial(text[at]) && (text[at] != kAmpersand || startsEntity(text, at, lineEnd))) {
        positions.push_back(static_cast<uint32_t>(at));
      }
    }
    const size_t hashes = trailingHashesAt(text, lineStart, lineEnd);
    if (hashes != std::u16string_view::npos && hashes != marker) {
      positions.push_back(static_cast<uint32_t>(hashes));
    }
    lineStart = lineEnd + 1;
  }
  return positions;
}

} // namespace Markdown::Input
