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

} // namespace

int main() {
  for (std::string text : {"", "plain", "café", "https://e.com/😀.png", "日本語 and 𝄞 and \0x"}) {
    check(Markdown::toUtf8(Markdown::toUtf16(text)) == text, "round trip of '" + text + "'");
  }
  check(Markdown::toUtf16("😀").size() == 2, "a character outside the BMP is a surrogate pair");
  check(Markdown::toUtf8(std::u16string(1, char16_t(0xD83D))) == "\xEF\xBF\xBD", "a lone high surrogate is U+FFFD");
  check(Markdown::toUtf8(std::u16string(1, char16_t(0xDE00))) == "\xEF\xBF\xBD", "a lone low surrogate is U+FFFD");

  if (failures == 0) {
    std::cout << "    utf-16 conversions ok\n";
    return 0;
  }
  return 1;
}
