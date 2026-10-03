// Hand-written cases for the repair module. ReferenceCases.cpp covers parity
// with the reference implementation; these pin the behaviours we care about
// by name so a regression points at the handler, not at "case 412".
#include <string>

#include "RepairInternal.hpp"
#include "doctest/doctest.h"

using namespace Markdown;

namespace {

std::string repair(std::string_view s, const RepairOptions &o = RepairOptions()) {
  return repairInlineMarkdown(s, o);
}

using RepairInternal::RepairContext;

// Runs one handler on its own context and returns the resulting text.
template <class Handler> auto handler(Handler h) {
  return [h](std::string_view s) {
    std::string text(s);
    RepairContext ctx(text);
    h(ctx);
    return text;
  };
}

const auto linksProtocol = handler([](RepairContext &c) { RepairHandlers::links(c, LinkMode::Protocol); });
const auto linksTextOnly = handler([](RepairContext &c) { RepairHandlers::links(c, LinkMode::TextOnly); });

} // namespace

TEST_CASE("pipeline: trailing single space is dropped, double space kept") {
  CHECK(repair("hello ") == "hello");
  CHECK(repair("hello  ") == "hello  ");
  CHECK(repair("") == "");
}

TEST_CASE("bold") {
  auto bold = handler(RepairHandlers::bold);
  CHECK(bold("**bold") == "**bold**");
  CHECK(bold("**bold*") == "**bold**");
  CHECK(bold("**bold**") == "**bold**");
  CHECK(bold("**") == "**");
  CHECK(bold("` **bold`") == "` **bold`");
  CHECK(bold("```\n**bold\n") == "```\n**bold\n");
  CHECK(bold("- item\n**bold\nmore") == "- item\n**bold\nmore**");
  CHECK(bold("**bold\n\n") == "**bold**\n\n"); // closers go before trailing newlines
  // Bold closes even when an italic is nested inside (our divergence).
  CHECK(repair("**bold *ital") == "**bold *ital***");
  CHECK(repair("**a *b* c") == "**a *b* c**");
  CHECK(repair("**a *b* c*") == "**a *b* c**"); // trailing * is half of the closer
  CHECK(repair("2**3 = 8") == "2**3 = 8**");    // same as the reference: ** between digits can open
  CHECK(bold("***") == "***");                  // horizontal rule, not bold
}

TEST_CASE("italic") {
  auto asterisk = handler(RepairHandlers::italicSingleAsterisk);
  auto underscore = handler(RepairHandlers::italicSingleUnderscore);
  auto doubleUnderscore = handler(RepairHandlers::italicDoubleUnderscore);
  CHECK(asterisk("*it") == "*it*");
  CHECK(asterisk("hello*world") == "hello*world");
  CHECK(asterisk("* item") == "* item");
  CHECK(asterisk("2 * 3") == "2 * 3");
  CHECK(underscore("_it") == "_it_");
  CHECK(underscore("snake_case") == "snake_case");
  CHECK(underscore("_it\n\n") == "_it_\n\n");
  CHECK(repair("**bold _und") == "**bold _und_**");
  CHECK(underscore("**bold _und**") == "**bold _und**_"); // literal: nothing to nest into
  CHECK(doubleUnderscore("__it") == "__it__");
  CHECK(doubleUnderscore("__it_") == "__it__");
  CHECK(repair("__bold _ital") == "__bold _ital___"); // parity, like bold (our divergence)
  CHECK(repair("__b _i_") == "__b _i___");            // trailing _ closed the italic, so bold still needs __
  CHECK(repair("__b _i_ c_") == "__b _i_ c__");       // trailing _ is half of the closer
}

TEST_CASE("bold italic") {
  auto boldItalic = handler(RepairHandlers::boldItalic);
  CHECK(boldItalic("***x") == "***x***");
  CHECK(boldItalic("****") == "****");
  CHECK(boldItalic("**bold and *italic***") == "**bold and *italic***");
}

TEST_CASE("inline code") {
  auto inlineCode = handler(RepairHandlers::inlineCode);
  CHECK(inlineCode("`code") == "`code`");
  CHECK(inlineCode("`code`") == "`code`");
  CHECK(inlineCode("```js\ncode") == "```js\ncode");
  CHECK(inlineCode("```code``") == "```code```");
  CHECK(inlineCode("\\`not code") == "\\`not code");
}

TEST_CASE("strikethrough and single tilde") {
  auto strikethrough = handler(RepairHandlers::strikethrough);
  auto singleTilde = handler(RepairHandlers::singleTilde);
  CHECK(strikethrough("~~gone") == "~~gone~~");
  CHECK(strikethrough("~~gone~") == "~~gone~~");
  CHECK(singleTilde("20~25") == "20\\~25");
  CHECK(singleTilde("a~~b") == "a~~b");
  CHECK(singleTilde("`20~25`") == "`20~25`");
  CHECK(singleTilde("温~度") == "温\\~度"); // Unicode letters
  CHECK(singleTilde("a~b~c") == "a\\~b\\~c");
}

TEST_CASE("links and images") {
  CHECK(linksProtocol("[text](http://x") == "[text](streamdown:incomplete-link)");
  CHECK(linksTextOnly("[text](http://x") == "text");
  CHECK(linksProtocol("see [text") == "see [text](streamdown:incomplete-link)");
  CHECK(linksTextOnly("see [text") == "see text");
  CHECK(linksProtocol("![alt](http://x") == "");
  CHECK(linksProtocol("pic ![alt") == "pic ");
  CHECK(linksTextOnly("[a](b) and [c") == "[a](b) and c");
  CHECK(linksProtocol("`[not a link`") == "`[not a link`");
}

TEST_CASE("math") {
  auto displayMath = handler(RepairHandlers::displayMath);
  auto inlineMath = handler(RepairHandlers::inlineMath);
  CHECK(displayMath("$$x") == "$$x$$");
  CHECK(displayMath("$$\nx") == "$$\nx\n$$");
  CHECK(displayMath("$$x$") == "$$x$$");
  CHECK(displayMath("`$$x`") == "`$$x`");
  CHECK(inlineMath("$x") == "$x$");
  CHECK(inlineMath("costs $5 and $6") == "costs $5 and $6");
  CHECK(repair("$$ a * b") == "$$ a * b$$"); // asterisk inside math stays
}

TEST_CASE("html tags and comparison operators") {
  auto htmlTags = handler(RepairHandlers::htmlTags);
  auto comparison = handler(RepairHandlers::comparisonOperators);
  // Only a tag that starts a line is stripped; inline `<` is prose for our parser.
  CHECK(htmlTags("text <cus") == "text <cus");
  CHECK(htmlTags("if x<y then") == "if x<y then");
  CHECK(htmlTags("text\n<video src=\"http://x") == "text");
  CHECK(htmlTags("<div") == "");
  CHECK(htmlTags("a<b\n<video src=\"x") == "a<b"); // mid-line `<` must not hide a later line-start tag
  CHECK(htmlTags("a < b") == "a < b");
  CHECK(htmlTags("```\n<cus") == "```\n<cus");
  CHECK(htmlTags("<https://exa") == ""); // a line-start autolink is hidden until its > arrives
  CHECK(comparison("- > 25: costly") == "- \\> 25: costly");
  CHECK(comparison("1. >= $5") == "1. \\>= $5");
  CHECK(comparison("- > quote") == "- > quote");
  CHECK(comparison("> 5") == "> 5");
}

TEST_CASE("setext headings") {
  auto setext = handler(RepairHandlers::setextHeadings);
  CHECK(setext("Title\n-") == "Title\n-\xE2\x80\x8B");
  CHECK(setext("Title\n--") == "Title\n--\xE2\x80\x8B");
  CHECK(setext("Title\n---") == "Title\n---");
  CHECK(setext("Title\n- ") == "Title\n- ");
  CHECK(setext("\n-") == "\n-");
  CHECK(setext("Title\n=") == "Title\n=\xE2\x80\x8B");
}

TEST_CASE("options disable individual handlers") {
  RepairOptions o;
  o.bold = false;
  CHECK(repair("**x", o) == "**x");
  o = RepairOptions();
  o.links = false;
  o.images = false;
  CHECK(repair("[x](y", o) == "[x](y");
  o = RepairOptions();
  o.links = false; // images alone keeps the handler on, as upstream
  CHECK(repair("[x](y", o) == "[x](streamdown:incomplete-link)");
}

TEST_CASE("helpers") {
  CHECK(isWordChar('a'));
  CHECK(isWordChar('_'));
  CHECK(isWordChar(0x4E2D));  // 中
  CHECK(isWordChar(0x1D400)); // 𝐀 (full code point view)
  CHECK_FALSE(isWordChar(' '));
  CHECK_FALSE(isWordChar(0x1F600)); // 😀
  CHECK_FALSE(isWordChar(kNoCodePoint));
  CHECK(isWithinCodeBlock("```\nx", 4));
  CHECK_FALSE(isWithinCodeBlock("```\nx\n```\ny", 10));
  CHECK(isWithinMathBlock("$x$ $y", 5));
  CHECK_FALSE(isWithinMathBlock("$x$ y", 4));
  CHECK(isWithinMathBlock("\\(a_b\\)", 3));
  CHECK(isWithinLinkOrImageUrl("[a](b_c)", 5));
  CHECK_FALSE(isWithinLinkOrImageUrl("(b_c)", 2));
}

TEST_CASE("unicode neighbours of markers") {
  // Word-internal detection must decode code points, not bytes.
  CHECK(repair("naïve*word") == "naïve*word");
  CHECK(repair("naïve _x") == "naïve _x_");
  CHECK(repair("日本語_テスト") == "日本語_テスト");
  // Astral characters are not word characters in the reference (UTF-16 view).
  CHECK(repair("😀*wave") == "😀*wave*");
}

TEST_CASE("in-place entry point matches the copying one") {
  std::string text = "**bold [link](http://x";
  repairInlineMarkdownInPlace(text, RepairOptions());
  CHECK(text == repair("**bold [link](http://x"));
  text = "";
  repairInlineMarkdownInPlace(text, RepairOptions());
  CHECK(text.empty());
}
