// Cases where the port deliberately differs from the reference, plus the
// md4c extensions it has no counterpart for. Every behaviour asserted here is
// listed in the MarkdownRepair.hpp header; the recorded reference cases that
// changed because of it are marked `// ours` in ReferenceCases.cpp.
#include <string>

#include "RepairInternal.hpp"
#include "doctest/doctest.h"

using namespace Markdown;

namespace {
std::string repair(std::string_view s, const RepairOptions &o = RepairOptions()) {
  return repairInlineMarkdown(s, o);
}
} // namespace

TEST_CASE("constructs opened before a placeholder link are still closed") {
  // The reference stops the pipeline after the placeholder (our divergence).
  CHECK(repair("**bold [link") == "**bold [link](streamdown:incomplete-link)**");
  CHECK(repair("*a [b](http://x") == "*a [b](streamdown:incomplete-link)*");
  CHECK(repair("[**bold link") == "[**bold link**](streamdown:incomplete-link)");
  CHECK(repair("see [a *b") == "see [a *b*](streamdown:incomplete-link)");
  CHECK(repair("`code [not a link") == "`code [not a link`");
  RepairOptions o;
  o.linkMode = LinkMode::TextOnly;
  CHECK(repair("**bold [link", o) == "**bold link**");
}

TEST_CASE("brackets that are not links") {
  CHECK(repair("- [") == "- [");
  CHECK(repair("- [ ") == "- ["); // trailing space trimmed as usual
  CHECK(repair("- [x") == "- [x");
  CHECK(repair("1. [ ] todo **b") == "1. [ ] todo **b**");
  CHECK(repair("- [link") == "- [link](streamdown:incomplete-link)");
  CHECK(repair("> [!NO") == "> [!NO");
  CHECK(repair("> [!NOTE]\n> text **b") == "> [!NOTE]\n> text **b**");
  CHECK(repair("note[^1") == "note[^1");
  CHECK(repair("[text][re") == "[text][re");
  CHECK(repair("see [x") == "see [x](streamdown:incomplete-link)");
}

TEST_CASE("md4c extensions") {
  CHECK(repair("||hidden") == "||hidden||");
  CHECK(repair("||a|| and ||b") == "||a|| and ||b||");
  CHECK(repair("| a | b") == "| a | b"); // single pipes are tables, not spoilers
  RepairOptions o;
  o.highlight = o.superscript = o.subscript = true;
  CHECK(repair("==mark", o) == "==mark==");
  CHECK(repair("x^2", o) == "x^2^");
  CHECK(repair("x^ 2", o) == "x^ 2"); // an opener before whitespace is literal
  CHECK(repair("H~2", o) == "H~2~");
  CHECK(repair("H~2~O and ~~s", o) == "H~2~O and ~~s~~");
  CHECK(repair("20~25", o) == "20~25~"); // subscript on: no single-tilde escape
  CHECK(repair("20~25") == "20\\~25");   // subscript off: reference behaviour
  CHECK(repair("`x^2`", o) == "`x^2`");
}

TEST_CASE("openers in an earlier block are left alone") {
  CHECK(repair("**Note\n\nNext paragraph") == "**Note\n\nNext paragraph");
  CHECK(repair("**a\n \n_b") == "**a\n \n_b_"); // a whitespace-only line is blank; only the last opener closes
  CHECK(repair("## **Setup\nSome text") == "## **Setup\nSome text");
  CHECK(repair("## **Setup") == "## **Setup**");
  CHECK(repair("[link\n\nmore") == "[link\n\nmore");
  CHECK(repair("$$\nx\n\ny") == "$$\nx\n\ny");
  CHECK(repair("**a\nb") == "**a\nb**"); // a soft break stays inside the paragraph
}

TEST_CASE("line endings") {
  CHECK(repair("**b\r\n") == "**b**\r\n");
  CHECK(repair("**b\r\n\r\n") == "**b**\r\n\r\n");
}

TEST_CASE("full pipeline: mixed") {
  CHECK(repair("This is **bold with *ital") == "This is **bold with *ital***");
  // Closers nest in reverse opening order (our divergence from the reference).
  CHECK(repair("Text **bold `code") == "Text **bold `code`**");
  CHECK(repair("**bold ~~strike") == "**bold ~~strike~~**");
  CHECK(repair("~~strike with **bold") == "~~strike with **bold**~~");
  CHECK(repair("$$\nx\n") == "$$\nx\n$$\n");
  CHECK(repair("$$a\nb$$ $$c") == "$$a\nb$$ $$c$$"); // only the open block decides single- vs multi-line
  CHECK(repair("**bold\n") == "**bold**\n");
  CHECK(repair("**a `b\n\n") == "**a `b`**\n\n");
  CHECK(repair("~~s **b *i\n") == "~~s **b *i***~~\n");
  CHECK(repair("`g **c") == "`g **c`"); // ** inside an open code span is code, not emphasis
  CHECK(repair("| a | b |\n|---|---|\n| **x") == "| a | b |\n|---|---|\n| **x**");
}

// The italic closer is anchored at the open marker, not the first `*`/`_` in
// the text, so an italic in an earlier paragraph does not disable repair later.
TEST_CASE("italic closer is anchored at the open marker") {
  CHECK(repair("This is *important*.\n\nNext *point") == "This is *important*.\n\nNext *point*");
  CHECK(repair("This is _important_.\n\nNext _point") == "This is _important_.\n\nNext _point_");
  CHECK(repair("# *Title*\nsome *text") == "# *Title*\nsome *text*");
  CHECK(repair("_ x **y _z") == "_ x **y _z_**");
}

// An escaped `\[` is not a link opener. LLMs stream `\[ … \]` for display math.
TEST_CASE("an escaped bracket is not a link") {
  CHECK(repair("Solve \\[ x^2 + y^2") == "Solve \\[ x^2 + y^2");
  CHECK(repair("see \\[a](http://x") == "see \\[a](http://x");
  RepairOptions o;
  o.linkMode = LinkMode::TextOnly;
  CHECK(repair("Solve \\[ x^2", o) == "Solve \\[ x^2");
}

// Math closers are anchored at the counted opener, never at half of a `$$`,
// an escaped `\$` or a `$$` inside inline code.
TEST_CASE("math closers are anchored at their opener") {
  RepairOptions o;
  o.inlineMath = true;
  CHECK(repair("It costs $5.\n\nThe formula $$x^2$$", o) == "It costs $5.\n\nThe formula $$x^2$$");
  CHECK(repair("$a **b \\$5", o) == "$a **b \\$5$"); // `**` inside math is not a delimiter
  CHECK(repair("$$a\n\n`$$` b") == "$$a\n\n`$$` b");
  CHECK(repair("$$a **b `$$`") == "$$a **b `$$`$$");
}

// A CRLF blank line is a block boundary, like an LF one.
TEST_CASE("a CRLF blank line is a block boundary") {
  CHECK(repair("**a\r\n\r\nb") == "**a\r\n\r\nb");
  CHECK(repair("[link\r\n\r\nmore") == "[link\r\n\r\nmore");
}

// The underscore counter applies the open/close flanking rule the reference
// does not have.
TEST_CASE("underscore flanking rule, pinned") {
  CHECK(repair("_a_ b_") == "_a_ b_"); // reference: _a_ b__
  CHECK(repair("_  b") == "_  b");     // reference: _  b_
}

// The task-list check matches a checkbox only, not any link text starting with x.
TEST_CASE("task-list check only matches a checkbox") {
  CHECK(repair("- [Xcode setup") == "- [Xcode setup](streamdown:incomplete-link)");
  CHECK(repair("- [x") == "- [x");
}

// A fence, heading or list item after the opener ends its paragraph like a
// blank line does. The reference has the same gap.
TEST_CASE("a fence or heading after the opener is a block boundary") {
  CHECK(repair("**a\n```\ncode") == "**a\n```\ncode");
  CHECK(repair("**a\n# heading") == "**a\n# heading");
}

// Handlers that erase rather than close apply the same block rule: a
// construct left open in an earlier block is literal, not a reason to drop
// everything after it.
TEST_CASE("erase paths stop at a block boundary") {
  CHECK(repair("[a](http://x\n\nmore") == "[a](http://x\n\nmore");
  CHECK(repair("![alt](http://x\n\nmore") == "![alt](http://x\n\nmore");
  CHECK(repair("pic ![alt\n\nmore") == "pic ![alt\n\nmore");
  CHECK(repair("<video src=\"x\n\nmore") == "<video src=\"x\n\nmore");
  CHECK(repair("<a\n\n<video src=\"x") == "<a");
  CHECK(repair("[a](http://x\n\n[b") == "[a](http://x\n\n[b](streamdown:incomplete-link)");
  CHECK(repair("[a](http://x\nmore") ==
        "[a](streamdown:incomplete-link)"); // same paragraph: still the reference's rule
  RepairOptions o;
  o.linkMode = LinkMode::TextOnly;
  CHECK(repair("[a\n\n[b", o) == "[a\n\nb");
  CHECK(repair("[a](http://x\n\nmore", o) == "[a](http://x\n\nmore");
}

TEST_CASE("tilde fences are code") {
  CHECK(repair("~~~\nx **b") == "~~~\nx **b");
  CHECK(repair("~~~js\nx `y") == "~~~js\nx `y");
  CHECK(repair("~~~\nx\n~~~\n**b") == "~~~\nx\n~~~\n**b**");
  CHECK(repair("  ~~~\n  x **b") == "  ~~~\n  x **b");
  CHECK(repair("```\n~~~\n```\n**b") == "```\n~~~\n```\n**b**"); // a tilde line inside a backtick fence is content
  CHECK(repair("~~~\n```\n~~~\n**b") == "~~~\n```\n~~~\n**b**");
  CHECK(repair("a~~~b ~~c") == "a~~~b ~~c"); // mid-line tildes are not a fence
}

TEST_CASE("double markers inside math or a fence are not delimiters") {
  CHECK(repair("$$ a ** b") == "$$ a ** b$$");
  CHECK(repair("$$ a __b") == "$$ a __b$$");
  CHECK(repair("$$ a ~~b") == "$$ a ~~b$$");
  CHECK(repair("**x** $$ a ** b") == "**x** $$ a ** b$$");
  CHECK(repair("```\n~~a\n```\n~~b") == "```\n~~a\n```\n~~b~~");
}

TEST_CASE("blocks that interrupt a paragraph") {
  CHECK(repair("**a\n> quote") == "**a\n> quote");
  CHECK(repair("> **a\n> b") == "> **a\n> b**");
  CHECK(repair("> **a\nb") == "> **a\nb**"); // lazy continuation
  CHECK(repair("> **a\n>\n> b") == "> **a\n>\n> b");
  CHECK(repair("**a\n---") == "**a\n---");
  CHECK(repair("**a\n* * *") == "**a\n* * *");
  CHECK(repair("**a\n2. b") == "**a\n2. b");
  CHECK(repair("**a\n-") == "**a\n-\xE2\x80\x8B**"); // a bare `-` is a setext underline, kept inside the paragraph
}

TEST_CASE("a lone dollar is currency unless inline math is on") {
  CHECK(repair("It costs $5 and **bold") == "It costs $5 and **bold**");
  CHECK(repair("It costs $5 and ~~gone") == "It costs $5 and ~~gone~~");
  CHECK(repair("It costs $5 and *it") == "It costs $5 and *it*"); // the reference left this open
  CHECK(repair("$$ a ** b") == "$$ a ** b$$");                    // display math is always math
  RepairOptions o;
  o.inlineMath = true;
  CHECK(repair("$a **b", o) == "$a **b$");
  CHECK(repair("costs $5 and **bold", o) == "costs $5 and **bold$"); // ambiguous by design: the `$` opened math
}

TEST_CASE("blockquote depth is the block's, not the previous line's") {
  CHECK(repair("> **a\nb\n> c") == "> **a\nb\n> c**"); // lazy continuation, then the quote resumes
  CHECK(repair("> **a\n> > c") == "> **a\n> > c");
  CHECK(repair("> ~~~\n> x **b") == "> ~~~\n> x **b");
}

TEST_CASE("text-only link repair skips brackets that can no longer close") {
  RepairOptions o;
  o.linkMode = LinkMode::TextOnly;
  CHECK(repair("# [a\n[b", o) == "# [a\nb");
}

TEST_CASE("inline code parity ignores backticks inside a closed fence") {
  CHECK(repair("~~~\n`\n~~~\n`b") == "~~~\n`\n~~~\n`b`");
  CHECK(repair("```\n`\n```\n`b") == "```\n`\n```\n`b`");
}

TEST_CASE("a setext `=` underline ends the paragraph") {
  CHECK(repair("**a\n===") == "**a\n===");
  CHECK(repair("**a\n=\nb") == "**a\n=\nb");
}
