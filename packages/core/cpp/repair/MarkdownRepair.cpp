// Counterpart of the reference's index.ts (the pipeline) and the exported
// helpers in utils.ts. Attribution is in MarkdownRepair.hpp.
#include "MarkdownRepair.hpp"

#include <algorithm>

#include "RepairInternal.hpp"
#include "UnicodeTables.hpp"

namespace Markdown {

using namespace RepairInternal;

// --- Public helpers ----------------------------------------------------------

bool isWordChar(uint32_t codePoint) {
  if (codePoint < 0x80) { // ASCII fast path; the table lookup below is a binary search
    return (codePoint >= '0' && codePoint <= '9') || (codePoint >= 'A' && codePoint <= 'Z') ||
           (codePoint >= 'a' && codePoint <= 'z') || codePoint == '_';
  }
  if (codePoint == kNoCodePoint) {
    return false;
  }
  const auto *begin = UnicodeTables::kLetterOrNumberRanges;
  const auto *end = begin + UnicodeTables::kLetterOrNumberRangeCount;
  const auto *it = std::upper_bound(begin, end, codePoint,
                                    [](uint32_t value, const UnicodeTables::Range &r) { return value < r.first; });
  return it != begin && codePoint <= (it - 1)->last;
}

// utils.ts isWithinCodeBlock(): only ``` toggles, no escapes, no inline code.
bool isWithinCodeBlock(std::string_view text, size_t position) {
  bool inFence = false;
  for (size_t i = 0; i < position && i < text.size(); ++i) {
    if (isTripleAt(text, i)) {
      inFence = !inFence;
      i += 2;
    }
  }
  return inFence;
}

bool isWithinMathBlock(std::string_view text, size_t position) {
  return MathLookup(text).inside(position);
}

bool isWithinLinkOrImageUrl(std::string_view text, size_t position) {
  for (size_t i = position; i > 0; --i) {
    const char c = text[i - 1];
    if (c == ')' || c == '\n') {
      return false;
    }
    if (c == '(') {
      if (i < 2 || text[i - 2] != ']') {
        return false;
      }
      // isBeforeClosingParen()
      for (size_t j = position; j < text.size(); ++j) {
        if (text[j] == ')') {
          return true;
        }
        if (text[j] == '\n') {
          return false;
        }
      }
      return false;
    }
  }
  return false;
}

// --- Pipeline ----------------------------------------------------------------

// Handlers run in the reference's priority order on one shared context. Each option
// gates one handler, except `italic` (three handlers) and `links`/`images`
// (either enables the shared link handler).
void repairInlineMarkdownInPlace(std::string &text, const RepairOptions &options) {
  if (text.empty()) {
    return;
  }
  // A single trailing space is dropped; two are a hard break and stay.
  if (endsWith(text, " ") && !endsWith(text, "  ")) {
    text.pop_back();
  }

  RepairContext ctx(text);
  if (options.singleTilde && !options.subscript) { // with subscripts, `~x~` is markup
    RepairHandlers::singleTilde(ctx);
  }
  if (options.comparisonOperators) {
    RepairHandlers::comparisonOperators(ctx);
  }
  if (options.htmlTags) {
    RepairHandlers::htmlTags(ctx);
  }
  if (options.setextHeadings) {
    RepairHandlers::setextHeadings(ctx);
  }
  if (options.links || options.images) {
    // The reference stops here once a placeholder link was appended; we keep
    // going so constructs opened before the link still get their closers,
    // which closeAt() places after the link. The placeholder URL contains no
    // marker characters, so no later handler can damage it.
    RepairHandlers::links(ctx, options.linkMode);
  }
  if (options.boldItalic) {
    RepairHandlers::boldItalic(ctx);
  }
  if (options.bold) {
    RepairHandlers::bold(ctx);
  }
  if (options.italic) {
    RepairHandlers::italicDoubleUnderscore(ctx);
    RepairHandlers::italicSingleAsterisk(ctx);
    RepairHandlers::italicSingleUnderscore(ctx);
  }
  if (options.inlineCode) {
    RepairHandlers::inlineCode(ctx);
  }
  if (options.strikethrough) {
    RepairHandlers::strikethrough(ctx);
  }
  if (options.displayMath) {
    RepairHandlers::displayMath(ctx);
  }
  if (options.inlineMath) {
    RepairHandlers::inlineMath(ctx);
  }
  if (options.spoilers) {
    RepairHandlers::spoilers(ctx);
  }
  if (options.highlight) {
    RepairHandlers::highlight(ctx);
  }
  if (options.superscript) {
    RepairHandlers::superscript(ctx);
  }
  if (options.subscript) {
    RepairHandlers::subscript(ctx);
  }
}

std::string repairInlineMarkdown(std::string_view markdown, const RepairOptions &options) {
  std::string text(markdown);
  repairInlineMarkdownInPlace(text, options);
  return text;
}

} // namespace Markdown
