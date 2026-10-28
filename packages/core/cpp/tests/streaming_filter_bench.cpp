/*
 * Guards the streaming filter's cost per tick: it runs on every streamed token,
 * so it must stay linear in the trailing block. Each input is measured against
 * the same amount of plain prose, so the check holds on any machine; it fails
 * when an input costs more than kMaxRatio times its baseline.
 * See scripts/test-core-parser.sh.
 */
#include "StreamingFilter.hpp"
#include <chrono>
#include <cstdio>
#include <string>

namespace {

// Linear inputs land within a few times prose; a quadratic one is hundreds.
constexpr double kMaxRatio = 25.0;

double microsPerCall(const std::string &markdown) {
  Markdown::StreamingFilterOptions options;
  int reps = 0;
  auto start = std::chrono::steady_clock::now();
  std::chrono::duration<double, std::micro> elapsed{};
  do {
    volatile size_t sink = Markdown::renderableMarkdownForStreaming(markdown, options).markdown.size();
    (void)sink;
    reps++;
    elapsed = std::chrono::steady_clock::now() - start;
  } while (elapsed.count() < 20000 && reps < 2000);
  return elapsed.count() / reps;
}

std::string repeat(const std::string &unit, size_t bytes) {
  std::string text;
  while (text.size() < bytes)
    text += unit;
  return text;
}

} // namespace

int main() {
  struct Case {
    const char *name;
    std::string markdown;
  };
  const size_t size = 50000;
  const std::string baseline = repeat("plain prose words ", size);
  const Case cases[] = {
      {"single line of links", repeat("see [l](https://e.com/x) ", size) + "tail"},
      {"nested brackets", std::string(size / 2, '[') + std::string(size / 2, ']') + " x"},
      {"unclosed brackets", "x " + repeat("[a ", size)},
      {"closed labels", "x " + repeat("[a] ", size)},
      {"backtick runs", repeat("`` x ` ", size)},
      {"lines of links", repeat("see [l](https://e.com/x)\n", size)},
      {"open destinations", repeat("[x](", size) + " z"},
      {"destinations with text", repeat("[x](a", size) + " z"},
  };
  double base = microsPerCall(baseline);
  int failures = 0;
  for (const auto &entry : cases) {
    double cost = microsPerCall(entry.markdown);
    double ratio = cost / base;
    std::printf("    %-22s %8.1f us  (%.1fx prose)\n", entry.name, cost, ratio);
    if (ratio > kMaxRatio) {
      std::fprintf(stderr, "FAIL: %s costs %.1fx the prose baseline\n", entry.name, ratio);
      failures++;
    }
  }
  return failures == 0 ? 0 : 1;
}
