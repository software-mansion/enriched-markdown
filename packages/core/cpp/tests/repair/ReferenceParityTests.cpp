// Runs every case in ReferenceCases.cpp through the port and asserts byte
// equality with the recorded output.
#include <string>

#include "MarkdownRepair.hpp"
#include "ReferenceCases.hpp"
#include "RepairInternal.hpp"
#include "doctest/doctest.h"

namespace {

// Makes control characters visible in failure output.
std::string show(std::string_view s) {
  std::string out;
  for (const char c : s) {
    if (c == '\n') {
      out += "\\n";
    } else if (c == '\t') {
      out += "\\t";
    } else {
      out.push_back(c);
    }
  }
  return out;
}

} // namespace

TEST_CASE("reference parity: recorded cases") {
  REQUIRE(ReferenceCases::kCaseCount > 100);
  for (size_t i = 0; i < ReferenceCases::kCaseCount; ++i) {
    const ReferenceCases::Case &c = ReferenceCases::kCases[i];
    const std::string actual = Markdown::repairInlineMarkdown(c.input, c.options);
    CHECK_MESSAGE(actual == c.expected, "case " << i << "\ninput:    " << show(c.input) << "\nexpected: "
                                                << show(c.expected) << "\nactual:   " << show(actual));
  }
}

TEST_CASE("reference parity: exported helpers") {
  using ReferenceCases::Helper;
  REQUIRE(ReferenceCases::kHelperCallCount > 0);
  for (size_t i = 0; i < ReferenceCases::kHelperCallCount; ++i) {
    const ReferenceCases::HelperCall &h = ReferenceCases::kHelperCalls[i];
    bool actual = false;
    switch (h.fn) {
      case Helper::IsWordChar:
        actual = Markdown::isWordChar(h.argument);
        break;
      case Helper::IsWithinCodeBlock:
        actual = Markdown::isWithinCodeBlock(h.text, h.argument);
        break;
      case Helper::IsWithinMathBlock:
        actual = Markdown::isWithinMathBlock(h.text, h.argument);
        break;
      case Helper::IsWithinLinkOrImageUrl:
        actual = Markdown::isWithinLinkOrImageUrl(h.text, h.argument);
        break;
    }
    CHECK_MESSAGE(actual == h.expected, "helper call " << i << " (" << show(h.text) << ", " << h.argument << ")");
  }
}

// The forward-pass lookup must agree with the backward-walking public
// functions on every position of every recorded input, so the recorded cases
// double as an oracle for the fast path.
TEST_CASE("line-context lookup agrees with the reference helpers") {
  size_t positions = 0;
  for (size_t i = 0; i < ReferenceCases::kCaseCount; ++i) {
    const std::string_view text = ReferenceCases::kCases[i].input;
    const Markdown::RepairInternal::LineContextLookup lookup(text);
    for (size_t p = 0; p <= text.size(); ++p, ++positions) {
      CHECK_MESSAGE(lookup.insideLinkUrl(p) == Markdown::isWithinLinkOrImageUrl(text, p),
                    "insideLinkUrl(" << show(text) << ", " << p << ")");
      CHECK_MESSAGE(lookup.insideHtmlTag(p) == Markdown::RepairInternal::isWithinHtmlTag(text, p),
                    "insideHtmlTag(" << show(text) << ", " << p << ")");
    }
  }
  // Shapes the recorded cases do not cover: an unclosed URL, a bare paren
  // after a link paren, nested link parens, a paren inside inline code.
  for (const std::string_view text : {"[a](url _x", "[a](b(c) d) e", "[a](b [c](d) e) f", "x (y) [a](z)",
                                      "<a href=\"_x\">_y</a> <b _c", "a\n(b) [c](d\ne)"}) {
    const Markdown::RepairInternal::LineContextLookup lookup(text);
    for (size_t p = 0; p <= text.size(); ++p, ++positions) {
      CHECK_MESSAGE(lookup.insideLinkUrl(p) == Markdown::isWithinLinkOrImageUrl(text, p),
                    "insideLinkUrl(" << show(text) << ", " << p << ")");
      CHECK_MESSAGE(lookup.insideHtmlTag(p) == Markdown::RepairInternal::isWithinHtmlTag(text, p),
                    "insideHtmlTag(" << show(text) << ", " << p << ")");
    }
  }
  CHECK(positions > 10000);
}

namespace {

// isBracketNotALink() as it was before the per-line lookup: the same
// predicate, walking back to the line start for every query. It is the
// oracle here, so keep it as it was even if the fast path changes.
bool referenceIsBracketNotALink(std::string_view text, size_t idx) {
  using namespace Markdown::RepairInternal;
  const char next = idx + 1 < text.size() ? text[idx + 1] : '\0';
  const char prev = idx > 0 ? text[idx - 1] : '\0';
  if (next == '^' || prev == ']' || isEscaped(text, idx)) {
    return true;
  }
  std::string_view line = jsTrimStart(lineBefore(text, idx));
  bool inBlockquote = false;
  while (!line.empty() && line[0] == '>') {
    line = jsTrimStart(line.substr(1));
    inBlockquote = true;
  }
  if (inBlockquote && line.empty() && next == '!') {
    return true;
  }
  const size_t marker = skipListMarker(line);
  if (marker == npos || marker >= line.size() || !jsTrimStart(line.substr(marker)).empty()) {
    return false;
  }
  const bool checkbox = (next == 'x' || next == 'X') && (idx + 2 >= text.size() || text[idx + 2] == ']');
  return next == '\0' || next == ' ' || next == ']' || checkbox;
}

// Only `[` positions, the predicate's contract.
void checkBracketPredicateAgrees(std::string_view text, size_t &brackets) {
  const Markdown::RepairInternal::LineMarkerLookup markers(text);
  for (size_t p = 0; p < text.size(); ++p) {
    if (text[p] != '[') {
      continue;
    }
    ++brackets;
    CHECK_MESSAGE(Markdown::RepairInternal::isBracketNotALink(text, p, markers) == referenceIsBracketNotALink(text, p),
                  "isBracketNotALink(" << show(text) << ", " << p << ")");
  }
}

} // namespace

// The per-line marker lookup must classify every position the way the
// backward walk did, on every recorded input plus the marker shapes the
// recorded cases are thin on.
TEST_CASE("line-marker lookup agrees with the backward-walking bracket predicate") {
  size_t brackets = 0;
  for (size_t i = 0; i < ReferenceCases::kCaseCount; ++i) {
    checkBracketPredicateAgrees(ReferenceCases::kCases[i].input, brackets);
  }
  for (const std::string_view text : {"- [ ] a",
                                      "- [x] b",
                                      "- [X]",
                                      "- [",
                                      "-[",
                                      "- x [",
                                      "1. [ ] c",
                                      "12. [",
                                      "1.[",
                                      "12[",
                                      "  * [ ]",
                                      "> [!NOTE] b",
                                      "> > [!",
                                      "> [x",
                                      ">[!",
                                      "> - [ ] y",
                                      "a > [",
                                      "a [^1] b",
                                      "[a][b]",
                                      "\\[x",
                                      "[a](b) [",
                                      "\u00a0- [ ] nbsp",
                                      "x\n- [ ] y\n> [!\n\n[",
                                      "\n",
                                      "a\n",
                                      "[",
                                      ""}) {
    checkBracketPredicateAgrees(text, brackets);
  }
  MESSAGE("bracket positions checked: " << brackets);
  CHECK(brackets > 150);
}
