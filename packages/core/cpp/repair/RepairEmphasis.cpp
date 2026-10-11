// Counterpart of the reference's emphasis-handlers.ts: bold, italic and
// bold-italic. Attribution is in MarkdownRepair.hpp.
//
// Every handler has the same shape: locate the last opener (a regex stand-in
// for `***`, the last occurrence for `**` and `__`, the first valid single
// marker for `*` and `_`), bail out if it sits in code or has no real content
// after it, then count delimiters outside fences and close on odd parity.
#include "RepairInternal.hpp"

namespace Markdown::RepairHandlers {

using namespace RepairInternal;

namespace {

// --- Counting ---------------------------------------------------------------

// shouldSkipAsterisk()
bool shouldSkipAsterisk(std::string_view text, size_t index, uint32_t prev, uint32_t next, const MathLookup &math) {
  if (prev == '\\' || math.inside(index)) {
    return true;
  }
  if (prev != '*' && next == '*') {
    // first * of ** or ***: only the *** case counts (it can close a single *)
    const char nextNext = index + 2 < text.size() ? text[index + 2] : '\0';
    return nextNext != '*';
  }
  if (prev == '*') {
    return true;
  }
  const bool prevWs = prev == kNoCodePoint || isSpaceTabNewline(prev);
  const bool nextWs = next == kNoCodePoint || isSpaceTabNewline(next);
  return prevWs && nextWs;
}

// countSingleAsterisks(): parity of single * delimiters outside fences.
// Intraword asterisks only count while an emphasis run is open (hello*world
// stays literal, *foo*bar* does not reopen).
// Parity of single-marker delimiters. When `count` is odd, `lastCounted` is
// the delimiter still open, which is where its closer belongs.
struct DelimiterCount {
  size_t count = 0;
  size_t lastCounted = npos;
};

DelimiterCount countSingleAsterisks(std::string_view text, const MathLookup &math) {
  DelimiterCount result;
  size_t &count = result.count;
  bool inWordChain = false;
  scanOutsideFences(text, [&](size_t &i) {
    if (text[i] != '*') {
      const auto [codePoint, length] = decodeAt(text, i);
      if (!isWordCharUnit(codePoint)) {
        inWordChain = false;
      }
      i += length - 1;
      return false;
    }
    const uint32_t prev = codePointBefore(text, i);
    const uint32_t next = codePointAt(text, i + 1);
    if (shouldSkipAsterisk(text, i, prev, next, math)) {
      return false;
    }
    // shouldCountSingleAsterisk()
    const bool wordInternal = isWordCharUnit(prev) && isWordCharUnit(next);
    const bool canOpen = next != kNoCodePoint && !isSpaceTabNewline(next);
    const bool canClose = prev != kNoCodePoint && !isSpaceTabNewline(prev);
    if (wordInternal && count % 2 == 0 && !inWordChain) {
      return false;
    }
    if ((canClose && count % 2 == 1) || canOpen) {
      ++count;
      result.lastCounted = i;
      inWordChain = wordInternal;
    }
    return false;
  });
  return result;
}

// countSingleUnderscores(): parity of single _ delimiters outside fences,
// math, URLs, HTML tags and words. The reference counts every such _; ours
// also applies the open/close flanking rule the asterisk counter uses, so a
// trailing `_` after a closed italic (`_a_ b_`) is not taken for an opener.
DelimiterCount countSingleUnderscores(std::string_view text, const MathLookup &math, const LineContextLookup &lines) {
  DelimiterCount result;
  size_t &count = result.count;
  scanOutsideFences(text, [&](size_t &i) {
    if (text[i] != '_') {
      return false;
    }
    const uint32_t prev = codePointBefore(text, i);
    const uint32_t next = codePointAt(text, i + 1);
    // shouldSkipUnderscore(), cheapest tests first: snake_case never reaches the lookups
    const bool skip = prev == '\\' || prev == '_' || next == '_' || (isWordCharUnit(prev) && isWordCharUnit(next)) ||
                      math.inside(i) || lines.insideLinkUrl(i) || lines.insideHtmlTag(i);
    if (skip) {
      return false;
    }
    const bool canOpen = next != kNoCodePoint && !isSpaceTabNewline(next);
    const bool canClose = prev != kNoCodePoint && !isSpaceTabNewline(prev);
    if ((canClose && count % 2 == 1) || canOpen) {
      ++count;
      result.lastCounted = i;
    }
    return false;
  });
  return result;
}

// countTripleAsterisks(): runs of *** outside fences (**** counts one).
// Not written with scanOutsideFences() because a fence toggle must also
// flush the run in progress.
size_t countTripleAsterisks(std::string_view text) {
  size_t count = 0;
  size_t run = 0;
  bool inFence = false;
  for (size_t i = 0; i < text.size(); ++i) {
    if (isTripleAt(text, i)) {
      count += run / 3;
      run = 0;
      inFence = !inFence;
      i += 2;
      continue;
    }
    if (inFence) {
      continue;
    }
    if (text[i] == '*') {
      ++run;
    } else {
      count += run / 3;
      run = 0;
    }
  }
  return count + run / 3;
}

// countDoubleAsterisksOutsideCodeBlocks() / countDoubleUnderscoresOutsideCodeBlocks()
size_t countDoubleMarkers(std::string_view text, char c) {
  size_t count = 0;
  scanOutsideFences(text, [&](size_t &i) {
    if (text[i] == c && i + 1 < text.size() && text[i + 1] == c) {
      ++count;
      ++i;
    }
    return false;
  });
  return count;
}

// --- Openers ----------------------------------------------------------------

// findFirstSingleAsteriskIndex(): the first * that can open incomplete italic.
size_t findFirstSingleAsteriskIndex(std::string_view text, const MathLookup &math) {
  size_t found = npos;
  scanOutsideFences(text, [&](size_t &i) {
    if (text[i] != '*') {
      return false;
    }
    const char prevByte = i > 0 ? text[i - 1] : '\0';
    const char nextByte = i + 1 < text.size() ? text[i + 1] : '\0';
    if (prevByte == '*' || nextByte == '*' || prevByte == '\\' || math.inside(i)) {
      return false;
    }
    const uint32_t prev = codePointBefore(text, i);
    const uint32_t next = codePointAt(text, i + 1);
    const bool prevWs = prev == kNoCodePoint || isSpaceTabNewline(prev);
    const bool nextWs = next == kNoCodePoint || isSpaceTabNewline(next);
    // Whitespace on both sides, word-internal, or right-flanking only: not an opener.
    if ((prevWs && nextWs) || (isWordCharUnit(prev) && isWordCharUnit(next)) || nextWs) {
      return false;
    }
    found = i;
    return true;
  });
  return found;
}

// findFirstSingleUnderscoreIndex(): the first _ that can open incomplete italic.
size_t findFirstSingleUnderscoreIndex(std::string_view text, const MathLookup &math, const LineContextLookup &lines) {
  size_t found = npos;
  scanOutsideFences(text, [&](size_t &i) {
    if (text[i] != '_') {
      return false;
    }
    const char prevByte = i > 0 ? text[i - 1] : '\0';
    const char nextByte = i + 1 < text.size() ? text[i + 1] : '\0';
    if (prevByte == '_' || nextByte == '_' || prevByte == '\\' || math.inside(i) || lines.insideLinkUrl(i)) {
      return false;
    }
    if (isWordCharUnit(codePointBefore(text, i)) && isWordCharUnit(codePointAt(text, i + 1))) {
      return false;
    }
    found = i;
    return true;
  });
  return found;
}

// shouldSkipBoldCompletion() / shouldSkipItalicCompletion(): no real content
// after the marker, a multi-line list item, or a horizontal rule.
bool shouldSkipDoubleMarkerCompletion(std::string_view text, std::string_view content, size_t markerIndex,
                                      char hrMarker) {
  if (content.empty() || isWhitespaceOrMarkersOnly(content)) {
    return true;
  }
  if (isListItemMarkerLine(lineBefore(text, markerIndex)) && content.find('\n') != npos) {
    return true;
  }
  return isHorizontalRule(text, markerIndex, hrMarker);
}

} // namespace

// --- Handlers ---------------------------------------------------------------

// /(\*\*\*)([^*]*?)$/
void boldItalic(RepairContext &ctx) {
  const std::string_view text = ctx.text();
  // /^\*{4,}$/ : only asterisks, never emphasis
  if (text.size() >= 4 && text.find_first_not_of('*') == npos) {
    return;
  }
  const auto content = matchTrailingMarker(text, "***", '*', false);
  if (!content) {
    return;
  }
  const size_t markerIndex = text.rfind("***");
  if (content->empty() || isWhitespaceOrMarkersOnly(*content) || ctx.insideAnyCode(markerIndex) ||
      isHorizontalRule(text, markerIndex, '*')) {
    return;
  }
  if (countTripleAsterisks(text) % 2 == 1) {
    // areBoldItalicMarkersBalanced(): `**bold and *italic***` is overlap, not an opener
    if (countDoubleMarkers(text, '*') % 2 == 0 && countSingleAsterisks(text, ctx.math()).count % 2 == 0) {
      return;
    }
    ctx.closeAt(markerIndex, "***");
  }
}

// Reference: /(\*\*)([^*]*\*?)$/ , which gives up as soon as any `*` follows
// the opener, so a nested italic keeps the bold open until the stream ends.
// Ours: close on odd `**` parity whatever the content; closeAt() nests the
// closers, so `**bold *ital` becomes `**bold *ital***`.
void bold(RepairContext &ctx) {
  const std::string_view text = ctx.text();
  const size_t markerIndex = text.rfind("**");
  if (markerIndex == npos) {
    return;
  }
  const std::string_view content = text.substr(markerIndex + 2);
  if (ctx.insideAnyCode(markerIndex) || shouldSkipDoubleMarkerCompletion(text, content, markerIndex, '*')) {
    return;
  }
  if (countDoubleMarkers(text, '*') % 2 != 1) {
    return;
  }
  // **content* : the trailing * is half of the closer unless an italic is
  // still open before it, in which case it closes that italic. (The math
  // lookup is prefix-based, so the full text's lookup is exact here.)
  const bool halfCloser =
      endsWith(content, "*") && countSingleAsterisks(text.substr(0, text.size() - 1), ctx.math()).count % 2 == 0;
  ctx.closeAt(markerIndex, halfCloser ? "*" : "**");
}

// Reference: /(__)([^_]*?)$/ plus the half-closed /(__)([^_]+)_$/ case,
// which like bold gives up as soon as a `_` follows the opener. Ours: parity.
void italicDoubleUnderscore(RepairContext &ctx) {
  const std::string_view text = ctx.text();
  const size_t markerIndex = text.rfind("__");
  if (markerIndex == npos) {
    return;
  }
  const std::string_view content = text.substr(markerIndex + 2);
  if (ctx.insideAnyCode(markerIndex) || shouldSkipDoubleMarkerCompletion(text, content, markerIndex, '_')) {
    return;
  }
  if (countDoubleMarkers(text, '_') % 2 != 1) {
    return;
  }
  // __content_ : same half-closer rule as bold.
  const bool halfCloser =
      endsWith(content, "_") &&
      countSingleUnderscores(text.substr(0, text.size() - 1), ctx.math(), ctx.lines()).count % 2 == 0;
  ctx.closeAt(markerIndex, halfCloser ? "_" : "__");
}

// /(\*)([^*]*?)$/ , which matches any text containing *
void italicSingleAsterisk(RepairContext &ctx) {
  // Full text on purpose: the *** rule in countSingleAsterisks() needs to see
  // a `***` closer already placed to pair the italic it also closes.
  const std::string_view text = ctx.text();
  if (text.find('*') == npos) {
    return;
  }
  const size_t first = findFirstSingleAsteriskIndex(text, ctx.math());
  if (first == npos || ctx.insideAnyCode(first)) {
    return;
  }
  const std::string_view content = text.substr(first + 1);
  if (content.empty() || isWhitespaceOrMarkersOnly(content)) {
    return;
  }
  const DelimiterCount singles = countSingleAsterisks(text, ctx.math());
  if (singles.count % 2 == 1) {
    ctx.closeAt(singles.lastCounted, "*");
  }
}

// /(_)([^_]*?)$/ , which matches any text containing _
void italicSingleUnderscore(RepairContext &ctx) {
  // Text before the closer tail: a `__` closer placed right after the user's
  // closing `_` would otherwise read as `___` and hide that delimiter.
  const std::string_view text = ctx.textBeforeClosers();
  if (text.find('_') == npos) {
    return;
  }
  const size_t first = findFirstSingleUnderscoreIndex(text, ctx.math(), ctx.lines());
  if (first == npos) {
    return;
  }
  const std::string_view content = text.substr(first + 1);
  if (content.empty() || isWhitespaceOrMarkersOnly(content) || ctx.insideAnyCode(first)) {
    return;
  }
  const DelimiterCount singles = countSingleUnderscores(text, ctx.math(), ctx.lines());
  if (singles.count % 2 != 1) {
    return;
  }
  ctx.closeAt(singles.lastCounted, "_");
}

} // namespace Markdown::RepairHandlers
