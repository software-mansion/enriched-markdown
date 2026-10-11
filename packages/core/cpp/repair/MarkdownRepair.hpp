// Repair of incomplete markdown for streaming: closes the `**`, `[link](`,
// `$$` and similar constructs left open at the end of a streamed prefix, so
// the parser renders it the way the finished document will.
//
// Attribution: this module is a C++ port of remend 1.3.1 by Vercel, licensed
// under Apache-2.0; see LICENSE.remend in this directory. Below, "the
// reference" means that implementation. Handler names, option names, defaults
// and run order match it, and the tests in packages/core/cpp/tests replay its
// test suite against this port. When changing anything here, run
// `yarn core:test`.
//
// Source layout, mirroring the reference's:
//   MarkdownRepair.cpp   pipeline and public helpers        (index.ts, utils.ts)
//   RepairEmphasis.cpp   bold / italic / bold-italic        (emphasis-handlers.ts)
//   RepairHandlers.cpp   every other handler                (*-handler.ts)
//   RepairInternal.*     UTF-8, JS character classes, scans (utils.ts, code-block-utils.ts)
//
// Deliberate divergences from the reference:
// - Closers for constructs that are open at the same time are inserted in
//   reverse opening order, before any trailing newlines, so the result nests
//   correctly (`**bold `code` becomes `**bold `code`**`). The reference appends
//   each closer as its handler runs.
// - `**` and `__` close on parity even when a single marker follows the
//   opener, so a nested italic no longer keeps them open (`**bold *ital`
//   becomes `**bold *ital***`).
// - The pipeline does not stop after a placeholder link, and the placeholder
//   is itself a closer anchored at `[`, so `**bold [link` gets its `**` after
//   the link and `[**bold link` gets it inside.
// - The htmlTags handler only strips a tag that starts a line. Inline HTML is
//   disabled in our parser, so `<` inside a line is prose.
// - A `[` that starts a task-list item (`- [ `), an admonition (`> [!`), a
//   footnote (`[^`) or the second bracket of a reference link (`][`) is not
//   an incomplete link.
// - Trailing CRLF counts as a trailing newline when placing closers.
// - An opener whose paragraph has already ended is not closed: after a blank
//   line, a heading line, or a later line that starts a fence, heading or
//   list item. An inline span cannot reach across a block boundary, so the
//   closer would be a stray marker in a later block.
// - Closers are anchored at the delimiter that is actually open, found while
//   counting, rather than at the first marker in the text.
// - An escaped `\[` or `\]` is never a link bracket; LLMs stream `\[ … \]`
//   for display math.
// - The single-underscore counter applies the same open/close flanking rule
//   as the asterisk counter (`_a_ b_` does not reopen).
// The affected recorded cases in the test data are marked as ours.
//
// Additions with no reference counterpart: closers for spoilers, highlight,
// superscript and subscript (RepairExtensions.cpp).
//
// When wiring this into a renderer, default `inlineMath` to the parser's
// latexMath flag: with `$…$` math enabled an open `$x` should be closed too.
//
// All text is UTF-8. Positions are byte offsets.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>

namespace Markdown {

enum class LinkMode { Protocol, TextOnly };

// Same names and defaults as the reference's options object, except that its
// `katex` / `inlineKatex` are `displayMath` / `inlineMath` here: this repo
// calls the feature latexMath everywhere, and "KaTeX" would suggest the web
// renderer.
struct RepairOptions {
  bool bold = true;
  bool boldItalic = true;
  bool comparisonOperators = true;
  bool htmlTags = true;
  bool images = true;
  bool inlineCode = true;
  bool inlineMath = false;  // `$…$`; opt-in upstream too, since `$` is ambiguous with currency
  bool italic = true;
  bool displayMath = true;  // `$$…$$`
  bool links = true;
  bool setextHeadings = true;
  bool singleTilde = true;
  bool strikethrough = true;
  LinkMode linkMode = LinkMode::Protocol;

  // Closers for md4c extensions the reference does not have. Spoilers are
  // always on in our parser; wire the others from the parser flags. With
  // subscripts on, the single-tilde escape is skipped since `~x~` is markup.
  bool spoilers = true;
  bool highlight = false;
  bool superscript = false;
  bool subscript = false;
};

// Equivalent to the reference's top-level function.
std::string repairInlineMarkdown(std::string_view markdown, const RepairOptions &options);
void repairInlineMarkdownInPlace(std::string &markdown, const RepairOptions &options);

// Placeholder URL substituted for an incomplete link in LinkMode::Protocol.
// Renderers must treat links with this URL as inert.
inline constexpr std::string_view kIncompleteLinkUrl = "streamdown:incomplete-link";

// Sentinel for "no character here" in the code point helpers below.
inline constexpr uint32_t kNoCodePoint = 0xFFFFFFFFu;

// Helpers with the same semantics as the reference's public exports.
bool isWordChar(uint32_t codePoint);
bool isWithinCodeBlock(std::string_view text, size_t position);
bool isWithinMathBlock(std::string_view text, size_t position);
bool isWithinLinkOrImageUrl(std::string_view text, size_t position);

}  // namespace Markdown
