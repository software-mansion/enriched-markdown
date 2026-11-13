// MarkdownSerializer.ts: the TypeScript unit tests, over the same models.
#include "InputInternal.hpp"
#include "doctest/doctest.h"

using namespace Markdown::Input;

namespace {

FormattingRange range(StyleType type, uint32_t start, uint32_t end, std::u16string url = {}) {
  FormattingRange r;
  r.type = type;
  r.start = start;
  r.end = end;
  r.url = std::move(url);
  return r;
}

BlockRange block(BlockType type, uint32_t start, uint32_t end, uint8_t level = 0, uint32_t ordinal = 1) {
  BlockRange b;
  b.type = type;
  b.start = start;
  b.end = end;
  b.level = level;
  b.ordinal = ordinal;
  return b;
}

std::u16string inlineOf(std::u16string_view text, const std::vector<FormattingRange> &ranges) {
  return serializeInline(text, ranges);
}

constexpr StyleType Strong = StyleType::Strong;
constexpr StyleType Em = StyleType::Em;
constexpr StyleType Underline = StyleType::Underline;
constexpr StyleType Strike = StyleType::Strikethrough;
constexpr StyleType Link = StyleType::Link;
constexpr StyleType Spoiler = StyleType::Spoiler;

} // namespace

TEST_CASE("inline: each style wraps in its dialect delimiters") {
  const std::u16string_view text = u"The world is big";
  CHECK(inlineOf(text, {range(Strong, 4, 9)}) == u"The **world** is big");
  CHECK(inlineOf(text, {range(Em, 4, 9)}) == u"The *world* is big");
  CHECK(inlineOf(text, {range(Underline, 4, 9)}) == u"The _world_ is big");
  CHECK(inlineOf(text, {range(Strike, 4, 9)}) == u"The ~~world~~ is big");
  CHECK(inlineOf(text, {range(Spoiler, 4, 9)}) == u"The ||world|| is big");
  CHECK(inlineOf(text, {range(Link, 4, 9, u"https://a.example")}) == u"The [world](https://a.example) is big");
}

TEST_CASE("inline: links and spoilers go outside font styles over the same text") {
  const std::u16string_view text = u"The world is big";
  CHECK(inlineOf(text, {range(Spoiler, 4, 9), range(Em, 4, 9)}) == u"The ||*world*|| is big");
  CHECK(inlineOf(text, {range(Link, 4, 9, u"https://a.example"), range(Strong, 4, 9)}) ==
        u"The [**world**](https://a.example) is big");
}

TEST_CASE("inline: nesting follows containment, whatever the types") {
  CHECK(inlineOf(u"click here", {range(Link, 0, 10, u"u"), range(Strong, 6, 10)}) == u"[click **here**](u)");
  CHECK(inlineOf(u"click here", {range(Strong, 0, 5), range(Link, 0, 10, u"u")}) == u"[**click** here](u)");
  CHECK(inlineOf(u"a b", {range(Spoiler, 0, 3), range(Strong, 0, 1)}) == u"||**a** b||");
}

TEST_CASE("inline: a range crossing another closes and reopens") {
  // Bold "ab cd", italic "cd ef": bold ends inside italic.
  CHECK(inlineOf(u"ab cd ef", {range(Strong, 0, 5), range(Em, 3, 8)}) == u"**ab *cd*** *ef*");
  // The reopened italic skips the space, where it could not open.
  CHECK(inlineOf(u"ab cd ef", {range(Em, 0, 5), range(Strong, 3, 8)}) == u"*ab **cd*** **ef**");
  CHECK(inlineOf(u"ab cd", {range(Link, 0, 2, u"u"), range(Em, 0, 5)}) == u"*[ab](u) cd*");
}

TEST_CASE("inline: delimiters are trimmed to hug non-whitespace content") {
  CHECK(inlineOf(u"The world is big", {range(Strong, 3, 10)}) == u"The **world** is big");
  CHECK(inlineOf(u"a b", {range(Strong, 1, 2)}) == u"a b");
}

TEST_CASE("inline: a range closes before the next opens at a shared boundary") {
  CHECK(inlineOf(u"ab", {range(Strong, 0, 1), range(Underline, 1, 2)}) == u"**a**_b_");
}

TEST_CASE("inline: a range closes and reopens on each line it covers") {
  CHECK(inlineOf(u"foo\nbar", {range(Strong, 0, 7)}) == u"**foo**\n**bar**");
  CHECK(inlineOf(u"foo\n\nbar", {range(Em, 0, 8)}) == u"*foo*\n\n*bar*");
  CHECK(inlineOf(u"foo\nbar", {range(Link, 0, 7, u"https://a.example")}) ==
        u"[foo](https://a.example)\n[bar](https://a.example)");
}

TEST_CASE("inline: a \"!\" right before a link is escaped") {
  CHECK(inlineOf(u"Wow!docs", {range(Link, 4, 8, u"u")}) == u"Wow\\![docs](u)");
  // A literal backslash before the "!" stays escaped on its own.
  CHECK(inlineOf(u"Wo\\!docs", {range(Link, 4, 8, u"u")}) == u"Wo\\\\\\![docs](u)");
}

TEST_CASE("inline: a \"!\" is left alone when anything is written between it and the link") {
  CHECK(inlineOf(u"Wow! docs", {range(Link, 5, 9, u"u")}) == u"Wow! [docs](u)");
  // A delimiter closing at the link start lands between the two.
  CHECK(inlineOf(u"Wow!docs", {range(Strong, 0, 4), range(Link, 4, 8, u"u")}) == u"**Wow!**[docs](u)");
  // So does one opening there outside the link.
  CHECK(inlineOf(u"Wow!docs", {range(Strong, 4, 8), range(Link, 4, 6, u"u")}) == u"Wow!**[do](u)cs**");
}

TEST_CASE("inline: bold and italic meeting inside a word are one delimiter run") {
  CHECK(inlineOf(u"abcd", {range(Strong, 0, 1), range(Em, 0, 1)}) == u"***a***bcd");
  CHECK(inlineOf(u"abcd", {range(Strong, 0, 2), range(Em, 1, 2)}) == u"**a*b***cd");
  CHECK(inlineOf(u"abcd", {range(Strong, 1, 3), range(Em, 1, 3)}) == u"a***bc***d");
}

TEST_CASE("inline: a delimiter of another kind is punctuation, and an unreadable style is dropped") {
  CHECK(inlineOf(u"abcd", {range(Strong, 0, 2), range(Strike, 0, 2)}) == u"abcd");
  // Underline and strikethrough do not work inside a word.
  CHECK(inlineOf(u"abcd", {range(Underline, 0, 2)}) == u"abcd");
  CHECK(inlineOf(u"ab cd", {range(Underline, 3, 5)}) == u"ab _cd_");
}

TEST_CASE("inline: flanking uses the Unicode classes of the reference") {
  // "**" after an ideographic comma: punctuation before, CJK letter after.
  CHECK(inlineOf(u"、日本", {range(Strong, 1, 3)}) == u"、**日本**");
  // A closing "**" after punctuation and before a letter cannot close.
  CHECK(inlineOf(u"「引用」です", {range(Strong, 0, 4)}) == u"「引用」です");
  // An emoji counts as punctuation next to "**".
  CHECK(inlineOf(u"a\U0001F600b", {range(Strong, 1, 3)}) == u"a\U0001F600b");
  CHECK(inlineOf(u"a \U0001F600b", {range(Strong, 2, 4)}) == u"a \U0001F600b");
  CHECK(inlineOf(u"a \U0001F600 b", {range(Strong, 2, 4)}) == u"a **\U0001F600** b");
  // No-break and ideographic spaces are whitespace: trimmed, and not flanking.
  CHECK(inlineOf(u" ab　", {range(Strong, 0, 4)}) == u" **ab**　");
}

TEST_CASE("inline: a link destination that would end early is wrapped") {
  const auto link = [](std::u16string url) { return inlineOf(u"docs", {range(Link, 0, 4, std::move(url))}); };
  CHECK(link(u"https://a.example/a b") == u"[docs](<https://a.example/a b>)");
  CHECK(link(u"https://a.example/a(b") == u"[docs](<https://a.example/a(b>)");
  // Balanced parens parse fine bare, so they stay bare.
  CHECK(link(u"https://a.example/a(b)c") == u"[docs](https://a.example/a(b)c)");
  CHECK(link(u"a<b>c d") == u"[docs](<a\\<b\\>c d>)");
}

TEST_CASE("inline: a backslash in a link destination is doubled in both forms") {
  const auto link = [](std::u16string url) { return inlineOf(u"docs", {range(Link, 0, 4, std::move(url))}); };
  CHECK(link(u"https://a.example/a b\\") == u"[docs](<https://a.example/a b\\\\>)");
  CHECK(link(u"https://a.example/a\\*b") == u"[docs](https://a.example/a\\\\*b)");
}

TEST_CASE("inline: a line ending in a link destination is percent-encoded") {
  CHECK(inlineOf(u"docs", {range(Link, 0, 4, u"https://a.example/a\nb")}) == u"[docs](https://a.example/a%0Ab)");
  CHECK(inlineOf(u"docs", {range(Link, 0, 4, u"https://a.example/a\r\nb")}) == u"[docs](https://a.example/a%0D%0Ab)");
}

TEST_CASE("inline: plain text that would read as markup is escaped") {
  CHECK(inlineOf(u"2 ** 2 and a_b", {}) == u"2 \\*\\* 2 and a\\_b");
  CHECK(inlineOf(u"**bold * star**", {range(Strong, 0, 15)}) == u"**\\*\\*bold \\* star\\*\\***");
}

TEST_CASE("blocks: each line is prefixed with its marker") {
  const std::u16string_view text = u"Rebase\nfetch\nmerge";
  const std::vector<BlockRange> blocks = {block(BlockType::H2, 0, 6, 2), block(BlockType::OrderedListItem, 7, 12),
                                          block(BlockType::OrderedListItem, 13, 18, 0, 2)};
  CHECK(serialize(text, {}, blocks) == u"## Rebase\n1. fetch\n2. merge");
}

TEST_CASE("blocks: markers combine with inline delimiters") {
  const std::vector<BlockRange> blocks = {block(BlockType::OrderedListItem, 7, 12)};
  CHECK(serialize(u"Rebase\nfetch\nmerge", {range(Strong, 7, 12)}, blocks) == u"Rebase\n1. **fetch**\nmerge");
  const std::vector<BlockRange> mixed = {block(BlockType::UnorderedListItem, 0, 2), block(BlockType::H2, 3, 5, 2)};
  CHECK(serialize(u"ab\ncd", {range(Strong, 0, 5)}, mixed) == u"- **ab**\n## **cd**");
}

TEST_CASE("blocks: an empty heading anchor keeps its prefix, an empty item under text stays bare") {
  const std::u16string_view text = u"a\n\nb";
  CHECK(serialize(text, {}, {block(BlockType::H1, 2, 2, 1)}) == u"a\n# \nb");
  CHECK(serialize(text, {}, {block(BlockType::UnorderedListItem, 2, 2)}) == u"a\n\nb");
}

TEST_CASE("blocks: an empty item after an item at least as deep, a heading, an empty line or the start is marked") {
  const std::vector<BlockRange> deep = {
      block(BlockType::UnorderedListItem, 0, 1, 0), block(BlockType::UnorderedListItem, 2, 3, 1),
      block(BlockType::UnorderedListItem, 4, 4, 1), block(BlockType::UnorderedListItem, 5, 5, 0)};
  CHECK(serialize(u"a\nb\n\n", {}, deep) == u"- a\n  - b\n  - \n- ");

  const auto item = [](uint32_t at) { return block(BlockType::OrderedListItem, at, at); };
  CHECK(serialize(u"h\n", {}, {block(BlockType::H1, 0, 1, 1), item(2)}) == u"# h\n1. ");
  CHECK(serialize(u"a\n\n", {}, {item(3)}) == u"a\n\n1. ");
  CHECK(serialize(u"\nb", {}, {item(0)}) == u"1. \nb");
}

TEST_CASE("blocks: a first child is left bare when its parent has text") {
  // "- a\n  -" makes "a" a setext heading inside the item.
  const std::vector<BlockRange> blocks = {block(BlockType::UnorderedListItem, 0, 1, 0),
                                          block(BlockType::UnorderedListItem, 2, 2, 1),
                                          block(BlockType::UnorderedListItem, 3, 4, 1)};
  CHECK(serialize(u"a\n\nc", {}, blocks) == u"- a\n\n  - c");
}

TEST_CASE("blocks: a link url carrying a line ending keeps the block prefixes") {
  const std::vector<BlockRange> blocks = {block(BlockType::H1, 0, 6, 1), block(BlockType::UnorderedListItem, 7, 12)};
  CHECK(serialize(u"Rebase\nfetch\nmerge", {range(Link, 7, 12, u"https://a.example/a\nb")}, blocks) ==
        u"# Rebase\n- [fetch](https://a.example/a%0Ab)\nmerge");
}

TEST_CASE("blocks: a nested item indents to its parent's marker width") {
  const auto nested = [](uint32_t ordinal) {
    return serialize(
        u"a\nb", {},
        {block(BlockType::OrderedListItem, 0, 1, 0, ordinal), block(BlockType::UnorderedListItem, 2, 3, 1)});
  };
  // Three spaces clear "1. " but not "10. ", which would de-nest the child.
  CHECK(nested(1) == u"1. a\n   - b");
  CHECK(nested(10) == u"10. a\n    - b");
}

TEST_CASE("blocks: blocks handed over out of order still get every marker") {
  const std::vector<BlockRange> blocks = {block(BlockType::H1, 13, 18, 1), block(BlockType::UnorderedListItem, 7, 12),
                                          block(BlockType::H3, 0, 6, 3)};
  CHECK(serialize(u"Rebase\nfetch\nmerge", {}, blocks) == u"### Rebase\n- fetch\n# merge");
}

TEST_CASE("blocks: the trailing empty line after a final newline can be anchored") {
  CHECK(serialize(u"a\n", {}, {block(BlockType::H1, 2, 2, 1)}) == u"a\n# ");
}

TEST_CASE("blocks: ranges past the text are clamped, not read out of bounds") {
  CHECK(serialize(u"ab", {range(Strong, 1, 99)}, {block(BlockType::H1, 0, 99, 1)}) == u"# a**b**");
  CHECK(serialize(u"", {range(Strong, 0, 4)}, {}) == u"");
  CHECK(serialize(u"ab", {range(Strong, 5, 9)}, {block(BlockType::UnorderedListItem, 7, 9)}) == u"ab");
}

TEST_CASE("markdownLinePrefix: heading, bullet and numbered markers") {
  CHECK(markdownLinePrefix(block(BlockType::H3, 0, 5, 3)) == u"### ");
  CHECK(markdownLinePrefix(block(BlockType::Paragraph, 0, 5)).empty());
  CHECK(markdownLinePrefix(block(BlockType::UnorderedListItem, 0, 5, 1)) == u"   - ");
  CHECK(markdownLinePrefix(block(BlockType::OrderedListItem, 0, 5, 2, 3)) == u"      3. ");
  CHECK(markdownLinePrefix(block(BlockType::OrderedListItem, 0, 5, 1, 12), 4) == u"    12. ");
}

TEST_CASE("markdownLinePrefix: a heading's level comes from its type") {
  CHECK(markdownLinePrefix(block(BlockType::H3, 0, 5)) == u"### ");
  CHECK(markdownLinePrefix(block(BlockType::H6, 0, 5, 2)) == u"###### ");
}

TEST_CASE("markdownLinePrefix: list indentation clamps to the deepest nesting the store allows") {
  CHECK(markdownLinePrefix(block(BlockType::UnorderedListItem, 0, 5, 9)) == std::u16string(15, u' ') + u"- ");
}
