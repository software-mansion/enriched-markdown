// Internals shared by the repair translation units and their tests. Not part
// of the public API.
//
// Two JS details shape this file:
//
// - JS strings are UTF-16. The reference inspects `text[i - 1]` / `text[i + 1]` as
//   single code units, so an astral character (emoji, mathematical letters)
//   is seen as a lone surrogate and never counts as a word character, while
//   the Unicode-aware regexes (`u` flag) see the full code point. We mirror
//   both: isWordCharUnit() is the code-unit view, Markdown::isWordChar() the
//   full view.
// - `\s`, trim() and trimEnd() use the JS whitespace set (which includes
//   NBSP, the U+2000 block, U+FEFF and the line separators), not ASCII.
#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "MarkdownRepair.hpp"

namespace Markdown::UnicodeTables {
struct Range;
}

namespace Markdown::RepairInternal {

constexpr size_t npos = std::string_view::npos;
constexpr std::string_view kIncompleteLinkSuffix = "](streamdown:incomplete-link)";
static_assert(kIncompleteLinkSuffix.substr(2, kIncompleteLinkUrl.size()) == kIncompleteLinkUrl,
              "kIncompleteLinkSuffix must embed kIncompleteLinkUrl");
constexpr std::string_view kZeroWidthSpace = "\xE2\x80\x8B"; // U+200B

// --- UTF-8 -----------------------------------------------------------------

struct Decoded {
  uint32_t codePoint;
  size_t length;
};

// Decodes the code point starting at byte i. Malformed input decodes as
// U+FFFD with length 1 so scanning always makes progress.
Decoded decodeAt(std::string_view text, size_t i);

// Code point starting at byte i, or kNoCodePoint past the end.
uint32_t codePointAt(std::string_view text, size_t i);

// Code point whose last byte is i - 1, or kNoCodePoint at the start.
uint32_t codePointBefore(std::string_view text, size_t i);

// Start of the code point whose last byte is i - 1. Requires i > 0.
size_t codePointStartBefore(std::string_view text, size_t i);

// --- JS character classes --------------------------------------------------

// The reference's isWordChar() applied to a single UTF-16 code unit (see file comment).
bool isWordCharUnit(uint32_t codePoint);

// JS `\s` / String.prototype.trim whitespace.
bool isJsWhitespace(uint32_t codePoint);

// The three characters the reference's emphasis code treats as whitespace.
bool isSpaceTabNewline(uint32_t codePoint);

bool isAsciiDigit(char c);
bool isAsciiLetterOrSlash(char c);

bool inRanges(uint32_t codePoint, const UnicodeTables::Range *ranges, size_t count);

// md4c's ISUNICODEPUNCT: Unicode general categories P and S.
bool isUnicodePunctuation(uint32_t codePoint);

std::string_view jsTrimStart(std::string_view text);
std::string_view jsTrimEnd(std::string_view text);
std::string_view jsTrim(std::string_view text);

// /^[\s_~*`]*$/ : nothing but whitespace and emphasis markers
bool isWhitespaceOrMarkersOnly(std::string_view text);

// /^[\s]*[-*+][\s]+$/ : a bare list marker line
bool isListItemMarkerLine(std::string_view line);

// --- Plain string helpers --------------------------------------------------

bool startsWith(std::string_view text, std::string_view prefix);
bool endsWith(std::string_view text, std::string_view suffix);

// The byte at i is preceded by an odd number of backslashes.
bool isEscaped(std::string_view text, size_t i);

bool isTripleAt(std::string_view text, size_t i);

// A fence marker: three or more backticks anywhere, as the reference counts
// them, or tildes with only indentation before them on their line. `fence`
// is the open fence, or none. Inside an open fence a run of the other
// character, or a shorter run of the same one, is content. When a marker is
// consumed, i is advanced to its last byte (the caller's loop takes the
// final step) and the result is true.
struct Fence {
  char c = 0;
  size_t length = 0;
};
bool consumeFence(std::string_view text, size_t &i, Fence &fence);

// The fence the text ends inside, or none.
Fence unclosedFence(std::string_view text);
bool endsInsideFence(std::string_view text);

// Non-overlapping occurrence count, like text.match(/needle/g).length.
size_t countNonOverlapping(std::string_view text, std::string_view needle);

// The line containing `index`, up to (not including) `index`.
std::string_view lineBefore(std::string_view text, size_t index);

// The whole line containing `index`, without its newline.
std::string_view lineAt(std::string_view text, size_t index);

// Length of a list marker at the start of `line` (`-`, `*`, `+`, or digits
// followed by `.` or `)`), or npos if the line does not start with one.
size_t skipListMarker(std::string_view line);

// Strips the blockquote markers that open `line`, each allowed up to three
// spaces of indentation before it and one space after, and counts them.
std::string_view stripBlockquotes(std::string_view line, size_t &depth);

// --- Regex stand-ins -------------------------------------------------------

// /(MARKER)([^c]*)$/ (and, with allowTrailingSingle, /(MARKER)([^c]*c?)$/):
// the leftmost occurrence of MARKER after which no `c` appears, except
// possibly one final `c`. Returns the text after the marker.
std::optional<std::string_view> matchTrailingMarker(std::string_view text, std::string_view marker, char c,
                                                    bool allowTrailingSingle);

// /(MM)([^c]+)c$/ where MM is the doubled marker: text ends with a single `c`,
// preceded by at least one non-`c` character, preceded somewhere by MM.
bool matchHalfCompleteMarker(std::string_view text, std::string_view marker, char c);

// --- Scans (utils.ts / code-block-utils.ts) --------------------------------

// isWithinHtmlTag(): position is after a `<` that starts a tag on this line.
bool isWithinHtmlTag(std::string_view text, size_t position);

// isHorizontalRule(): the line containing markerIndex is only `marker`
// characters (at least three) and spaces/tabs.
bool isHorizontalRule(std::string_view text, size_t markerIndex, char marker);
bool isHorizontalRuleLine(std::string_view line, char marker);

// isPartOfTripleBacktick(): the backtick at i belongs to a ``` sequence.
bool isPartOfTriple(std::string_view text, size_t i);

// countSingleBackticks(): backticks that are neither escaped nor part of ```.
size_t countSingleBackticks(std::string_view text);

// findMatchingOpeningBracket() / findMatchingClosingBracket(), nesting-aware.
size_t findMatchingOpeningBracket(std::string_view text, size_t closeIndex);
size_t findMatchingClosingBracket(std::string_view text, size_t openIndex);

// --- Context lookups (code-block-utils.ts / utils.ts) ----------------------

// isInsideCodeBlock() as a lookup: inside(p) is true when scanning [0, p)
// ends inside inline or fenced code. Escaped backticks are skipped.
class CodeLookup {
public:
  explicit CodeLookup(std::string_view text);
  bool inside(size_t position) const;

private:
  std::vector<uint8_t> insideAt_;
};

struct DollarRun {
  size_t length;
  bool canOpen;
  bool canClose;
};
DollarRun dollarRunAt(std::string_view text, size_t i);

// isWithinMathBlock() as a lookup: inside(p) is true when scanning [0, p)
// ends inside `$…$`, `$$…$$`, `\(…\)` or `\[…\]`. Built only when the text
// contains a math delimiter, since most callers check that first. With
// inlineDollar false a lone `$` is currency, not a delimiter; the reference
// always treats it as math, so `$5 and *x` never closed there.
class MathLookup {
public:
  explicit MathLookup(std::string_view text, bool inlineDollar = true, const CodeLookup *code = nullptr);
  bool inside(size_t position) const;

private:
  bool hasDelimiters_;
  std::vector<uint8_t> insideAt_;
};

// countDoubleAsterisksOutsideCodeBlocks() and its `_` / `~` counterparts:
// doubled markers outside fences and math. The reference counts `~~` with a
// plain string search, so one inside a fence or `$$…$$` is a delimiter there.
size_t countDoubleMarkers(std::string_view text, char c, const MathLookup &math);

// isWithinCompleteInlineCode() as a lookup: inside(p) is true when p sits
// strictly inside an inline code span that has both backticks.
class CompleteInlineCodeLookup {
public:
  explicit CompleteInlineCodeLookup(std::string_view text);
  bool inside(size_t position) const;

private:
  std::vector<uint8_t> insideAt_;
};

// isWithinLinkOrImageUrl() and isWithinHtmlTag() as lookups, built in one
// forward pass. Both public functions walk backwards per query, which is
// O(line length) per delimiter and quadratic on long unwrapped paragraphs;
// the lookup gives the same answers in O(1). The parity tests check the two
// agree on every position of every recorded case.
class LineContextLookup {
public:
  explicit LineContextLookup(std::string_view text);
  bool insideLinkUrl(size_t position) const;
  bool insideHtmlTag(size_t position) const;

private:
  static constexpr uint8_t kLinkUrl = 1;
  static constexpr uint8_t kHtmlTag = 2;
  std::vector<uint8_t> flags_;
};

// The two places on a line where a `[` is block markup rather than a link:
// right after a `>` chain (`> [!NOTE]`) and right after a list marker plus
// whitespace (`- [ ]`). npos when the line has no such slot.
struct LineMarkers {
  size_t admonitionBracket;
  size_t checkboxBracket;
};

// LineMarkers for every line, built in one pass so isBracketNotALink() no
// longer walks back to the line start per `[`, which was quadratic on
// bracket-heavy unwrapped paragraphs.
class LineMarkerLookup {
public:
  explicit LineMarkerLookup(std::string_view text);
  const LineMarkers &lineFor(size_t position) const;

private:
  std::vector<size_t> lineStarts_;
  std::vector<LineMarkers> lines_;
};

// True for a `[` that is markup of its own rather than the start of a link:
// a task-list marker (`- [ `, `- [x]`, or `- [` still streaming), an
// admonition marker (`> [!`), a footnote reference (`[^`) or the second
// bracket of a reference-style link (`][`). The reference has none of these.
// Defined for positions where text[idx] == '['.
bool isBracketNotALink(std::string_view text, size_t idx, const LineMarkerLookup &markers);

// State for one pipeline run. Three responsibilities, kept together because
// every one of them has to know when the text changed:
//
// 1. The text. Handlers read it through text() and edit it only through the
//    methods below, so nothing here can go stale unnoticed.
// 2. Lookups shared by the handlers (code, math, complete inline code), built
//    on first use and rebuilt only when an edit could have changed them.
// 3. The closer tail: closers placed so far sit in one contiguous run just
//    before any trailing whitespace, ordered so that a later opener closes
//    first (`**bold `code` becomes `**bold `code`**`). Insertion is immediate,
//    as in the reference, so later handlers see earlier closers and never
//    close the same construct twice.
//
// Aliasing rule: a string_view from text() and a lookup reference from code()
// or math() are valid only until the next edit. Handlers therefore do all
// their reading first and edit as their final step.
class RepairContext {
public:
  explicit RepairContext(std::string &text, bool inlineMath = false, bool parserMath = false)
      : text_(text), inlineMath_(inlineMath), parserMath_(parserMath) {}

  // --- reading
  std::string_view text() const {
    return text_;
  }
  // The text without the closer tail, for handlers whose counting would be
  // confused by a closer glued onto the user's last delimiter.
  std::string_view textBeforeClosers() const {
    return closers_.empty() ? text() : text().substr(0, closersStart_);
  }
  const CodeLookup &code();
  const MathLookup &math();
  // Built over textBeforeClosers(); valid for positions before the tail.
  const LineContextLookup &lines();
  const LineMarkerLookup &markers();
  // isInsideCodeBlock() || isWithinCompleteInlineCode()
  bool insideAnyCode(size_t position);

  // --- editing (forgets the closer tail and the lookups)
  void append(std::string_view suffix);
  void append(char c);
  void erase(size_t position, size_t count = std::string::npos);
  void assign(std::string &&replacement);

  // --- closing
  // Places the closer for a construct opened at openerIndex into the tail.
  // Ignored when the opener sits in an earlier block: an inline span cannot
  // cross a blank line or leave a heading, so the closer would only be a stray
  // marker in a later block. (The reference appends regardless.)
  void closeAt(size_t openerIndex, std::string_view closer);
  // The rule closeAt() applies, for the handlers that erase instead of
  // closing: an opener in an earlier block is literal, not a reason to drop
  // the text after it.
  bool openerCanStillClose(size_t openerIndex);
  // Start of the last block of textBeforeClosers(): the text after the last
  // blank line or the last line that interrupts a paragraph.
  size_t lastBlockStart();

private:
  struct Closer {
    size_t openerIndex;
    size_t length;
  };

  void dropLookups();
  void invalidate();

  std::string &text_;
  bool inlineMath_; // whether a lone `$` opens math (RepairOptions::inlineMath)
  bool parserMath_;

  std::optional<CodeLookup> code_;
  std::optional<MathLookup> math_;
  std::optional<CompleteInlineCodeLookup> completeInline_;
  std::optional<LineContextLookup> lines_;
  std::optional<LineMarkerLookup> markers_;

  std::vector<Closer> closers_; // in text order, contiguous from closersStart_
  size_t closersStart_ = 0;
  std::optional<size_t> blockStart_; // start of the last block, cached for openerCanStillClose()
};

// Visits every byte index outside fences (see consumeFence()), in order. The
// visitor returns true to stop early and may advance `i` past bytes it
// consumed; most leave it alone.
template <class Visitor> void scanOutsideFences(std::string_view text, Visitor visit) {
  Fence fence;
  for (size_t i = 0; i < text.size(); ++i) {
    if (consumeFence(text, i, fence) || fence.c != 0) {
      continue;
    }
    if (visit(i)) {
      return;
    }
  }
}

} // namespace Markdown::RepairInternal

// One function per reference handler. The pipeline runs them in priority
// order on a shared context; tests run them individually.
namespace Markdown::RepairHandlers {
using RepairInternal::RepairContext;
void singleTilde(RepairContext &ctx);
void comparisonOperators(RepairContext &ctx);
void htmlTags(RepairContext &ctx);
void setextHeadings(RepairContext &ctx);
void links(RepairContext &ctx, LinkMode mode);
void boldItalic(RepairContext &ctx);
void bold(RepairContext &ctx);
void italicDoubleUnderscore(RepairContext &ctx);
void italicSingleAsterisk(RepairContext &ctx);
void italicSingleUnderscore(RepairContext &ctx);
void inlineCode(RepairContext &ctx);
void strikethrough(RepairContext &ctx);
void displayMath(RepairContext &ctx);
void inlineMath(RepairContext &ctx);
// md4c extensions (RepairExtensions.cpp)
void spoilers(RepairContext &ctx);
void highlight(RepairContext &ctx);
void superscript(RepairContext &ctx);
void subscript(RepairContext &ctx);
void withhold(RepairContext &ctx, const RepairOptions &options);
} // namespace Markdown::RepairHandlers
