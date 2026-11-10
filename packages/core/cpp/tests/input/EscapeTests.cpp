// markdownEscape.ts: the positions found for plain text that would otherwise
// read as markup. Expectations were checked against the TypeScript reference.
#include "InputInternal.hpp"
#include "doctest/doctest.h"

using namespace Markdown::Input;

namespace {

std::u16string escaped(std::u16string_view text) {
  std::u16string out;
  const auto positions = markdownEscapePositions(text);
  size_t written = 0;
  for (uint32_t at : positions) {
    out.append(text.substr(written, at - written));
    out.push_back(u'\\');
    written = at;
  }
  out.append(text.substr(written));
  return out;
}

} // namespace

TEST_CASE("inline specials are escaped wherever they appear") {
  CHECK(escaped(u"*not em*") == u"\\*not em\\*");
  CHECK(escaped(u"2 ** 2") == u"2 \\*\\* 2");
  CHECK(escaped(u"a || b") == u"a \\|\\| b");
  CHECK(escaped(u"[a]b") == u"\\[a\\]b");
  CHECK(escaped(u"snake_case ~~x") == u"snake\\_case \\~\\~x");
  CHECK(escaped(u"`code` <b> back\\slash") == u"\\`code\\` \\<b> back\\\\slash");
  CHECK(escaped(u"plain words, 5 > 3!") == u"plain words, 5 > 3!");
  CHECK(escaped(u"") == u"");
}

TEST_CASE("an ampersand is escaped only where it starts an entity") {
  CHECK(escaped(u"&copy; 2024") == u"\\&copy; 2024");
  CHECK(escaped(u"&#x1F; &#; &x; &;") == u"\\&#x1F; &#; \\&x; &;");
  CHECK(escaped(u"AT&T and R&D") == u"AT&T and R&D");
  CHECK(escaped(u"a & b") == u"a & b");
}

TEST_CASE("a block marker at a line start is escaped, at any indent") {
  CHECK(escaped(u"# not a heading") == u"\\# not a heading");
  CHECK(escaped(u"#hashtag") == u"\\#hashtag");
  CHECK(escaped(u"- x") == u"\\- x");
  CHECK(escaped(u"+ plus") == u"\\+ plus");
  CHECK(escaped(u"> quote") == u"\\> quote");
  CHECK(escaped(u"a\n===") == u"a\n\\===");
  CHECK(escaped(u"a\n---") == u"a\n\\---");
  CHECK(escaped(u"  - indented dash") == u"  \\- indented dash");
  CHECK(escaped(u"\t# y\n      1. z") == u"\t\\# y\n      1\\. z");
  CHECK(escaped(u"a\n\n  1) z\n   > q\n+ p") == u"a\n\n  1\\) z\n   \\> q\n\\+ p");
}

TEST_CASE("an ordered marker needs up to nine digits and a blank or the line end after the delimiter") {
  CHECK(escaped(u"1984. A novel") == u"1984\\. A novel");
  CHECK(escaped(u"3) third") == u"3\\) third");
  CHECK(escaped(u"1.") == u"1\\.");
  CHECK(escaped(u"123456789. x") == u"123456789\\. x");
  CHECK(escaped(u"0123456789. x") == u"0123456789. x");
  CHECK(escaped(u"1.5 apples") == u"1.5 apples");
  CHECK(escaped(u"3") == u"3");
}

TEST_CASE("a closing run of hashes is escaped, once") {
  CHECK(escaped(u"# Use #") == u"\\# Use \\#");
  CHECK(escaped(u"ends with #") == u"ends with \\#");
  CHECK(escaped(u"trailing ## ") == u"trailing \\## ");
  CHECK(escaped(u"a #  \t") == u"a \\#  \t");
  CHECK(escaped(u"## ") == u"\\## ");
  CHECK(escaped(u"###") == u"\\###");
  CHECK(escaped(u"C# and F#") == u"C# and F#");
}

TEST_CASE("positions are ascending and line breaks other than newline are not lines") {
  const auto positions = markdownEscapePositions(u"# a *b* #\n- c\r- d\n1. e");
  for (size_t i = 1; i < positions.size(); i++) {
    CHECK(positions[i - 1] < positions[i]);
  }
  // "\r" is no line break here: the second "-" is not at a line start.
  CHECK(escaped(u"x\r- d") == u"x\r- d");
}
