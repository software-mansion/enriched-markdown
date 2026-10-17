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
