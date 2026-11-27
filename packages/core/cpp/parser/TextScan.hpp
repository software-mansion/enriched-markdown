#pragma once

#include <cstddef>
#include <string_view>

namespace Markdown {

// Character tests shared by the block kinds and the streaming filter. A line
// break is not whitespace here: the callers look at one line, or treat a break
// as the end of what they scan.
inline bool isWhitespace(char ch) {
  return ch == ' ' || ch == '\t' || ch == '\r' || ch == '\f' || ch == '\v';
}

inline bool isBlankFrom(std::string_view text, size_t from) {
  for (size_t i = from; i < text.size(); i++) {
    if (!isWhitespace(text[i]))
      return false;
  }
  return true;
}

inline bool isBlank(std::string_view text) {
  return isBlankFrom(text, 0);
}

inline bool startsWith(std::string_view text, std::string_view prefix) {
  return text.substr(0, prefix.size()) == prefix;
}

} // namespace Markdown
