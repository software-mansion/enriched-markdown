/*
 * Checks the shared document store: one filter and one parse per input, the
 * same tree for every caller, eviction, and concurrent callers on the threads a
 * streaming tick uses, under the thread sanitizer where scripts/test-core-parser.sh
 * can run it.
 */
#include "DocumentStore.hpp"
#include <iostream>
#include <string>
#include <thread>
#include <vector>

namespace {

int failures = 0;

void check(bool condition, const std::string &what) {
  if (!condition) {
    std::cerr << "FAIL: " << what << "\n";
    failures++;
  }
}

} // namespace

int main() {
  auto &store = Markdown::DocumentStore::shared();
  store.clear();
  Markdown::Md4cFlags flags;
  Markdown::StreamingFilterOptions options;
  const std::string tick = "Intro\n\n![a](https://e.com/a.png)\n\nSee [docs](https://e";

  // A tick: collect, measure and render each filter and parse the same text.
  for (int caller = 0; caller < 3; caller++) {
    auto filtered = store.filter(tick, options);
    check(filtered.markdown == "Intro\n\n![a](https://e.com/a.png)\n\nSee ", "filtered text");
    store.parse(filtered.markdown, flags, true);
  }
  check(store.filterCount() == 1 && store.parseCount() == 1, "one filter and one parse per tick (got " +
                                                                 std::to_string(store.filterCount()) + ", " +
                                                                 std::to_string(store.parseCount()) + ")");

  auto first = store.parse("Intro\n\n![a](https://e.com/a.png)\n\nSee ", flags, true);
  auto again = store.parse("Intro\n\n![a](https://e.com/a.png)\n\nSee ", flags, true);
  check(first == again && first->blocks.slots.size() == 1, "callers share one document and its blocks");
  check(store.parse("Intro\n\n![a](https://e.com/a.png)\n\nSee ", flags, false) != first,
        "the flavor is part of the key");
  Markdown::Md4cFlags other = flags;
  other.latexMath = !flags.latexMath;
  check(store.parse("Intro\n\n![a](https://e.com/a.png)\n\nSee ", other, true) != first,
        "the flags are part of the key");
  check(store.parse("", flags, true)->ast == nullptr, "an empty document has no tree");

  // Old entries go, the one in use stays alive.
  for (int i = 0; i < 40; i++)
    store.parse("doc " + std::to_string(i), flags, true);
  size_t before = store.parseCount();
  store.parse("doc 39", flags, true);
  store.parse("doc 0", flags, true);
  check(store.parseCount() == before + 1, "recent documents stay, old ones are parsed again");
  check(first->blocks.slots.size() == 1 && first->ast != nullptr, "an evicted document stays valid for its holder");

  // A streaming tick on three threads at once: they all end up with one tree.
  store.clear();
  std::string longer;
  for (int i = 0; i < 200; i++)
    longer += "Paragraph " + std::to_string(i) + " with [a link](https://e.com/" + std::to_string(i) + ").\n\n";
  std::vector<std::shared_ptr<const Markdown::ParsedDocument>> seen(3);
  std::vector<std::thread> threads;
  for (int t = 0; t < 3; t++) {
    threads.emplace_back([&, t] {
      for (int round = 0; round < 50; round++) {
        auto filtered = store.filter(longer + std::to_string(round), options);
        seen[static_cast<size_t>(t)] = store.parse(filtered.markdown, flags, true);
      }
    });
  }
  for (auto &thread : threads)
    thread.join();
  check(seen[0] == seen[1] && seen[1] == seen[2], "concurrent callers share the last document");

  // A document over the byte budget is still kept while it is the newest.
  store.clear();
  std::string huge(2 * 1024 * 1024, 'x');
  check(store.parse(huge, flags, true) == store.parse(huge, flags, true) && store.parseCount() == 1,
        "the newest document is kept even past the budget");

  if (failures == 0) {
    std::cout << "    document store ok\n";
    return 0;
  }
  return 1;
}
