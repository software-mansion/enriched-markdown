/*
 * Checks the streaming session every host and the JS collector share: the
 * finished blocks stay as they are, the filter withholds trailing blocks and
 * repair handles inline syntax still being typed. Every prefix of the fixtures
 * filters the same as filtering it whole. See scripts/test-core-parser.sh.
 */
#include "StreamingSession.hpp"
#include <fstream>
#include <iostream>
#include <sstream>
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
using Markdown::StreamingOptions;

void expect(const std::string &markdown, const std::string &expected, const std::string &what,
            const StreamingOptions &options = {}) {
  std::string got = Markdown::streamingSnapshot(markdown, options).markdown;
  check(got == expected, what + "\n  expected: [" + expected + "]\n  got:      [" + got + "]");
}

size_t finished(const std::string &markdown) {
  return Markdown::streamingSnapshot(markdown, {}).finishedBytes;
}

std::string readFile(const std::string &path) {
  std::ifstream file(path);
  std::stringstream buffer;
  buffer << file.rdbuf();
  return buffer.str();
}

// Streams `document` one character at a time: filtering only what follows the
// finished blocks gives what filtering every prefix whole gives, and the
// finished blocks only grow. (Repair is block-local by design and runs on the
// unfinished tail only.)
void checkPrefixes(const std::string &name, const std::string &document) {
  for (StreamingBlockMode mode : {StreamingBlockMode::Progressive, StreamingBlockMode::Hidden}) {
    StreamingOptions options;
    options.blocks.tableMode = options.blocks.codeBlockMode = options.blocks.mediaMode = mode;
    size_t previous = 0;
    int reported = 0;
    for (size_t length = 1; length <= document.size() && reported < 3; length++) {
      if ((static_cast<unsigned char>(document[length - 1]) & 0xC0) == 0x80)
        continue; // inside a UTF-8 sequence
      std::string prefix = document.substr(0, length);
      Markdown::StreamingSnapshot snapshot = Markdown::streamingSnapshot(prefix, options);
      Markdown::StreamingFilterResult whole = Markdown::renderableMarkdownForStreaming(prefix, options.blocks);
      Markdown::StreamingFilterResult tail =
          Markdown::renderableMarkdownForStreaming(prefix.substr(snapshot.finishedBytes), options.blocks);
      std::string at = name + (mode == StreamingBlockMode::Hidden ? " (hidden)" : "") + " after " +
                       std::to_string(length) + " bytes";
      bool same = prefix.substr(0, snapshot.finishedBytes) + tail.markdown == whole.markdown &&
                  tail.endsInsideOpenCodeFence == whole.endsInsideOpenCodeFence;
      bool grows = snapshot.finishedBytes >= previous &&
                   snapshot.markdown.compare(0, snapshot.finishedBytes, prefix, 0, snapshot.finishedBytes) == 0;
      check(same, at + ": the filter differs from filtering it whole");
      check(grows, at + ": the finished blocks shrank or changed");
      reported += !same || !grows;
      previous = snapshot.finishedBytes;
    }
  }
}

} // namespace

int main(int argc, char **argv) {
  // Inline syntax still being typed: an image waits, a link shows its label.
  expect("- ![a](https://e", "- ", "a list item's half-typed image waits");
  expect("The inline ![leaf](https://e", "The inline ", "an open inline image waits");
  expect("The inline ![leaf", "The inline ", "an inline image without ]( waits");
  expect("> Quote ![q](https://e", "> Quote ", "a quoted inline image waits");
  expect("See [docs](https://e", "See docs", "an open link shows its label");
  expect("See [docs]", "See docs", "a label at the very end may become a link: no brackets yet");
  expect("See [docs](https://e.com/a(b)", "See docs", "a nested parenthesis keeps the link open");
  expect("See [a](u \"t )", "See a", "an open title keeps the link open");
  expect("Use \\![a](https://e", "Use \\!a", "an escaped bang is text, the link after it is still open");
  expect("Use `a` and [docs](https://e", "Use `a` and docs", "a closed code span before an open link");
  expect("See [![thumb](u)](https://e", "See ![thumb](u)", "an open link around a closed image keeps the image");
  expect("see [the\ndocs](https://e", "see the\ndocs", "a label across a soft line break");
  expect("> see [the\n> docs](https://e", "> see the\n> docs", "a quoted label across a soft line break");
  expect("> see [the\ndocs](https://e", "> see the\ndocs", "a lazy continuation line stays in the quoted paragraph");
  expect("para\n    [a](https://e", "para\n    a", "a lazy continuation is not indented code");
  expect("- item\n- see [a](https://e", "- item\n- see a", "only the last list item holds the link");
  expect("# Heading\nsee [a](https://e", "# Heading\nsee a", "the paragraph after a heading");
  expect("[x](a [b](https://e", "[x](a b", "a link after a destination that is prose");
  expect("See [docs][nope]", "See [docs][nope]", "an undefined reference stays literal, as in the finished text");
  expect("> ```md\n> code\n\nAfter ![a](https://e", "> ```md\n> code\n\nAfter ",
         "a quoted fence closes with its quote");

  // Inline syntax the filter leaves to repair: complete or literal syntax stays.
  expect("See [docs] now", "See [docs] now", "plain brackets in prose kept");
  expect("See [docs](https://e.com) now", "See [docs](https://e.com) now", "closed inline link kept");
  expect("Use `a[0](` here", "Use `a[0](` here", "brackets in inline code kept");
  expect("See [docs](https://e\n\nAfter", "See [docs](https://e\n\nAfter",
         "a link left open in an earlier paragraph is literal");
  expect("See [docs](https://e\n```js\nlet a", "See [docs](https://e\n```js\nlet a",
         "a fence ends the paragraph: nothing to repair");

  // Review cases: the trailing paragraph, not the last line, holds the syntax.
  expect("a `x\n[a](https://e` b", "a `x\n[a](https://e` b", "code span across lines kept");
  expect("# Heading [draft\nsome text after", "# Heading [draft\nsome text after",
         "a heading ends on its line: the paragraph after it is scanned");
  expect("Title [x\n=====\nnext para", "Title [x\n=====\nnext para", "a setext underline ends the block above");
  expect("Title [x\n=====", "Title [x\n=====", "a setext heading with a stray bracket is closed");
  expect("para [x\n***\nnext", "para [x\n***\nnext", "a thematic break ends the block above");
  expect("para [x\n> quoted text", "para [x\n> quoted text", "a quote interrupts the paragraph");
  expect("> a [x\n> > nested text", "> a [x\n> > nested text", "a deeper quote interrupts the paragraph");
  expect("para [x\n<div>raw</div>", "para [x\n<div>raw</div>", "an HTML block interrupts the paragraph");
  expect("See [docs](https://e.com then more", "See [docs](https://e.com then more",
         "a destination followed by prose is no link");
  const std::string stray = "Note [1 " + std::string(600, 'x');
  expect(stray, stray, "a stray bracket far behind is literal");
  expect("[a](https://e.com/`q`) then `[b` c", "[a](https://e.com/`q`) then `[b` c",
         "code spans after a skipped destination still count");

  // Review cases: references.
  expect("[r]: https://e.com\n\nSee [docs][r]", "[r]: https://e.com\n\nSee [docs][r]", "full reference kept");
  expect("[r]: https://e.com\n\n![logo][r]", "[r]: https://e.com\n\n![logo][r]", "reference image kept");
  expect("[R  x]: https://e.com\n\nSee [docs][r x]", "[R  x]: https://e.com\n\nSee [docs][r x]",
         "reference labels match case and space insensitively");
  expect("[r]: https://e.com\n\nSee [r][]", "[r]: https://e.com\n\nSee [r][]", "collapsed reference kept");

  expect("[note] see [docs] here", "[note] see [docs] here", "two bracketed words are prose");

  // Repair runs with the parser's flags.
  expect("Text **bol", "Text **bol**", "emphasis gets its closer");
  expect("Run `npm i", "Run `npm i`", "inline code gets its closer");
  expect("Energy $E = mc", "Energy", "unclosed math waits");
  StreamingOptions noMath;
  noMath.flags.latexMath = false;
  expect("Costs $5 and *a", "Costs $5 and *a*", "without math a dollar is currency", noMath);
  expect("Para\n- ", "Para\n", "a lone list marker waits");
  expect("Para\n#", "Para\n", "a lone heading marker waits");
  expect("Approx ~5 and ~10", "Approx ~5 and ~10", "the parser decides what a single tilde means");

  // The filter still withholds trailing blocks.
  expect("Intro\n\n| a | b |\n|---|---|\n| 1", "Intro\n\n| a | b |\n|---|---|\n", "an incomplete table row");
  expect("Intro\n\n$$\nE = mc^2", "Intro\n\n", "an open display math block");
  check(Markdown::streamingSnapshot("Intro\n\n```js\nlet a", {}).endsInsideOpenCodeFence, "an open fence is flagged");

  // Finished blocks: only after a blank line, at a complete line that starts a
  // block of its own, outside fences, `$$` and HTML that may hold blank lines.
  check(finished("One\n\nTwo\n\nThree") == 10, "the last paragraph start");
  check(finished("One\n\nTwo") == 5, "a line still arriving that cannot become a fence, `$$` or HTML");
  check(finished("One\n\n``") == 0, "a line still arriving that may become a fence");
  check(finished("One\n\n$") == 0, "a line still arriving that may become `$$`");
  check(finished("One\nTwo\n") == 0, "no blank line, no finished block");
  check(finished("- a\n\n- b\n") == 0, "a list item may belong to the list above");
  check(finished("Para\n\n    code\n") == 0, "an indented line may continue the block above");
  check(finished("Para\n\n[r]: https://e.com\n") == 0, "a reference definition");
  check(finished("```\na\n\nb\n") == 0, "inside an open fence");
  check(finished("```\na\n```\n\nb\n") == 11, "after a closed fence");
  check(finished("$$\nx\n\ny\n") == 0, "inside open display math");
  check(finished("<pre>\n\nx\n\ny\n") == 0, "inside HTML that may hold blank lines");
  check(finished("<!-- c -->\n\nOne\n\nTwo\n") == 17, "after a closed comment");
  check(finished("<pre>\n\nx\n</pre>\n\nOne\n\nTwo\n") == 22, "after a closed raw block");
  check(finished("One\n\n<PRE>\n\n**x\n\ny\n") == 0, "a raw tag in capitals");
  check(finished("<prefix>\n\nOne\n\nTwo\n") == 15, "a tag that only starts like a raw one");
  check(finished("<!--\na\n\nb\n-->\n\nOne\n\nTwo\n") == 20, "a comment closed lines later");
  check(finished("> quote\n\nPara\n") == 9, "after a blockquote");

  for (int i = 1; i < argc; i++)
    checkPrefixes(argv[i], readFile(argv[i]));
  checkPrefixes("HTML blocks with blank lines",
                "Intro\n\n<!--\nnote\n\nmore\n-->\n\n| A | B |\n| - | - |\n| 1 | 2 |\n\n<PRE>\n**x\n\ny\n</pre>\n\n"
                "```js\nlet a\n```\n\n<?php\n\n?>\n\nEnd **bold**\n");

  if (failures != 0) {
    std::cerr << failures << " streaming session check(s) failed\n";
    return 1;
  }
  std::cout << "    streaming session checks passed\n";
  return 0;
}
