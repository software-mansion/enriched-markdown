/*
 * Checks the UTF-8 / UTF-16 conversions hosts use at their string boundary:
 * a round trip keeps every character, including ones outside the BMP, and a
 * lone surrogate becomes U+FFFD as Hermes encodes it. See
 * scripts/test-core-parser.sh.
 */
#include "Utf16.hpp"
#include <iostream>
#include <string>

namespace {

int failures = 0;

void check(bool condition, const std::string &what) {
  if (!condition) {
    std::cerr << "FAIL: " << what << "\n";
    failures++;
  }
}

// The conversions as they were written first, one push_back per unit: the sized ones must match them.
std::u16string referenceUtf16(std::string_view utf8) {
  std::u16string out;
  for (size_t i = 0; i < utf8.size();) {
    unsigned char lead = static_cast<unsigned char>(utf8[i]);
    size_t length = lead < 0x80 ? 1 : lead < 0xE0 ? 2 : lead < 0xF0 ? 3 : 4;
    if (i + length > utf8.size())
      break;
    uint32_t codePoint = length == 1   ? lead
                         : length == 2 ? ((lead & 0x1Fu) << 6) | (utf8[i + 1] & 0x3Fu)
                         : length == 3 ? ((lead & 0x0Fu) << 12) | ((utf8[i + 1] & 0x3Fu) << 6) | (utf8[i + 2] & 0x3Fu)
                                       : ((lead & 0x07u) << 18) | ((utf8[i + 1] & 0x3Fu) << 12) |
                                             ((utf8[i + 2] & 0x3Fu) << 6) | (utf8[i + 3] & 0x3Fu);
    if (codePoint >= 0x10000) {
      codePoint -= 0x10000;
      out.push_back(static_cast<char16_t>(0xD800 + (codePoint >> 10)));
      out.push_back(static_cast<char16_t>(0xDC00 + (codePoint & 0x3FF)));
    } else {
      out.push_back(static_cast<char16_t>(codePoint));
    }
    i += length;
  }
  return out;
}

std::string referenceUtf8(std::u16string_view utf16) {
  std::string out;
  for (size_t i = 0; i < utf16.size(); i++) {
    uint32_t codePoint = utf16[i];
    bool high = codePoint >= 0xD800 && codePoint <= 0xDBFF;
    if (high && i + 1 < utf16.size() && utf16[i + 1] >= 0xDC00 && utf16[i + 1] <= 0xDFFF) {
      codePoint = 0x10000 + ((codePoint - 0xD800) << 10) + (utf16[i + 1] - 0xDC00);
      i++;
    } else if (codePoint >= 0xD800 && codePoint <= 0xDFFF) {
      codePoint = 0xFFFD;
    }
    if (codePoint < 0x80) {
      out.push_back(static_cast<char>(codePoint));
    } else if (codePoint < 0x800) {
      out.push_back(static_cast<char>(0xC0 | (codePoint >> 6)));
      out.push_back(static_cast<char>(0x80 | (codePoint & 0x3F)));
    } else if (codePoint < 0x10000) {
      out.push_back(static_cast<char>(0xE0 | (codePoint >> 12)));
      out.push_back(static_cast<char>(0x80 | ((codePoint >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (codePoint & 0x3F)));
    } else {
      out.push_back(static_cast<char>(0xF0 | (codePoint >> 18)));
      out.push_back(static_cast<char>(0x80 | ((codePoint >> 12) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | ((codePoint >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (codePoint & 0x3F)));
    }
  }
  return out;
}

} // namespace

int main() {
  for (std::string text : {"", "plain", "café", "https://e.com/😀.png", "日本語 and 𝄞 and \0x"}) {
    check(Markdown::toUtf8(Markdown::toUtf16(text)) == text, "round trip of '" + text + "'");
  }
  check(Markdown::toUtf16("😀").size() == 2, "a character outside the BMP is a surrogate pair");
  check(Markdown::toUtf8(std::u16string(1, char16_t(0xD83D))) == "\xEF\xBF\xBD", "a lone high surrogate is U+FFFD");
  check(Markdown::toUtf8(std::u16string(1, char16_t(0xDE00))) == "\xEF\xBF\xBD", "a lone low surrogate is U+FFFD");

  // Random units and bytes, lone and paired surrogates and cut sequences among them.
  uint32_t seed = 1;
  auto next = [&] { return seed = seed * 1664525u + 1013904223u; };
  const char16_t units[] = {u'a',   u'\n',  0x7F,   0x80,   0x7FF,  0x800,  0xD7FF,
                            0xD800, 0xDBFF, 0xDC00, 0xDFFF, 0xE000, 0xFFFD, 0xFFFF};
  for (int round = 0; round < 20000; round++) {
    std::u16string utf16;
    std::string utf8;
    size_t size = next() % 12;
    for (size_t i = 0; i < size; i++) {
      utf16.push_back(next() % 3 == 0 ? static_cast<char16_t>(next() >> 16) : units[next() % 14]);
      utf8.push_back(static_cast<char>(next() >> 24));
    }
    check(Markdown::toUtf8(utf16) == referenceUtf8(utf16), "toUtf8 matches the reference");
    check(Markdown::toUtf16(utf8) == referenceUtf16(utf8), "toUtf16 matches the reference");
  }

  if (failures == 0) {
    std::cout << "    utf-16 conversions ok\n";
    return 0;
  }
  return 1;
}
