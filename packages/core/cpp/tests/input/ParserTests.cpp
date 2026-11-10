// InputParser.ts and normalizeImport.ts. The AST cases are the TypeScript unit
// tests, over the same hand-built trees; the markdown cases were checked
// against the TypeScript reference.
#include "InputInternal.hpp"
#include "Utf16.hpp"
#include "doctest/doctest.h"
#include <memory>
#include <sstream>

using namespace Markdown::Input;
using Markdown::MarkdownASTNode;
using Markdown::NodeType;

namespace {

using Node = std::shared_ptr<MarkdownASTNode>;

Node node(NodeType type, std::vector<Node> children = {},
          std::unordered_map<std::string, std::string> attributes = {}) {
  auto result = std::make_shared<MarkdownASTNode>(type);
  result->children = std::move(children);
  result->attributes = std::move(attributes);
  return result;
}

Node text(const std::string &content) {
  auto result = std::make_shared<MarkdownASTNode>(NodeType::Text);
  result->content = content;
  return result;
}

// md4c's report of `count` blank source lines (`preserveBlankLines`).
Node blank(int count) {
  return node(NodeType::BlankLine, {}, {{"count", std::to_string(count)}});
}

std::string utf8(std::u16string_view s) {
  return Markdown::toUtf8(s);
}

// One line per range, e.g. "ul:0-5/0" and "strong:6-10".
std::string describe(const std::vector<BlockRange> &blocks) {
  static const char *const names[] = {"p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol"};
  std::ostringstream out;
  for (const BlockRange &b : blocks) {
    out << names[static_cast<int>(b.type)] << ":" << b.start << "-" << b.end << "/" << int(b.level) << " ";
  }
  return out.str();
}

std::string describe(const std::vector<FormattingRange> &ranges) {
  static const char *const names[] = {"strong", "em", "underline", "strikethrough", "link", "spoiler"};
  std::ostringstream out;
  for (const FormattingRange &r : ranges) {
    out << names[static_cast<int>(r.type)] << ":" << r.start << "-" << r.end;
    if (!r.url.empty()) {
      out << "(" << utf8(r.url) << ")";
    }
    out << " ";
  }
  return out.str();
}

ParseResult fromAst(const Node &ast) {
  ParseResult result;
  REQUIRE(parseResultFromAst(*ast, result));
  return result;
}

ParseResult parseUtf8(const std::string &markdown) {
  return parse(Markdown::toUtf16(markdown));
}

std::string textOf(const std::string &markdown) {
  return utf8(parseUtf8(markdown).plainText);
}

} // namespace

TEST_CASE("AST: plain text accumulates and style nodes become ranges") {
  // "merge **fast** now": delimiters live in the AST, not the text.
  auto ast = node(NodeType::Document,
                  {node(NodeType::Paragraph, {text("merge "), node(NodeType::Strong, {text("fast")}), text(" now")})});
  const ParseResult result = fromAst(ast);
  CHECK(result.plainText == u"merge fast now");
  CHECK(describe(result.formattingRanges) == "strong:6-10 ");
  CHECK(result.blockRanges.empty());
}

TEST_CASE("AST: a link keeps its url, a style over empty content is dropped") {
  auto ast = node(NodeType::Document,
                  {node(NodeType::Paragraph, {node(NodeType::Link, {text("docs")}, {{"url", "https://git-scm.com"}}),
                                              node(NodeType::Strong)})});
  CHECK(describe(fromAst(ast).formattingRanges) == "link:0-4(https://git-scm.com) ");
}

TEST_CASE("AST: headings carry their level, paragraphs none, a bad level is a paragraph") {
  auto ast = node(NodeType::Document, {node(NodeType::Heading, {text("Rebase")}, {{"level", "2"}}), blank(1),
                                       node(NodeType::Paragraph, {text("fetch first")})});
  const ParseResult result = fromAst(ast);
  CHECK(result.plainText == u"Rebase\n\nfetch first");
  CHECK(describe(result.blockRanges) == "h2:0-6/2 ");

  auto broken = node(NodeType::Document, {node(NodeType::Heading, {text("broken")}, {{"level", "9"}})});
  CHECK(fromAst(broken).plainText == u"broken");
  CHECK(fromAst(broken).blockRanges.empty());
}

TEST_CASE("AST: list items get first-line bounds and AST-derived depths") {
  // - stack
  //    - review
  // 1. merge   (separate list, so a fresh ordered container)
  auto ast =
      node(NodeType::Document,
           {node(NodeType::UnorderedList,
                 {node(NodeType::ListItem,
                       {text("stack"), node(NodeType::UnorderedList, {node(NodeType::ListItem, {text("review")})})})}),
            blank(1), node(NodeType::OrderedList, {node(NodeType::ListItem, {text("merge")})})});
  const ParseResult result = fromAst(ast);
  CHECK(result.plainText == u"stack\nreview\n\nmerge");
  // Ranges are emitted on node exit, so a nested item precedes its parent; the
  // result is sorted by start on the way out.
  CHECK(describe(result.blockRanges) == "ul:0-5/0 ul:6-12/1 ol:14-19/0 ");
}

TEST_CASE("AST: each blank source line is an empty line between blocks") {
  // Three blank lines after "a", one after "b", none before the heading.
  auto ast = node(NodeType::Document,
                  {node(NodeType::Paragraph, {text("a")}), blank(3), node(NodeType::Paragraph, {text("b")}), blank(1),
                   node(NodeType::Paragraph, {text("c")}), node(NodeType::Heading, {text("d")}, {{"level", "1"}})});
  CHECK(fromAst(ast).plainText == u"a\n\n\n\nb\n\nc\nd");
}

TEST_CASE("AST: blank lines before the first block and after the last are dropped") {
  auto ast = node(NodeType::Document, {blank(2), node(NodeType::Paragraph, {text("a")}), blank(2)});
  CHECK(fromAst(ast).plainText == u"a");
}

TEST_CASE("AST: blank lines between list items stay where they stood") {
  auto ast = node(
      NodeType::Document,
      {node(NodeType::UnorderedList, {node(NodeType::ListItem, {node(NodeType::Paragraph, {text("a")}), blank(2)}),
                                      node(NodeType::ListItem, {node(NodeType::Paragraph, {text("b")}), blank(1)})}),
       node(NodeType::Paragraph, {text("c")})});
  const ParseResult result = fromAst(ast);
  CHECK(result.plainText == u"a\n\n\nb\n\nc");
  CHECK(describe(result.blockRanges) == "ul:0-1/0 ul:4-5/0 ");
}

TEST_CASE("AST: an empty item's own line is not a blank one") {
  // "- \n\n- b": md4c reports the empty item's line and the blank line after it
  // as one run of two, first in the item.
  auto ast =
      node(NodeType::Document,
           {node(NodeType::UnorderedList, {node(NodeType::ListItem, {blank(2)}),
                                           node(NodeType::ListItem, {node(NodeType::Paragraph, {text("b")})})})});
  const ParseResult result = fromAst(ast);
  CHECK(result.plainText == u"\n\nb");
  CHECK(describe(result.blockRanges) == "ul:0-0/0 ul:2-3/0 ");
}

TEST_CASE("AST: a blank line above a nested item is dropped rather than de-nesting it") {
  auto ast = node(NodeType::Document,
                  {node(NodeType::UnorderedList,
                        {node(NodeType::ListItem,
                              {node(NodeType::Paragraph, {text("a")}),
                               node(NodeType::UnorderedList,
                                    {node(NodeType::ListItem, {node(NodeType::Paragraph, {text("b")}), blank(1)}),
                                     node(NodeType::ListItem, {node(NodeType::Paragraph, {text("c")})})})})})});
  CHECK(fromAst(ast).plainText == u"a\nb\nc");
}

TEST_CASE("AST: soft and hard breaks are newlines") {
  auto ast =
      node(NodeType::Document, {node(NodeType::Paragraph, {text("pull"), node(NodeType::SoftBreak), text("push")})});
  CHECK(fromAst(ast).plainText == u"pull\npush");
}

TEST_CASE("AST: a list starts on the top-level break without an extra newline") {
  auto ast = node(NodeType::Document,
                  {node(NodeType::Paragraph, {text("intro")}), blank(1),
                   node(NodeType::UnorderedList,
                        {node(NodeType::ListItem, {node(NodeType::Paragraph, {text("fetch")})}),
                         node(NodeType::ListItem, {node(NodeType::Paragraph, {text("merge")}), blank(2)})}),
                   node(NodeType::Paragraph, {text("done")})});
  const ParseResult result = fromAst(ast);
  CHECK(result.plainText == u"intro\n\nfetch\nmerge\n\n\ndone");
  CHECK(describe(result.blockRanges) == "ul:7-12/0 ul:13-18/0 ");
}

TEST_CASE("AST: an item's further paragraphs go on their own lines") {
  auto ast = node(
      NodeType::Document,
      {node(NodeType::UnorderedList, {node(NodeType::ListItem, {node(NodeType::Paragraph, {text("fetch")}), blank(1),
                                                                node(NodeType::Paragraph, {text("then rebase")})}),
                                      node(NodeType::ListItem, {node(NodeType::Paragraph, {text("push")})})})});
  const ParseResult result = fromAst(ast);
  CHECK(result.plainText == u"fetch\n\nthen rebase\npush");
  CHECK(describe(result.blockRanges) == "ul:0-5/0 ul:19-23/0 ");
}

TEST_CASE("AST: an item's range ends at a soft break inside its paragraph") {
  auto ast = node(NodeType::Document,
                  {node(NodeType::UnorderedList,
                        {node(NodeType::ListItem, {node(NodeType::Paragraph, {text("fetch"), node(NodeType::SoftBreak),
                                                                              text("then rebase")})})})});
  const ParseResult result = fromAst(ast);
  CHECK(result.plainText == u"fetch\nthen rebase");
  CHECK(describe(result.blockRanges) == "ul:0-5/0 ");
}

TEST_CASE("AST: an empty item is a zero-length range on its own line") {
  auto ast =
      node(NodeType::Document,
           {node(NodeType::OrderedList,
                 {node(NodeType::ListItem, {node(NodeType::Paragraph, {text("fetch")})}), node(NodeType::ListItem),
                  node(NodeType::ListItem, {node(NodeType::Paragraph, {text("push")})})})});
  const ParseResult result = fromAst(ast);
  CHECK(result.plainText == u"fetch\n\npush");
  CHECK(describe(result.blockRanges) == "ol:0-5/0 ol:6-6/0 ol:7-11/0 ");
}

TEST_CASE("AST: a document nested past the walk limit is refused, not recursed into") {
  Node inner = text("x");
  for (int i = 0; i < 2000; i++) {
    inner = node(NodeType::Blockquote, {inner});
  }
  ParseResult result;
  CHECK_FALSE(parseResultFromAst(*node(NodeType::Document, {inner}), result));
}

TEST_CASE("parse: empty input") {
  const ParseResult result = parse(u"");
  CHECK(result.plainText.empty());
  CHECK(result.formattingRanges.empty());
  CHECK(result.blockRanges.empty());
}

TEST_CASE("parse: an unclosed delimiter stays literal text") {
  CHECK(textOf("**force push") == "**force push");
  CHECK(parseUtf8("**force push").formattingRanges.empty());
  CHECK(textOf("use snake_case here") == "use snake_case here");
  CHECK(textOf("2*3 = 6") == "2*3 = 6");
  CHECK(textOf("see [docs") == "see [docs");
  CHECK(textOf("## Title [wip") == "Title [wip");
  const ParseResult list = parseUtf8("- a\n- b\n- c [");
  CHECK(list.plainText == u"a\nb\nc [");
  CHECK(describe(list.blockRanges) == "ul:0-1/0 ul:2-3/0 ul:4-7/0 ");
}

TEST_CASE("parse: escapes and entities decode to text") {
  CHECK(textOf("x\\*y") == "x*y");
  CHECK(textOf("&amp; &copy; &#65; &nope;") == "& \xC2\xA9 A &nope;");
  CHECK(textOf("2 \\*x\\* 6") == "2 *x* 6");
  CHECK(textOf("- \\> x") == "> x");
  CHECK(textOf("## Use \\#") == "Use #");
}

TEST_CASE("parse: offsets count UTF-16 units") {
  // The emoji is two units, so the bold run after it starts at 3.
  ParseResult result = parseUtf8("\xF0\x9F\x98\x80 **\xF0\x9F\x98\x80** end");
  CHECK(result.plainText == u"\U0001F600 \U0001F600 end");
  CHECK(describe(result.formattingRanges) == "strong:3-5 ");

  result = parseUtf8("\xE6\x97\xA5\xE6\x9C\xAC *x* \xF0\x9F\x87\xB5\xF0\x9F\x87\xB1 [l](http://u)");
  CHECK(describe(result.formattingRanges) == "em:3-4 link:10-11(http://u) ");
  CHECK(describe(result.blockRanges).empty());
}

TEST_CASE("parse: block ranges") {
  ParseResult result = parseUtf8("# Head\nbody\n\n- a\n  - b\n1. c");
  CHECK(result.plainText == u"Head\nbody\n\na\nb\nc");
  CHECK(describe(result.blockRanges) == "h1:0-4/1 ul:11-12/0 ul:13-14/1 ol:15-16/0 ");

  result = parseUtf8("###### six\n### three");
  CHECK(describe(result.blockRanges) == "h6:0-3/6 h3:4-9/3 ");
}

TEST_CASE("parse: ordered items are numbered from one, whatever the source says") {
  ParseResult result = parseUtf8("9. a\n   - b");
  CHECK(result.plainText == u"a\nb");
  CHECK(describe(result.blockRanges) == "ol:0-1/0 ul:2-3/1 ");
  CHECK(result.blockRanges[0].ordinal == 1);

  result = parseUtf8("5. a\n6. b\n   1. c\n   2. d\n7. e\n\n1. f");
  REQUIRE(result.blockRanges.size() == 6);
  const uint32_t expected[] = {1, 2, 1, 2, 3, 1};
  for (size_t i = 0; i < 6; i++) {
    CHECK_MESSAGE(result.blockRanges[i].ordinal == expected[i], "item " << i);
  }
}

TEST_CASE("parse: an empty list item is a zero-length range") {
  ParseResult result = parseUtf8("- a\n- \n- c");
  CHECK(result.plainText == u"a\n\nc");
  CHECK(describe(result.blockRanges) == "ul:0-1/0 ul:2-2/0 ul:3-4/0 ");

  result = parseUtf8("1. a\n2. \n3. c");
  REQUIRE(result.blockRanges.size() == 3);
  CHECK(result.blockRanges[2].ordinal == 3);

  // An empty heading is dropped on import.
  CHECK(parseUtf8("# ").plainText.empty());
  CHECK(parseUtf8("# ").blockRanges.empty());
}

TEST_CASE("parse: blank lines are empty lines") {
  CHECK(textOf("a\n\nb") == "a\n\nb");
  CHECK(textOf("git fetch\n\n\n\ngit merge") == "git fetch\n\n\n\ngit merge");
  CHECK(textOf("\n\na\n\n") == "a");
  CHECK(textOf("- a\n\n- b") == "a\n\nb");
  CHECK(textOf("- a\n  - b\n\n  - c") == "a\nb\nc");
}

TEST_CASE("parse: syntax the input has no model for loses its markers") {
  CHECK(textOf("> quote") == "quote");
  CHECK(textOf("> quote\n> more") == "quote\nmore");
  CHECK(textOf("| a | b |\n| - | - |\n| 1 | 2 |") == "ab12");
  CHECK(textOf("---") == "");
  CHECK(textOf("a\n\n---\n\nb") == "a\n\n\n\nb");
  CHECK(textOf("`inline code`") == "inline code");
  CHECK(textOf("```\ncode\n```") == "code");
  CHECK(textOf("```js\nconst a = 1;\n```") == "const a = 1;");
  CHECK(textOf("```\ncode\n```\nafter") == "code\nafter");
  CHECK(textOf("a\n\n```\nx\ny\n```\n\nb") == "a\n\nx\ny\n\nb");
  CHECK(textOf("$$x^2$$") == "$$x^2$$"); // latexMath is off
  CHECK(textOf("![alt](u)") == "alt");
  CHECK(textOf("bare https://git-scm.com stays plain text") == "bare https://git-scm.com stays plain text");
}

TEST_CASE("parse: leading whitespace is kept as text") {
  CHECK(textOf("\tfoo") == "\tfoo");
  CHECK(textOf("  foo") == "  foo");
  CHECK(textOf("    foo") == "    foo");
  CHECK(textOf("\t\tfoo\nbar") == "\t\tfoo\nbar");
  CHECK(textOf("a\n\tb") == "a\n\tb");
  CHECK(textOf("a\n\n    b") == "a\n\n    b");
  CHECK(textOf("    \\- x\n\t\\# y\n      1\\. z") == "    - x\n\t# y\n      1. z");
  // The whitespace after a marker is the item's text.
  ParseResult result = parseUtf8("1.  x");
  CHECK(result.plainText == u" x");
  CHECK(describe(result.blockRanges) == "ol:0-2/0 ");
  result = parseUtf8("-   foo\n# \tbar");
  CHECK(result.plainText == u"  foo\n\tbar");
  CHECK(describe(result.blockRanges) == "ul:0-5/0 h1:6-10/1 ");
  // Structure stays structure, and a whitespace-only line is still blank.
  result = parseUtf8("- a\n  - b\n   - c");
  CHECK(result.plainText == u"a\nb\nc");
  CHECK(describe(result.blockRanges) == "ul:0-1/0 ul:2-3/1 ul:4-5/1 ");
  CHECK(textOf("a\n   \nb") == "a\n\nb");
  result = parseUtf8("  **bold**");
  CHECK(result.plainText == u"  bold");
  CHECK(describe(result.formattingRanges) == "strong:2-6 ");
  // A line ending in a carriage return is left as it is, as in the reference.
  CHECK(textOf("a\n  b\r\nc") == "a\nb\nc");
}

TEST_CASE("normalization: a setext heading over two lines is one heading per line") {
  const ParseResult result = parseUtf8("Foo\nbar\n===");
  CHECK(result.plainText == u"Foo\nbar");
  CHECK(describe(result.blockRanges) == "h1:0-3/1 h1:4-7/1 ");
}

TEST_CASE("normalization: the list item of a heading inside one is kept") {
  ParseResult result = parseUtf8("- # foo");
  CHECK(result.plainText == u"foo");
  CHECK(describe(result.blockRanges) == "ul:0-3/0 ");
  result = parseUtf8("1. # h\n2. x");
  CHECK(describe(result.blockRanges) == "ol:0-1/0 ol:2-3/0 ");
}

TEST_CASE("normalization: nested same-type styles merge") {
  CHECK(describe(parseUtf8("**foo **bar** baz**").formattingRanges) == "strong:0-11 ");
}

TEST_CASE("normalization: touching links merge only when their urls match") {
  CHECK(describe(parseUtf8("[a](x)[b](x)").formattingRanges) == "link:0-2(x) ");
  CHECK(describe(parseUtf8("[a](x)[b](y)").formattingRanges) == "link:0-1(x) link:1-2(y) ");
}

TEST_CASE("normalization: styles of other types and separate same-type styles are left alone") {
  CHECK(describe(parseUtf8("*a* *b* **c**").formattingRanges) == "em:0-1 em:2-3 strong:4-5 ");
}

namespace {
FormattingRange range(StyleType type, uint32_t start, uint32_t end) {
  FormattingRange r;
  r.type = type;
  r.start = start;
  r.end = end;
  return r;
}
BlockRange block(BlockType type, uint32_t start, uint32_t end, uint8_t level = 0) {
  BlockRange b;
  b.type = type;
  b.start = start;
  b.end = end;
  b.level = level;
  return b;
}
} // namespace

TEST_CASE("normalizeBlockRanges: a block spanning lines is copied onto each, at line bounds") {
  const auto result = normalizeBlockRanges(u"ab\ncd\n", {block(BlockType::H2, 0, 5, 2)});
  CHECK(describe(result) == "h2:0-2/2 h2:3-5/2 ");
}

TEST_CASE("normalizeBlockRanges: a zero-length anchor stays on its empty line") {
  const auto result = normalizeBlockRanges(u"a\n\nb", {block(BlockType::UnorderedListItem, 2, 2)});
  CHECK(describe(result) == "ul:2-2/0 ");
}

TEST_CASE("normalizeBlockRanges: a list item wins over a heading over a paragraph on one line") {
  const auto result =
      normalizeBlockRanges(u"ab", {block(BlockType::Paragraph, 0, 2), block(BlockType::H1, 0, 2, 1),
                                   block(BlockType::OrderedListItem, 0, 2), block(BlockType::H3, 0, 2, 3)});
  CHECK(describe(result) == "ol:0-2/0 ");
}

TEST_CASE("normalizeFormattingRanges: merges overlapping and touching same-type ranges, sorted by start") {
  const auto result = normalizeFormattingRanges({range(StyleType::Strong, 4, 7), range(StyleType::Em, 1, 2),
                                                 range(StyleType::Strong, 0, 4), range(StyleType::Strong, 6, 9),
                                                 range(StyleType::Strong, 11, 12)});
  CHECK(describe(result) == "strong:0-9 em:1-2 strong:11-12 ");
}

TEST_CASE("normalizeFormattingRanges: empty ranges are dropped") {
  CHECK(normalizeFormattingRanges({range(StyleType::Em, 3, 3)}).empty());
}

TEST_CASE("normalizeListMetadata: depths clamp to one below the adjacent item, ordinals count the run") {
  std::vector<BlockRange> blocks = {
      block(BlockType::OrderedListItem, 0, 1, 3), // starts a run: depth 0
      block(BlockType::OrderedListItem, 2, 3, 0), block(BlockType::UnorderedListItem, 4, 5, 4),
      block(BlockType::OrderedListItem, 7, 8, 1), // a gap: a new run, depth 0
  };
  normalizeListMetadata(blocks);
  CHECK(describe(blocks) == "ol:0-1/0 ol:2-3/0 ul:4-5/1 ol:7-8/0 ");
  CHECK(blocks[0].ordinal == 1);
  CHECK(blocks[1].ordinal == 2);
  CHECK(blocks[3].ordinal == 1);
}
