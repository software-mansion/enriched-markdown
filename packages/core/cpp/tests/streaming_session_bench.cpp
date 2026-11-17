/*
 * Guards the streaming session's cost per tick: it runs on every streamed token,
 * so it must stay linear in the unfinished tail. Each input is measured against
 * the same amount of plain prose, so the check holds on any machine; it fails
 * when an input costs more than kMaxRatio times its baseline. A long document
 * of finished paragraphs must cost a small fraction of preparing it whole.
 * See scripts/test-core-parser.sh.
 */
#include "MarkdownRepair.hpp"
#include "StreamingSession.hpp"
#include <chrono>
#include <cstdio>
#include <string>

namespace {

// Linear inputs land within a few times prose; a quadratic one is hundreds.
constexpr double kMaxRatio = 25.0;

template <typename Prepare> double microsPerCall(Prepare prepare) {
  int reps = 0;
  auto start = std::chrono::steady_clock::now();
  std::chrono::duration<double, std::micro> elapsed{};
  do {
    volatile size_t sink = prepare().size();
    (void)sink;
    reps++;
    elapsed = std::chrono::steady_clock::now() - start;
  } while (elapsed.count() < 20000 && reps < 2000);
  return elapsed.count() / reps;
}

double sessionMicros(const std::string &markdown) {
  return microsPerCall([&] { return Markdown::streamingSnapshot(markdown, {}).markdown; });
}

// Filtering and repairing the whole document, the work the session spares.
double wholeMicros(const std::string &markdown) {
  return microsPerCall([&] {
    std::string text = Markdown::renderableMarkdownForStreaming(markdown, {}).markdown;
    Markdown::repairInlineMarkdownInPlace(text, Markdown::streamingRepairOptions({}));
    return text;
  });
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
  double base = sessionMicros(baseline);
  int failures = 0;
  for (const auto &entry : cases) {
    double cost = sessionMicros(entry.markdown);
    double ratio = cost / base;
    std::printf("    %-22s %8.1f us  (%.1fx prose)\n", entry.name, cost, ratio);
    if (ratio > kMaxRatio) {
      std::fprintf(stderr, "FAIL: %s costs %.1fx the prose baseline\n", entry.name, ratio);
      failures++;
    }
  }

  // An 80 KB answer of finished paragraphs with a sentence still arriving.
  const std::string document =
      repeat("A finished paragraph with **bold**, `code` and a [link](https://e.com/x).\n\n", 80000) +
      "The last one is still **arriv";
  double session = sessionMicros(document);
  double whole = wholeMicros(document);
  std::printf("    80 KB document         %8.1f us, whole %.1f us (%.0f%%)\n", session, whole, 100 * session / whole);
  if (session > whole / 4) {
    std::fprintf(stderr, "FAIL: preparing a long document costs %.0f%% of preparing it whole\n", 100 * session / whole);
    failures++;
  }
  return failures == 0 ? 0 : 1;
}
