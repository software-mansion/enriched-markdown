#pragma once

#include "MarkdownInput.hpp"
#include "Utf16.hpp"
#include <string>

namespace TestSupport {

using namespace Markdown::Input;

// The editor's cycle: load a markdown value, save it back.
inline std::u16string roundTrip(std::u16string_view markdown) {
  const ParseResult parsed = parse(markdown);
  return serialize(parsed.plainText, parsed.formattingRanges, parsed.blockRanges);
}

// A string as a failure message shows it: UTF-8 with control characters escaped.
inline std::string show(std::u16string_view text) {
  std::string out;
  for (char c : Markdown::toUtf8(text)) {
    switch (c) {
      case '\n':
        out += "\\n";
        break;
      case '\t':
        out += "\\t";
        break;
      case '\r':
        out += "\\r";
        break;
      default:
        out.push_back(c);
    }
  }
  return "\"" + out + "\"";
}

} // namespace TestSupport
