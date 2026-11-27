/*
 * Times the input's markdown import and export on documents of 10,000 and
 * 50,000 characters. `onChangeMarkdown` serializes the whole document on every
 * keystroke, so `serialize` has to stay far below a frame (the budget on a
 * mid-range phone is 1 ms for 10,000 characters). The absolute numbers depend
 * on the machine and are only printed; the check that fails is linearity: a
 * document five times longer may cost no more than kMaxGrowth times as much per
 * character, which catches a quadratic scan on any machine.
 * See scripts/test-core-parser.sh.
 */
#include "MarkdownInput.hpp"
#include <chrono>
#include <cstdio>
#include <string>

namespace {

using namespace Markdown::Input;

// A fivefold document within this many times the per-character cost is linear.
constexpr double kMaxGrowth = 3.0;

template <class F> double microsPerCall(F &&call) {
  int reps = 0;
  const auto start = std::chrono::steady_clock::now();
  std::chrono::duration<double, std::micro> elapsed{};
  do {
    call();
    reps++;
    elapsed = std::chrono::steady_clock::now() - start;
  } while (elapsed.count() < 50000 && reps < 5000);
  return elapsed.count() / reps;
}

std::u16string repeatTo(const std::u16string &unit, size_t chars) {
  std::u16string text;
  while (text.size() < chars) {
    text += unit;
  }
  return text;
}

struct Shape {
  const char *name;
  std::u16string unit;
};

// What parse and serialize cost for one document, in microseconds.
struct Cost {
  double parse;
  double serialize;
  size_t formattingRanges;
  size_t blockRanges;
};

Cost measure(const std::u16string &markdown) {
  const ParseResult model = parse(markdown);
  Cost cost{};
  cost.formattingRanges = model.formattingRanges.size();
  cost.blockRanges = model.blockRanges.size();
  cost.parse = microsPerCall([&] {
    volatile size_t sink = parse(markdown).plainText.size();
    (void)sink;
  });
  cost.serialize = microsPerCall([&] {
    volatile size_t sink = serialize(model.plainText, model.formattingRanges, model.blockRanges).size();
    (void)sink;
  });
  return cost;
}

} // namespace

int main() {
  const Shape shapes[] = {
      {"notes (headings, lists, styles)",
       u"# Release notes\n\nWe **fixed** the *flaky* sync and [documented it](https://e.com/docs/sync) with ~~old~~ "
       u"new "
       u"_steps_ — \U0001F600 done.\n\n- first item with `code` and a_b\n  - nested item, **bold** inside\n    - "
       u"deeper still\n- last item\n\n1. fetch\n2. rebase\n3. push\n\n"},
      {"plain prose", u"The quick brown fox jumps over the lazy dog and keeps on running through the field.\n"},
      {"escapes", u"2 * 3 = 6, a_b_c, [x], #tag, 1. not a list, > not a quote, ~~ and || and <b> & &amp; \\ done\n"},
      {"one long styled line", u"**bold** plain *italic* plain [link](https://e.com/x) plain ~~gone~~ plain "},
      {"list items", u"- item one\n- item two with **bold**\n  1. nested\n  2. numbers\n"},
      {"headings", u"## A heading with *style*\nand a line below it\n"},
  };

  std::printf("    %-34s %9s %9s %9s %9s\n", "document", "parse 10k", "parse 50k", "ser. 10k", "ser. 50k");
  int failures = 0;
  for (const Shape &shape : shapes) {
    const Cost small = measure(repeatTo(shape.unit, 10000));
    const Cost large = measure(repeatTo(shape.unit, 50000));
    std::printf("    %-34s %7.0f us %7.0f us %7.0f us %7.0f us   (%zu styles, %zu blocks at 10k)\n", shape.name,
                small.parse, large.parse, small.serialize, large.serialize, small.formattingRanges, small.blockRanges);
    const struct {
      const char *what;
      double small, large;
    } checks[] = {{"parse", small.parse, large.parse}, {"serialize", small.serialize, large.serialize}};
    for (const auto &check : checks) {
      const double growth = check.large / check.small / 5.0;
      if (growth > kMaxGrowth) {
        std::fprintf(stderr, "FAIL: %s of \"%s\" costs %.1fx more per character at 50,000 than at 10,000\n", check.what,
                     shape.name, growth);
        failures++;
      }
    }
  }
  return failures == 0 ? 0 : 1;
}
