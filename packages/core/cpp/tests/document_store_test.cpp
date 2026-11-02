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

  // Strikethrough is an additive opt-in; the option also separates cached trees.
  for (bool gfm : {false, true}) {
    auto defaults = store.parse("~~struck~~", {}, gfm);
    for (bool enabled : {false, true, false}) {
      Markdown::Md4cFlags strikeFlags;
      strikeFlags.strikethrough = enabled;
      auto document = store.parse("~~struck~~", strikeFlags, gfm);
      auto span = document->ast->children.at(0)->children.at(0);
      bool strikes = gfm || enabled;
      check(span->type == (strikes ? Markdown::NodeType::Strikethrough : Markdown::NodeType::Text),
            "strikethrough follows flavor or explicit opt-in");
      check((strikes ? span->children.at(0)->content : span->content) == (strikes ? "struck" : "~~struck~~"),
            "only enabled strikethrough removes delimiters");
      check((document == defaults) == !enabled, "strikethrough cache separation and reuse");
    }
  }

  Markdown::Md4cFlags strikeFlags;
  strikeFlags.strikethrough = true;
  // Compare the complete inline tree with the existing GFM delimiter behavior.
  for (bool subscript : {false, true}) {
    strikeFlags.subscript = subscript;
    for (const std::string &markdown : {"~~*nested*~~", "~~one~~ and ~~two~~", "\\~\\~escaped~~", "`~~code~~`",
                                        "~~unmatched", "", "~sub~ ~~struck~~"}) {
      auto common = store.parse(markdown, strikeFlags, false)->ast;
      auto github = store.parse(markdown, strikeFlags, true)->ast;
      std::vector<std::pair<decltype(common), decltype(github)>> pending{{common, github}};
      while (!pending.empty()) {
        auto nodes = pending.back();
        pending.pop_back();
        if (!nodes.first || !nodes.second) {
          check(nodes.first == nodes.second, "empty trees match");
          continue;
        }
        check(nodes.first->type == nodes.second->type && nodes.first->content == nodes.second->content &&
                  nodes.first->attributes == nodes.second->attributes &&
                  nodes.first->children.size() == nodes.second->children.size(),
              "enabled CommonMark matches GFM inline parsing: " + markdown);
        for (size_t i = 0; i < nodes.first->children.size() && i < nodes.second->children.size(); i++)
          pending.emplace_back(nodes.first->children[i], nodes.second->children[i]);
      }
    }
  }
  // Single tildes strike as well, unless subscript claims them.
  for (bool subscript : {false, true}) {
    strikeFlags.subscript = subscript;
    auto paragraph = store.parse("the ~draft~ version", strikeFlags, false)->ast->children.at(0);
    check(paragraph->children.at(1)->type ==
              (subscript ? Markdown::NodeType::Subscript : Markdown::NodeType::Strikethrough),
          "a single tilde follows the subscript flag");
  }
  auto table = store.parse("| A | B |\n|---|---|\n| a | b |", strikeFlags, false)->ast;
  check(table->children.at(0)->type == Markdown::NodeType::Paragraph, "strikethrough does not enable tables");
  auto task = store.parse("- [x] task", strikeFlags, false)->ast->children.at(0)->children.at(0);
  check(task->children.at(0)->children.at(0)->content == "[x] task", "strikethrough does not enable task lists");

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
