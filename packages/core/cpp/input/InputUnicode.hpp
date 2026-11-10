#pragma once

#include "../repair/UnicodeTables.hpp"
#include <algorithm>
#include <cstdint>
#include <string_view>

// Character classes of the TypeScript serializer's flanking checks, which use
// JavaScript's /\s/ and /[\p{P}\p{S}]/u. The punctuation table is the one the
// repair module already ships, generated from V8's own classification.
namespace Markdown::Input {

// ASCII whitespace as the TypeScript `isAsciiWhitespace` counts it.
inline bool isAsciiWhitespace(uint32_t code) {
  return code == 0x20 || (code >= 0x09 && code <= 0x0D);
}

// /\s/ for one UTF-16 unit (every member is in the BMP).
inline bool isJsWhitespace(uint32_t unit) {
  if (unit < 0x80) {
    return isAsciiWhitespace(unit);
  }
  return unit == 0xA0 || unit == 0x1680 || (unit >= 0x2000 && unit <= 0x200A) || unit == 0x2028 || unit == 0x2029 ||
         unit == 0x202F || unit == 0x205F || unit == 0x3000 || unit == 0xFEFF;
}

// /[\p{P}\p{S}]/u for one code point. A lone surrogate is in neither class.
inline bool isUnicodePunctuation(uint32_t codePoint) {
  using UnicodeTables::kPunctuationRangeCount;
  using UnicodeTables::kPunctuationRanges;
  const auto *end = kPunctuationRanges + kPunctuationRangeCount;
  const auto *it = std::upper_bound(kPunctuationRanges, end, codePoint,
                                    [](uint32_t value, const UnicodeTables::Range &r) { return value < r.first; });
  return it != kPunctuationRanges && codePoint <= (it - 1)->last;
}

inline bool isHighSurrogate(uint32_t unit) {
  return unit >= 0xD800 && unit <= 0xDBFF;
}

inline bool isLowSurrogate(uint32_t unit) {
  return unit >= 0xDC00 && unit <= 0xDFFF;
}

// What sits on one side of a delimiter in the output. A line's edge reads as
// whitespace, another delimiter as punctuation.
enum class Neighbor { Whitespace, Punctuation, Word };

// Classifies the character (one code point, or whatever slice the caller cut)
// the way the TypeScript `classify` does: the first unit decides the ASCII
// case, and past it the whole slice is tested, as a regex test would.
inline Neighbor classify(std::u16string_view slice) {
  if (slice.empty()) {
    return Neighbor::Word;
  }
  const uint32_t first = slice[0];
  if (first < 0x80) {
    if (isAsciiWhitespace(first)) {
      return Neighbor::Whitespace;
    }
    return isUnicodePunctuation(first) ? Neighbor::Punctuation : Neighbor::Word;
  }
  for (char16_t unit : slice) {
    if (isJsWhitespace(unit)) {
      return Neighbor::Whitespace;
    }
  }
  for (size_t i = 0; i < slice.size(); i++) {
    uint32_t codePoint = slice[i];
    if (isHighSurrogate(codePoint) && i + 1 < slice.size() && isLowSurrogate(slice[i + 1])) {
      codePoint = 0x10000 + ((codePoint - 0xD800) << 10) + (slice[i + 1] - 0xDC00);
      i++;
    }
    if (isUnicodePunctuation(codePoint)) {
      return Neighbor::Punctuation;
    }
  }
  return Neighbor::Word;
}

} // namespace Markdown::Input
