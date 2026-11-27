#pragma once
#include <cstddef>
#include <string_view>

namespace Markdown {

// Words of streamed text, for fading and pacing it word by word. UTF-16 code units.

inline bool isStreamingSpace(char16_t c) {
  return c <= u' ' || c == 0xA0 || c == 0x2028 || c == 0x2029 || c == 0x3000;
}

// Characters that are words on their own: CJK and kana (written without spaces), CJK beyond the
// BMP (from its high surrogate), and attachments.
inline bool isOwnWord(char16_t c) {
  return (c >= 0x2E80 && c <= 0x9FFF) || (c >= 0xF900 && c <= 0xFAFF) || (c >= 0xFF00 && c <= 0xFFEF) ||
         (c >= 0xD840 && c <= 0xD87F) || c == 0xFFFC;
}

// Where the word starting at `i` ends, with the spaces after it.
inline size_t wordEnd(std::u16string_view text, size_t i) {
  if (i < text.size() && isOwnWord(text[i])) {
    bool pair = text[i] >= 0xD800 && text[i] <= 0xDBFF && i + 1 < text.size();
    i += pair ? 2 : 1;
  } else {
    while (i < text.size() && !isStreamingSpace(text[i]) && !isOwnWord(text[i])) {
      i++;
    }
  }
  while (i < text.size() && isStreamingSpace(text[i])) {
    i++;
  }
  return i;
}

} // namespace Markdown
