// Properties over the shared fixtures in fixtures/input:
//  1. a canonical document round-trips byte for byte;
//  2. any markdown reaches a fixed point after one round trip and keeps its text;
//  3. text a user typed comes back as typed (the fuzz test covers random models).
#include "FixtureFile.hpp"
#include "TestSupport.hpp"
#include "doctest/doctest.h"

using namespace TestSupport;

namespace {

using Cases = std::vector<std::vector<std::u16string>>;

BlockRange block(BlockType type, uint32_t start, uint32_t end, uint8_t level = 0) {
  BlockRange b;
  b.type = type;
  b.start = start;
  b.end = end;
  b.level = level;
  return b;
}

// Every markdown string the fixtures hold, as written and as settled.
std::vector<std::u16string> allFixtureMarkdown() {
  std::vector<std::u16string> all;
  for (const char *file : {"canonical.json", "normalization.json", "unsupported.json"}) {
    for (const auto &fixture : FixtureFile::load(file)) {
      all.insert(all.end(), fixture.begin(), fixture.end());
    }
  }
  return all;
}

} // namespace

TEST_CASE("property 1: canonical fixtures round-trip byte for byte") {
  for (const auto &fixture : FixtureFile::load("canonical.json")) {
    INFO("markdown: " << show(fixture[0]));
    CHECK(show(roundTrip(fixture[0])) == show(fixture[0]));
  }
}

TEST_CASE("normalization fixtures settle in one pass") {
  for (const char *file : {"normalization.json", "unsupported.json"}) {
    for (const auto &fixture : FixtureFile::load(file)) {
      REQUIRE(fixture.size() == 2);
      INFO(file << ", markdown: " << show(fixture[0]));
      CHECK(show(roundTrip(fixture[0])) == show(fixture[1]));
      // The settled form is canonical.
      INFO("settled: " << show(fixture[1]));
      CHECK(show(roundTrip(fixture[1])) == show(fixture[1]));
    }
  }
}

TEST_CASE("property 2: any fixture markdown reaches a fixed point and keeps its text") {
  for (const std::u16string &markdown : allFixtureMarkdown()) {
    INFO("markdown: " << show(markdown));
    const std::u16string once = roundTrip(markdown);
    CHECK(show(roundTrip(once)) == show(once));
    CHECK(show(parse(once).plainText) == show(parse(markdown).plainText));
  }
}

TEST_CASE("issue 1127: text with markup characters is not changed by a save") {
  const std::u16string_view cases[] = {u"## Title \\[wip", u"- a\n- b\n- c \\[", u"2 \\*x\\* 6", u"- \\> x",
                                       u"- \\+ x",         u"## Use \\#",        u"1.  x"};
  for (std::u16string_view markdown : cases) {
    INFO("markdown: " << show(markdown));
    CHECK(show(roundTrip(markdown)) == show(markdown));
  }
  // What the user typed, not what it escapes to.
  CHECK(parse(u"2 \\*x\\* 6").plainText == u"2 *x* 6");
  CHECK(parse(u"- \\> x").plainText == u"> x");
  CHECK(parse(u"- \\+ x").plainText == u"+ x");
  CHECK(parse(u"## Use \\#").plainText == u"Use #");
  CHECK(parse(u"1.  x").plainText == u" x");
  // An unclosed delimiter keeps the blocks around it.
  CHECK(parse(u"## Title [wip").plainText == u"Title [wip");
  CHECK(parse(u"- a\n- b\n- c [").blockRanges.size() == 3);
}

TEST_CASE("property 3, by example: typed text comes back as typed") {
  for (const auto &fixture : FixtureFile::load("plain-text.json")) {
    const std::u16string &text = fixture[0];
    INFO("text: " << show(text));
    const std::u16string markdown = serialize(text, {}, {});
    INFO("markdown: " << show(markdown));
    const ParseResult parsed = parse(markdown);
    CHECK(show(parsed.plainText) == show(text));
    CHECK(parsed.formattingRanges.empty());
    CHECK(parsed.blockRanges.empty());
  }
}

TEST_CASE("property 3, by example: typed text survives inside a heading, a list item and bold") {
  for (const auto &fixture : FixtureFile::load("plain-text.json")) {
    const std::u16string &text = fixture[0];
    if (text.find(u'\n') != std::u16string::npos) {
      continue;
    }
    for (BlockType type : {BlockType::H2, BlockType::UnorderedListItem}) {
      const uint32_t length = static_cast<uint32_t>(text.size());
      FormattingRange bold;
      bold.type = StyleType::Strong;
      bold.start = 0;
      bold.end = length;
      const std::u16string markdown = serialize(text, {bold}, {block(type, 0, length, type == BlockType::H2 ? 2 : 0)});
      INFO("text: " << show(text) << ", markdown: " << show(markdown));
      const ParseResult parsed = parse(markdown);
      CHECK(show(parsed.plainText) == show(text));
      REQUIRE(parsed.blockRanges.size() == 1);
      CHECK(parsed.blockRanges[0].type == type);
    }
  }
}

TEST_CASE("leading whitespace goes out as typed and comes back as text") {
  // Markdown has no escape for leading whitespace, so it is kept as is; the
  // marker after it is escaped.
  CHECK(parse(serialize(u"  - indented dash", {}, {})).plainText == u"  - indented dash");
  for (std::u16string_view text : {u"\tfoo", u"  foo", u"    foo", u"\t\tfoo\nbar", u"a\n\tb", u"a\n\n    b"}) {
    INFO("text: " << show(text));
    const std::u16string markdown = serialize(text, {}, {});
    CHECK(show(markdown) == show(text));
    const ParseResult parsed = parse(markdown);
    CHECK(show(parsed.plainText) == show(text));
    CHECK(parsed.formattingRanges.empty());
    CHECK(parsed.blockRanges.empty());
  }
}

TEST_CASE("private-use characters the user typed are not taken for leading whitespace") {
  // Leading whitespace is swapped for private-use stand-ins while md4c parses;
  // the stand-ins must not be characters the text already has.
  for (std::u16string_view text :
       {u"\uE000x", u"\uE001y\n\uE000z", u"\t\uE000foo", u"  \uE001\uE000 bar", u"\uE000\uE001\uE002\tq"}) {
    INFO("text: " << show(text));
    const ParseResult parsed = parse(serialize(text, {}, {}));
    CHECK(show(parsed.plainText) == show(text));
  }
  const std::vector<BlockRange> item = {block(BlockType::UnorderedListItem, 0, 2)};
  const ParseResult parsed = parse(serialize(u"\uE000x", {}, item));
  CHECK(show(parsed.plainText) == show(u"\uE000x"));
}

TEST_CASE("whitespace after a marker-like line in a code block comes back as text") {
  // The code block keeps the "-" or "#" whose following whitespace import
  // swapped for stand-ins, so they sit mid-line in the plain text.
  for (std::u16string_view markdown :
       {u"```\n-  x\n```", u"```\n#  x\n1.\t\ty\n```", u"~~~\n- \t z\n~~~", u"```\n    indented\n\tfoo\n```"}) {
    INFO("markdown: " << show(markdown));
    const ParseResult parsed = parse(markdown);
    const std::u16string_view code = std::u16string_view(markdown).substr(4, markdown.size() - 8);
    CHECK(show(parsed.plainText) == show(code));
    CHECK(show(parse(serialize(parsed.plainText, parsed.formattingRanges, parsed.blockRanges)).plainText) ==
          show(code));
  }
}

TEST_CASE("a private-use character written as a numeric reference is not taken for leading whitespace") {
  CHECK(show(parse(u"&#xE000;x\n&#57345;y").plainText) == show(u"\uE000x\n\uE001y"));
  CHECK(show(parse(u"  &#xe000;x").plainText) == show(u"  \uE000x"));
}

TEST_CASE("link urls come back as given") {
  for (std::u16string_view url : {u"https://x.dev/?q=&copy;", u"https://x.dev/?a=1&amp;b=2", u"https://x.dev/?a=1&b=2",
                                  u"https://x.dev/&#65;", u"<foo>", u"<foo", u"a<b", u"<a b>"}) {
    INFO("url: " << show(url));
    FormattingRange link;
    link.type = StyleType::Link;
    link.start = 0;
    link.end = 4;
    link.url = std::u16string(url);
    const ParseResult parsed = parse(serialize(u"docs", {link}, {}));
    CHECK(show(parsed.plainText) == show(u"docs"));
    REQUIRE(parsed.formattingRanges.size() == 1);
    CHECK(show(parsed.formattingRanges[0].url) == show(url));
  }
}

TEST_CASE("an indented marker the user typed stays text, at any depth") {
  const std::u16string_view text = u"    - x\n\t# y\n      1. z";
  const std::u16string markdown = serialize(text, {}, {});
  CHECK(show(markdown) == show(u"    \\- x\n\t\\# y\n      1\\. z"));
  const ParseResult parsed = parse(markdown);
  CHECK(parsed.plainText == text);
  CHECK(parsed.blockRanges.empty());
}

TEST_CASE("the whitespace after a list or heading marker is kept as text") {
  const std::vector<BlockRange> blocks = {block(BlockType::UnorderedListItem, 0, 5), block(BlockType::H1, 6, 10, 1)};
  const std::u16string markdown = serialize(u"  foo\n\tbar", {}, blocks);
  CHECK(show(markdown) == show(u"-   foo\n# \tbar"));
  const ParseResult parsed = parse(markdown);
  CHECK(parsed.plainText == u"  foo\n\tbar");
  REQUIRE(parsed.blockRanges.size() == 2);
  CHECK(parsed.blockRanges[0].type == BlockType::UnorderedListItem);
  CHECK(parsed.blockRanges[0].end == 5);
  CHECK(parsed.blockRanges[1].type == BlockType::H1);
  CHECK(parsed.blockRanges[1].start == 6);
}

TEST_CASE("offsets survive emoji and CJK in front of a style") {
  const std::u16string_view markdown = u"\U0001F600日本 **\U0001F1F5\U0001F1F1** [l](http://u)\n- あ *x*";
  const ParseResult parsed = parse(markdown);
  CHECK(parsed.plainText == u"\U0001F600日本 \U0001F1F5\U0001F1F1 l\nあ x");
  REQUIRE(parsed.formattingRanges.size() == 3);
  CHECK(parsed.formattingRanges[0].start == 5);
  CHECK(parsed.formattingRanges[0].end == 9);
  CHECK(show(roundTrip(markdown)) == show(markdown));
}
