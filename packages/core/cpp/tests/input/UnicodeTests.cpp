#include "InputUnicode.hpp"
#include "doctest/doctest.h"

using namespace Markdown::Input;

namespace {
Neighbor of(std::u16string_view s) {
  return classify(s);
}
} // namespace

TEST_CASE("JavaScript whitespace") {
  for (char16_t c :
       {u'\t', u'\n', u'\v', u'\f', u'\r', u' ', u' ', u' ', u' ', u' ', u' ', u' ', u' ', u' ', u' ', u'　', u'﻿'}) {
    CHECK_MESSAGE(isJsWhitespace(c), "U+" << int(c));
  }
  // Not /\s/: zero-width space, the line separator controls, NEL.
  for (char16_t c : {u'​', u'\u0085', u'᠎', u'⁠', u'a', u'\0'}) {
    CHECK_MESSAGE(!isJsWhitespace(c), "U+" << int(c));
  }
}

TEST_CASE("punctuation and symbols: ASCII") {
  for (char16_t c = 0x21; c < 0x7F; c++) {
    const bool alnum = (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
    CHECK_MESSAGE(isUnicodePunctuation(c) == !alnum, "U+" << int(c));
  }
  CHECK_FALSE(isUnicodePunctuation(0x20));
  CHECK_FALSE(isUnicodePunctuation(0x7F));
}

TEST_CASE("punctuation and symbols: Latin-1, General Punctuation, CJK, currency and math") {
  // Latin-1: inverted marks, guillemets, signs; not letters, NBSP or soft hyphen.
  for (uint32_t c : {0xA1u, 0xA2u, 0xA3u, 0xA9u, 0xABu, 0xAEu, 0xB1u, 0xB4u, 0xB6u, 0xBBu, 0xBFu, 0xD7u, 0xF7u}) {
    CHECK_MESSAGE(isUnicodePunctuation(c), "U+" << c);
  }
  for (uint32_t c : {0xA0u, 0xAAu, 0xADu, 0xB5u, 0xBAu, 0xC0u, 0xE9u}) {
    CHECK_MESSAGE(!isUnicodePunctuation(c), "U+" << c);
  }
  // General Punctuation: dashes, quotes, bullets, ellipsis, prime marks.
  for (uint32_t c = 0x2010; c <= 0x2027; c++) {
    CHECK_MESSAGE(isUnicodePunctuation(c), "U+" << c);
  }
  for (uint32_t c : {0x2030u, 0x2039u, 0x203Au, 0x203Cu, 0x2044u, 0x2052u}) {
    CHECK_MESSAGE(isUnicodePunctuation(c), "U+" << c);
  }
  // Spaces and format controls of the block are not punctuation.
  for (uint32_t c : {0x2000u, 0x200Au, 0x200Bu, 0x2028u, 0x202Fu, 0x205Fu, 0x2060u}) {
    CHECK_MESSAGE(!isUnicodePunctuation(c), "U+" << c);
  }
  // CJK symbols and punctuation, and fullwidth forms.
  for (uint32_t c : {0x3001u, 0x3002u, 0x300Cu, 0x300Du, 0x3010u, 0x3030u, 0xFF01u, 0xFF08u, 0xFF0Cu}) {
    CHECK_MESSAGE(isUnicodePunctuation(c), "U+" << c);
  }
  for (uint32_t c : {0x3000u, 0x3042u, 0x65E5u, 0xFF21u}) {
    CHECK_MESSAGE(!isUnicodePunctuation(c), "U+" << c);
  }
  // Currency, math, arrows, emoji.
  for (uint32_t c : {0x20ACu, 0x20B9u, 0x2190u, 0x2200u, 0x2211u, 0x221Eu, 0x2264u, 0x2600u, 0x1F600u, 0x1F1F5u}) {
    CHECK_MESSAGE(isUnicodePunctuation(c), "U+" << c);
  }
  // Lone surrogates and the top of the range.
  CHECK_FALSE(isUnicodePunctuation(0xD800));
  CHECK_FALSE(isUnicodePunctuation(0xDFFF));
  CHECK_FALSE(isUnicodePunctuation(0x10FFFF));
}

TEST_CASE("neighbor classification") {
  CHECK(of(u"a") == Neighbor::Word);
  CHECK(of(u"7") == Neighbor::Word);
  CHECK(of(u"é") == Neighbor::Word);
  CHECK(of(u"日") == Neighbor::Word);
  CHECK(of(u" ") == Neighbor::Whitespace);
  CHECK(of(u" ") == Neighbor::Whitespace);
  CHECK(of(u"　") == Neighbor::Whitespace);
  CHECK(of(u"!") == Neighbor::Punctuation);
  CHECK(of(u"「") == Neighbor::Punctuation);
  CHECK(of(u"\U0001F600") == Neighbor::Punctuation);
  CHECK(of(u"\U0001D400") == Neighbor::Word); // mathematical bold A: a letter
  // A lone surrogate is a word character.
  CHECK(of(std::u16string_view(u"\xD83D", 1)) == Neighbor::Word);
  CHECK(of(std::u16string_view(u"\xDE00", 1)) == Neighbor::Word);
}
