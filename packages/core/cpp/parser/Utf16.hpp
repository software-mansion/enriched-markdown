#pragma once

#include <cstdint>
#include <string>
#include <string_view>

namespace Markdown {

// UTF-8 to UTF-16, for hosts whose strings and regex offsets count UTF-16 units.
inline std::u16string toUtf16(std::string_view utf8) {
  std::u16string out;
  out.reserve(utf8.size());
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

// UTF-16 to UTF-8. A lone surrogate becomes U+FFFD, as Hermes encodes it, so a
// host string hashes to the same bytes as the JS one.
inline std::string toUtf8(std::u16string_view utf16) {
  std::string out;
  out.reserve(utf16.size());
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

} // namespace Markdown
