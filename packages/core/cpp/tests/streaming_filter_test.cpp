/*
 * Checks the streaming filter every host and the JS collector share: block
 * math, tables, code fences and trailing media. See scripts/test-core-parser.sh.
 */
#include "StreamingFilter.hpp"
#include <iostream>
#include <string>

namespace {

int failures = 0;

void check(bool condition, const std::string &what) {
  if (!condition) {
    std::cerr << "FAIL: " << what << "\n";
    failures++;
  }
}

using Markdown::StreamingBlockMode;
using Markdown::StreamingFilterOptions;

std::string filter(const std::string &markdown, StreamingBlockMode mediaMode = StreamingBlockMode::Progressive,
                   StreamingBlockMode tableMode = StreamingBlockMode::Progressive,
                   StreamingBlockMode codeBlockMode = StreamingBlockMode::Progressive) {
  StreamingFilterOptions options;
  options.tableMode = tableMode;
  options.codeBlockMode = codeBlockMode;
  options.mediaMode = mediaMode;
  return Markdown::renderableMarkdownForStreaming(markdown, options).markdown;
}

void expect(const std::string &markdown, const std::string &expected, const std::string &what,
            StreamingBlockMode mediaMode = StreamingBlockMode::Progressive,
            StreamingBlockMode tableMode = StreamingBlockMode::Progressive,
            StreamingBlockMode codeBlockMode = StreamingBlockMode::Progressive) {
  std::string got = filter(markdown, mediaMode, tableMode, codeBlockMode);
  check(got == expected, what + "\n  expected: [" + expected + "]\n  got:      [" + got + "]");
}

} // namespace

int main() {
  const auto H = StreamingBlockMode::Hidden;
  const auto P = StreamingBlockMode::Progressive;
  const std::string img = "![Hero](https://e.com/hero.png)";
  const std::string video = "<video src=\"https://e.com/clip.mp4\"></video>";

  // Media: partial syntax is cut in both modes.
  expect("Intro\n\n![Hero](https://e", "Intro\n\n", "partial image cut (progressive)");
  expect("Intro\n\n![Hero](https://e", "Intro\n\n", "partial image cut (hidden)", H);
  expect("Intro\n\n<video src=\"https://com", "Intro\n\n", "partial video cut");
  expect("Intro\n\n![Hero", "Intro\n\n", "image without ]( cut");
  expect("Intro\n\n!", "Intro\n\n", "lone ! may start an image");
  expect("Intro\n\n<", "Intro\n\n", "lone < may start a video or autolink");
  expect("Intro\n\n<vid", "Intro\n\n", "partial <video tag cut");
  expect("Intro\n\n<htt", "Intro\n\n", "partial <http autolink cut");
  expect("Intro\n\n<3 kyoto", "Intro\n\n<3 kyoto", "text that diverges from block syntax kept");
  expect("Intro\n\n!important", "Intro\n\n!important", "text starting with ! kept");

  // Media: complete syntax shows in progressive, waits for a blank line in hidden.
  expect("Intro\n\n" + img, "Intro\n\n" + img, "complete image kept (progressive)");
  expect("Intro\n\n" + img + "\n", "Intro\n\n" + img + "\n", "complete image with newline kept (progressive)");
  expect("Intro\n\n" + img, "Intro\n\n", "complete image withheld (hidden)", H);
  expect("Intro\n\n" + img + "\n", "Intro\n\n", "complete image withheld until blank line (hidden)", H);
  expect("Intro\n\n" + img + "\n\n", "Intro\n\n" + img + "\n\n", "blank line releases the image (hidden)", H);
  expect("Intro\n\n" + video + "\n", "Intro\n\n", "complete video withheld (hidden)", H);

  // Media: only a standalone image is a block; a paragraph starting with one is text.
  expect("Intro\n\n![icon](u) and some prose", "Intro\n\n![icon](u) and some prose", "inline-leading paragraph kept",
         H);
  // A list item is never a block slot, but its half-typed image is inline syntax and is cut.
  expect("- ![a](https://e", "- ", "list item partial image cut as inline syntax");
  expect("1. " + img, "1. " + img, "ordered list items are not media blocks", H);
  expect("> Quote\n> ![Q](https://e", "> Quote\n", "quoted partial image cut");
  expect("> > " + img, "> > " + img, "nested quote image kept (progressive)");
  expect("> " + img + "\n", "", "quoted image withheld (hidden)", H);
  expect("> Quote\n> " + img + "\n", "> Quote\n", "quoted image after text withheld (hidden)", H);
  expect(img + "\nCaption line", img + "\nCaption line", "image that is not the last line kept");
  expect(img + "\n\nAfter", img + "\n\nAfter", "image followed by text kept (hidden)", H);

  // Media composes with the other rules on the remaining text.
  expect(img + "\n$$\nE=mc", "", "image before an open math block is trailing and withheld (hidden)", H);
  expect(img + "\n$$\nE=mc", img + "\n", "image before an open math block kept (progressive)");
  expect(img + "\n```js\nlet a", img + "\n```js\nlet a", "a fence terminates the image paragraph (hidden)", H);
  expect("![a](https://e\n```js\nlet a", "```js\nlet a", "partial image before a fence cut");
  expect(img + "\n```js\nlet a", img + "\n", "hidden code fence cuts the block, image kept", H, P, H);

  // Links: a link-only paragraph is a block too; task boxes, footnotes and
  // reference definitions are not.
  const std::string link = "[Q3 report.pdf](https://e.com/q3.pdf)";
  expect("Intro\n\n[Q3 report](https://e", "Intro\n\n", "partial link cut");
  expect("Intro\n\n" + link, "Intro\n\n" + link, "complete link kept (progressive)");
  expect("Intro\n\n" + link + "\n", "Intro\n\n", "complete link withheld (hidden)", H);
  expect("See " + link, "See " + link, "link inside text kept");
  expect(link + " and more", link + " and more", "link-leading paragraph kept", H);
  expect("[ ] todo", "[ ] todo", "task box kept");
  expect("[^1]: note", "[^1]: note", "footnote kept");
  expect("[ref]: https://e.com", "[ref]: https://e.com", "reference definition kept");
  expect("Intro\n\nhttps://github.com/sof", "Intro\n\n", "a trailing bare url can still grow: withheld");
  expect("Intro\n\nhttps://github.com/sof\n", "Intro\n\n", "a bare url followed by a newline is still open");
  expect("Intro\n\nhttps://github.com/a/b\n\n", "Intro\n\nhttps://github.com/a/b\n\n",
         "a blank line releases the bare url");
  expect("Intro\n\nhttps://e.com and text", "Intro\n\nhttps://e.com and text", "a url followed by text is prose");
  expect("Intro\n\n<https://e.com/q3.pdf>", "Intro\n\n<https://e.com/q3.pdf>", "a closed autolink is complete");
  expect("Intro\n\n<https://e.com/q3", "Intro\n\n", "an open autolink is withheld");

  // Inline syntax still being typed at the tail of a paragraph is cut.
  expect("The inline ![leaf](https://e", "The inline ", "open inline image cut");
  expect("The inline ![leaf", "The inline ", "inline image without ]( cut");
  expect("See [docs](https://e", "See ", "open inline link cut");
  expect("See [docs]", "See ", "closed brackets at the very end may become a link: cut");
  expect("See [docs] now", "See [docs] now", "plain brackets in prose kept");
  expect("See [docs](https://e.com) now", "See [docs](https://e.com) now", "closed inline link kept");
  expect("Use `a[0](` here", "Use `a[0](` here", "brackets in inline code kept");
  expect("See [docs](https://e\n\nAfter", "See [docs](https://e\n\nAfter", "only the trailing paragraph is cut");
  expect("See [docs](https://e\n```js\nlet a", "See [docs](https://e\n```js\nlet a",
         "a fence terminates the paragraph: nothing to cut");
  expect("> Quote ![q](https://e", "> Quote ", "quoted inline image cut");

  // Review cases: prose that merely starts with brackets, nested parentheses,
  // autolinks followed by text, indented code, escapes and code spans.
  expect("[INFO] The operation completed", "[INFO] The operation completed", "bracketed prefix is prose", H);
  expect("[INFO] The operation completed", "[INFO] The operation completed", "bracketed prefix is prose (prog)");
  expect("![a](https://e.com/a(b)", "", "nested paren still open: cut");
  expect("![a](https://e.com/a(b))", "![a](https://e.com/a(b))", "nested paren closed: complete (progressive)");
  expect("![a](https://e.com/a(b))\n", "", "nested paren closed: withheld (hidden)", H);
  expect("[a](https://e.com \"t (x)\")", "[a](https://e.com \"t (x)\")", "title with parens: complete");
  expect("See [docs](https://e.com/a(b)", "See ", "nested paren in an open inline link: cut");
  expect("See [docs](https://e.com/a(b)) now", "See [docs](https://e.com/a(b)) now", "closed nested inline link kept");
  expect("<https://e.com> and more text", "<https://e.com> and more text", "autolink with prose is prose", H);
  expect("Intro\n\n    ![a](https://e", "Intro\n\n    ![a](https://e", "indented code is not media");
  expect("Intro\n\n    ![a](u)\n", "Intro\n\n    ![a](u)\n", "indented code is not media (hidden)", H);
  expect(">     ![a](https://e", ">     ![a](https://e", "indented code inside a quote");
  expect("Use \\[literal", "Use \\[literal", "escaped bracket is prose");
  expect("Use \\![a](https://e", "Use \\!", "an escaped bang is text, the link after it is still open");
  expect("Use ``a[0](`` here", "Use ``a[0](`` here", "double-backtick code span kept");
  expect("Use `a` and [docs](https://e", "Use `a` and ", "closed code span before an open link");
  expect("Use `a[0](` and more", "Use `a[0](` and more", "single-backtick code span kept");

  // Review cases: parentheses inside titles, pointy destinations, nested labels.
  expect("[a](u \"t(\")", "[a](u \"t(\")", "title with an unmatched paren: complete");
  expect("[a](u \"t(\")\n", "", "title with an unmatched paren: withheld (hidden)", H);
  expect("[a](u \"t )", "", "title still open: cut");
  expect("[a](u 't )", "", "single-quoted title still open: cut");
  expect("[a](u (t )", "", "parenthesised title still open: cut");
  expect("[a](u (t))", "[a](u (t))", "parenthesised title: complete");
  expect("![a](u \"t(\")", "![a](u \"t(\")", "image title with an unmatched paren: complete");
  expect("See [a](u \"t )", "See ", "inline link with an open title: cut");
  expect("[a](<u v>)", "[a](<u v>)", "pointy destination with a space: complete");
  expect("[a](<u v", "", "pointy destination still open: cut");
  expect("[a](u \"t\") after", "[a](u \"t\") after", "titled link followed by prose is prose", H);
  expect("[![thumb](u)](https://e", "", "outer link around a closed image still open: cut");
  expect("See [![thumb](u)](https://e", "See ", "inline outer link around a closed image: cut");
  expect("[![thumb](u)](v)", "[![thumb](u)](v)", "linked image: complete (progressive)");
  expect("[![thumb](u)](v)\n", "", "linked image: withheld (hidden)", H);
  expect("[a [b]](u)", "[a [b]](u)", "nested brackets in a label: complete");
  expect("[a [b]](u)\n", "", "nested brackets in a label: withheld (hidden)", H);
  expect("[a [b]](https://e", "", "nested brackets in an open label: cut");
  expect("[a [b] c", "", "label with nested brackets still open: cut");
  expect("[note] see [docs] here", "[note] see [docs] here", "two bracketed words are prose");
  expect("[a `]` b](https://e", "", "bracket in a code span inside a label: still open");

  // Review cases: the trailing paragraph, not the last line, holds the syntax.
  expect("see [the\ndocs](https://e", "see ", "label across a soft line break: cut");
  expect("> see [the\n> docs](https://e", "> see ", "quoted label across a soft line break: cut");
  expect("a `x\n[a](https://e` b", "a `x\n[a](https://e` b", "code span across lines kept");
  expect("para\n    [a](https://e", "para\n    ", "lazy continuation is not indented code");
  expect("- item\n- see [a](https://e", "- item\n- see ", "only the last list item is scanned");
  expect("# Heading [draft\nsome text after", "# Heading [draft\nsome text after",
         "a heading ends on its line: the paragraph after it is scanned");
  expect("Title [x\n=====\nnext para", "Title [x\n=====\nnext para", "a setext underline ends the block above");
  expect("Title [x\n=====", "Title [x\n=====", "a setext heading with a stray bracket is closed");
  expect("para [x\n***\nnext", "para [x\n***\nnext", "a thematic break ends the block above");
  expect("para [x\n> quoted text", "para [x\n> quoted text", "a quote interrupts the paragraph");
  expect("> a [x\n> > nested text", "> a [x\n> > nested text", "a deeper quote interrupts the paragraph");
  expect("> see [the\ndocs](https://e", "> see ", "a lazy continuation line stays in the quoted paragraph");
  expect("para [x\n<div>raw</div>", "para [x\n<div>raw</div>", "an HTML block interrupts the paragraph");
  expect("# Heading\nsee [a](https://e", "# Heading\nsee ", "the paragraph after a heading is still cut");
  expect("[x](a [b](https://e", "[x](a ", "a link after a destination found to be prose is still cut");
  expect("See [docs](https://e.com then more", "See [docs](https://e.com then more",
         "a destination followed by prose is no link");
  const std::string stray = "Note [1 " + std::string(600, 'x');
  expect(stray, stray, "a stray bracket far behind stops withholding");
  expect(stray + " [docs]", stray + " ", "a stray bracket far behind does not swallow a new label");
  expect(stray + " [docs](http", stray + " ", "a stray bracket far behind does not swallow a new link");
  expect("[a](https://e.com/`q`) then `[b` c", "[a](https://e.com/`q`) then `[b` c",
         "code spans after a skipped destination still count");
  expect("\\`x` and `[b` c", "\\`x` and `", "an escaped backtick opens no code span");

  // Review cases: references.
  expect("[r]: https://e.com\n\nSee [docs][r]", "[r]: https://e.com\n\nSee [docs][r]", "full reference kept");
  expect("[r]: https://e.com\n\n![logo][r]", "[r]: https://e.com\n\n![logo][r]", "reference image kept");
  expect("[R  x]: https://e.com\n\nSee [docs][r x]", "[R  x]: https://e.com\n\nSee [docs][r x]",
         "reference labels match case and space insensitively");
  expect("[r]: https://e.com\n\nSee [r][]", "[r]: https://e.com\n\nSee [r][]", "collapsed reference kept");
  expect("See [docs][nope]", "See [docs]", "an undefined reference may still become a link");

  // Review cases: containers and other blocks.
  expect("> ```md\n> ![a](https://e", "> ```md\n> ![a](https://e", "fence inside a quote holds code");
  check(Markdown::renderableMarkdownForStreaming("> ```md\n> ![a](https://e", {}).endsInsideOpenCodeFence,
        "quoted open fence flagged");
  expect("> ```md\n> code\n\nAfter ![a](https://e", "> ```md\n> code\n\nAfter ",
         "a quoted fence closes with its quote");
  expect("- ```md\n  ![a](https://e", "- ```md\n  ![a](https://e", "fence inside a list item holds code");
  expect("```\n$$\n```\n\nafter text\nmore", "```\n$$\n```\n\nafter text\nmore", "math marker inside a fence ignored");
  expect("> $$\n> x", "", "quoted open math cut");
  expect("<!--\n![a](https://e", "<!--\n![a](https://e", "html comment content kept");
  expect("<video\n  src=\"https://e", "", "multi-line video tag still open: cut");
  expect("Intro\n\n<video\n  src=\"u\">\n", "Intro\n\n<video\n  src=\"u\">\n",
         "multi-line video complete (progressive)");
  expect("Intro\n\n<video\n  src=\"u\">\n", "Intro\n\n", "multi-line video withheld (hidden)", H);

  // Review cases: tables without outer pipes, quoted tables.
  expect("a | b\n--|--\n1 | 2", "", "table without outer pipes withheld (hidden)", P, H);
  expect("a | b\n--|--\n1 | 2", "a | b\n--|--\n1 | 2", "table without outer pipes kept (progressive)");
  expect("a | b\n--|--\n1 ", "a | b\n--|--\n", "short row of a table without pipes trimmed");
  expect("a | b", "a | b", "a lone line with a pipe is prose", P, H);
  expect("> | a | b |\n> |---|---|\n> | 1 | 2 |", "", "quoted table withheld (hidden)", P, H);
  expect("| a | b |\n|-", "", "delimiter row with too few cells is not a table yet");

  // Pre-existing rules keep their behaviour.
  expect("A\n\n| a | b |\n|---|---|\n| 1 |", "A\n\n| a | b |\n|---|---|\n", "incomplete table row trimmed");
  expect("A\n\n| a | b |\n|---|---|\n| 1 | 2 |", "A\n\n", "table withheld (hidden)", P, H);
  expect("A\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n", "A\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n",
         "table released by blank line (hidden)", P, H);
  expect("A\n\n$$\nx", "A\n\n", "open math cut");
  expect("A\n\n$$\nx\n$$\n", "A\n\n$$\nx\n$$\n", "closed math kept");
  expect("A\n```js\nlet a", "A\n", "open fence cut (hidden)", P, P, H);
  check(Markdown::renderableMarkdownForStreaming("A\n```js\nlet a", {}).endsInsideOpenCodeFence,
        "open fence flagged (progressive)");
  check(!Markdown::renderableMarkdownForStreaming("A\n```js\nlet a\n```\n", {}).endsInsideOpenCodeFence,
        "closed fence not flagged");
  // An opening line still streaming in may grow its language: the fence waits for its newline.
  expect("A\n\n```mer", "A\n\n", "a fence whose opening line has not ended waits");
  expect("A\n\n```", "A\n\n", "a bare opening fence waits for its info string");
  expect("A\n\n```mermaid\n", "A\n\n```mermaid\n", "an ended opening line shows the fence");
  expect("> ```js", "", "a quoted opening line waits");
  // The line after a final newline has not streamed its `>` in yet, so it keeps a quoted fence open.
  for (const char *quotedFence : {"> ```js\n> let a\n", "> [!NOTE]\n> ```py\n> x\n", "> ```js\n", "> ```js\r\n> a\r\n"})
    check(Markdown::renderableMarkdownForStreaming(quotedFence, {}).endsInsideOpenCodeFence,
          std::string("a quoted fence stays open at a line end: ") + quotedFence);
  expect("> ```mermaid\n", "> ```mermaid\n", "a quoted fence shows once its opening line ends");
  expect("A\n\n> ```js\n> let a\n", "A\n\n", "a quoted open fence is cut at a line end (hidden)", P, P, H);
  check(filter("See [docs](https://e\n| a |\n```js") == filter("See [docs](https://e\n| a |\n```js", P, P, H),
        "a waiting fence is cut as a hidden one would be");
  check(!Markdown::renderableMarkdownForStreaming("A\n\n```mer", {}).endsInsideOpenCodeFence,
        "a waiting fence is not flagged");
  expect("", "", "empty input");
  expect("\r\n" + img + "\r\n", "\r\n" + img + "\r\n", "CRLF: complete image kept (progressive)");
  expect("\r\n" + img + "\r\n\r", "\r\n", "CRLF: trailing CR line is blank, image still open (hidden)", H);

  check(Markdown::streamingBlockModeFromName("hidden") == H && Markdown::streamingBlockModeFromName("x") == P,
        "mode names");

  if (failures == 0) {
    std::cout << "    streaming filter ok\n";
    return 0;
  }
  return 1;
}
