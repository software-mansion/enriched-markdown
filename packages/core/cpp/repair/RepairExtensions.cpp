// Closers for md4c extensions the reference does not know about: spoilers
// (`||text||`, always on in our parser), highlight (`==text==`), superscript
// (`^text^`) and subscript (`~text~`). Without these an open span streams as
// literal text and flips to styled when its closer arrives.
//
// Delimiter rules follow md4c: a run of exactly the marker's width outside
// code is a delimiter; a single-character opener cannot be followed by
// whitespace and a single-character closer cannot follow whitespace.
#include "RepairInternal.hpp"

namespace Markdown::RepairHandlers {

using namespace RepairInternal;

namespace {

bool isWhitespaceByte(char c) {
  return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}

// Walks runs of `c` outside fenced and inline code, pairing openers with
// closers like md4c does, and returns the index of the unmatched opener that
// is still open at the end, or npos. `width` is the exact run length that
// counts as a delimiter (1 for ^ and ~, 2 for || and ==); other run lengths
// are literal. `flanking` applies the single-character whitespace rules.
size_t openSpanIndex(std::string_view text, const CodeLookup &code, char c, size_t width, bool flanking) {
  std::vector<size_t> openers;
  size_t i = 0;
  while (i < text.size()) {
    if (text[i] == '\\') {
      i += 2;
      continue;
    }
    if (text[i] != c) {
      ++i;
      continue;
    }
    size_t run = 1;
    while (i + run < text.size() && text[i + run] == c) {
      ++run;
    }
    if (run == width && !code.inside(i)) {
      const bool beforeWs = i + run >= text.size() || isWhitespaceByte(text[i + run]);
      const bool afterWs = i == 0 || isWhitespaceByte(text[i - 1]);
      const bool canOpen = !flanking || !beforeWs;
      const bool canClose = !flanking || !afterWs;
      if (canClose && !openers.empty()) {
        openers.pop_back();
      } else if (canOpen) {
        openers.push_back(i);
      }
    }
    i += run;
  }
  return openers.empty() ? npos : openers.back();
}

void closeSpan(RepairContext &ctx, char c, size_t width, bool flanking) {
  // Text before the closer tail: these run last and must not read another
  // handler's closer as their own delimiter.
  const std::string_view text = ctx.textBeforeClosers();
  const size_t opener = openSpanIndex(text, ctx.code(), c, width, flanking);
  if (opener == npos) {
    return;
  }
  const std::string_view content = text.substr(opener + width);
  if (content.empty() || isWhitespaceOrMarkersOnly(content)) {
    return;
  }
  if (flanking && isWhitespaceByte(content.back())) {
    return; // a closer here would follow whitespace and not count
  }
  ctx.closeAt(opener, std::string(width, c));
}

} // namespace

void spoilers(RepairContext &ctx) {
  closeSpan(ctx, '|', 2, false);
}

void highlight(RepairContext &ctx) {
  closeSpan(ctx, '=', 2, false);
}

void superscript(RepairContext &ctx) {
  closeSpan(ctx, '^', 1, true);
}

void subscript(RepairContext &ctx) {
  closeSpan(ctx, '~', 1, true);
}

} // namespace Markdown::RepairHandlers
