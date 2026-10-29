/*
 * Checks the block slot collector: which blocks are eligible, the id scheme and
 * its stability under appends and inline edits, the shared hash fixture, and
 * the attributes a host converter adds through AstOverlay. See
 * scripts/test-core-parser.sh.
 */
#include "AstOverlay.hpp"
#include "BlockSlots.hpp"
#include "MD4CParser.hpp"
#include "StreamingFilter.hpp"
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
#include <unordered_set>

namespace {

int failures = 0;

void check(bool condition, const std::string &what) {
  if (!condition) {
    std::cerr << "FAIL: " << what << "\n";
    failures++;
  }
}

std::shared_ptr<Markdown::MarkdownASTNode> parse(const std::string &markdown) {
  Markdown::MD4CParser parser;
  return parser.parse(markdown, Markdown::Md4cFlags{}, true);
}

// The attributes AstOverlay adds, by node, after a walk like a host converter's.
std::map<const Markdown::MarkdownASTNode *, std::map<std::string, std::string>>
overlaid(const Markdown::MarkdownASTNode &root, const Markdown::AstOverlay &overlay) {
  std::map<const Markdown::MarkdownASTNode *, std::map<std::string, std::string>> out;
  auto walk = [&](const Markdown::MarkdownASTNode &node, auto &&self) -> void {
    overlay.forEachAttribute(node, [&](const char *key, const std::string &value) { out[&node][key] = value; });
    overlay.forEachChild(node, [&](const std::shared_ptr<Markdown::MarkdownASTNode> &child) { self(*child, self); });
  };
  walk(root, walk);
  return out;
}

std::string suffix(const std::string &id) {
  return id.substr(id.rfind(':'));
}

// A code slot's fields, empty for another kind.
Markdown::CodeSlotFields codeOf(const Markdown::BlockSlot &slot) {
  const auto *fields = std::get_if<Markdown::CodeSlotFields>(&slot.fields);
  return fields ? *fields : Markdown::CodeSlotFields{};
}

size_t slotCount(const std::string &markdown) {
  return Markdown::collect(*parse(markdown)).slots.size();
}

} // namespace

int main(int argc, char **argv) {
  using Markdown::BlockSlotKind;
  using Markdown::BlockSlotPlacement;
  using Markdown::ImagePlacement;
  using Markdown::ImageSlotFields;
  using Markdown::LinkSlotFields;

  const std::string doc =
      "# Title\n\n"
      "![Hero](https://e.com/a.png \"Hero title\")\n\n"
      "Text with ![inline](https://e.com/a.png) image.\n\n"
      "- ![list](https://e.com/b.png)\n\n"
      "[![linked](https://e.com/c.png)](https://e.com)\n\n"
      "> ![quoted](https://e.com/a.png)\n\n"
      "> [!NOTE]\n> <video src=\"https://e.com/v.mp4\"></video>\n\n"
      "<video src=\"https://e.com/v.mp4\"></video>\n\n"
      "| a |\n|---|\n| ![cell](https://e.com/d.png) |\n\n"
      "- > ![listed quote](https://e.com/a.png)\n\n"
      "[Q3 report.pdf](https://e.com/q3.pdf \"application/pdf\")\n";

  auto root = parse(doc);
  check(root != nullptr, "document parses");
  auto collected = Markdown::collect(*root);
  const auto &slots = collected.slots;
  const auto &images = collected.images;

  check(slots.size() == 6,
        "six slots: root image, linked image, quoted image, admonition video, root video, "
        "file link (got " +
            std::to_string(slots.size()) + ")");
  if (slots.size() == 6) {
    const auto *hero = std::get_if<ImageSlotFields>(&slots[0].fields);
    const auto *linked = std::get_if<LinkSlotFields>(&slots[1].fields);
    const auto *quoted = std::get_if<ImageSlotFields>(&slots[2].fields);
    const auto *file = std::get_if<LinkSlotFields>(&slots[5].fields);
    check(hero && slots[0].placement == BlockSlotPlacement::Root, "slot 0 is the root image");
    check(hero && hero->altText == "Hero" && hero->title == "Hero title", "slot 0 carries alt and title");
    check(linked && linked->url == "https://e.com" && linked->label == "linked",
          "a linked image paragraph is a link block with the image's alt as label");
    check(quoted && slots[2].placement == BlockSlotPlacement::Blockquote, "slot 2 is the quoted image");
    check(slots[3].kind() == BlockSlotKind::Video && slots[3].placement == BlockSlotPlacement::Admonition,
          "slot 3 is the admonition video");
    check(slots[4].kind() == BlockSlotKind::Video && slots[4].placement == BlockSlotPlacement::Root,
          "slot 4 is the root video");
    check(file && file->label == "Q3 report.pdf" && file->title == "application/pdf" &&
              slots[5].id.rfind("link:", 0) == 0,
          "the file link is a link block with label and title");
    check(slots[0].id.rfind("image:", 0) == 0 && suffix(slots[0].id) == ":0", "first a.png slot is 0");
    // The hash covers alt and title, so a.png with other text is another block.
    check(slots[2].id != slots[0].id && suffix(slots[2].id) == ":0",
          "quoted a.png has its own hash, got " + slots[2].id);
    check(suffix(slots[3].id) == ":0" && suffix(slots[4].id) == ":1", "identical videos count up");
    check(hero && quoted && hero->occurrenceId == images[0].id && quoted->occurrenceId == images[4].id,
          "image blocks name their occurrence");
    check(collected.slotByNode.at(root->children[1].get()) == 0, "a slot is indexed by the paragraph it replaces");
  }

  check(images.size() == 7, "seven image occurrences (got " + std::to_string(images.size()) + ")");
  if (images.size() == 7) {
    check(images[0].placement == ImagePlacement::Root, "image 0 placement root");
    check(images[1].placement == ImagePlacement::Inline, "image 1 placement inline");
    check(images[2].placement == ImagePlacement::List, "image 2 placement list");
    check(images[3].placement == ImagePlacement::Link, "image 3 placement link");
    check(images[4].placement == ImagePlacement::Blockquote, "image 4 placement blockquote");
    check(images[5].placement == ImagePlacement::Table, "image 5 placement table");
    check(images[6].placement == ImagePlacement::List, "a quote inside a list item is list placement");
    check(images[0].id.rfind("img:", 0) == 0, "occurrence ids have their own prefix");
    for (const auto &slot : slots) {
      for (const auto &image : images)
        check(slot.id != image.id, "a slot id never equals an occurrence id: " + slot.id);
    }
  }

  // Only identical blocks count up, so removing a different earlier one keeps the id.
  auto twins = Markdown::collect(*parse("![a](u)\n\n![b](u)\n\n![a](u)\n")).slots;
  auto withoutB = Markdown::collect(*parse("![a](u)\n\n![a](u)\n")).slots;
  check(twins.size() == 3 && suffix(twins[2].id) == ":1" && twins[1].id != twins[0].id, "identical blocks count up");
  check(withoutB.size() == 2 && withoutB[1].id == twins[2].id, "removing a different block keeps later ids");
  auto withoutFirst = Markdown::collect(*parse("![b](u)\n\n![a](u)\n")).slots;
  check(withoutFirst.size() == 2 && withoutFirst[0].id == twins[1].id, "the other block keeps its id");

  // Appending content keeps earlier ids.
  auto longerSlots = Markdown::collect(*parse(doc + "\n![Tail](https://e.com/a.png)\n")).slots;
  check(longerSlots.size() == slots.size() + 1, "appended block adds one slot");
  for (size_t i = 0; i < slots.size() && i < longerSlots.size(); i++) {
    check(longerSlots[i].id == slots[i].id, "slot id " + std::to_string(i) + " survives an append");
  }

  // An inline image inserted earlier does not shift slot ids.
  auto editedSlots = Markdown::collect(*parse("See ![icon](https://e.com/a.png) first.\n\n" + doc)).slots;
  check(editedSlots.size() == slots.size(), "inline insertion adds no slot");
  for (size_t i = 0; i < slots.size() && i < editedSlots.size(); i++) {
    check(editedSlots[i].id == slots[i].id, "slot id " + std::to_string(i) + " survives an inline insertion");
  }

  // Eligibility edge cases.
  check(slotCount("![a](u) caption\n") == 0, "an image with trailing text is no slot");
  check(slotCount("# ![a](u)\n") == 0, "a heading image is no slot");
  check(slotCount("- > ![a](u)\n") == 0, "a quote inside a list item is no slot");
  check(slotCount("> > ![a](u)\n") == 1, "a nested quote is a slot");
  // The parser hoists a video-only list item out of its list, so it is a block of the quote.
  check(slotCount("> - <video src=\"v\"></video>\n") == 1, "a hoisted video in a quote is a slot");
  check(slotCount("<https://e.com/q3.pdf>\n") == 1, "an autolink paragraph is a link slot");
  check(slotCount("https://e.com/q3.pdf\n") == 1, "a bare url paragraph is a link slot");
  check(slotCount("See [docs](https://e.com)\n") == 0, "a link inside text is no slot");
  check(slotCount("- [docs](https://e.com)\n") == 0, "a link in a list item is no slot");

  // Code blocks, fenced or indented, are slots outside lists; the id hashes the language alone.
  auto fencesRoot = parse(
      "```js\nlet a;\n\n```\n\n"
      "    indented\n\n"
      "```\nplain\n```\n\n"
      "> ```js\n> quoted\n> ```\n\n"
      "> [!NOTE]\n> ```py\n> noted\n> ```\n\n"
      "- ```js\n  listed\n  ```\n");
  auto fences = Markdown::collect(*fencesRoot);
  check(fences.slots.size() == 5,
        "five code slots, none from the list (got " + std::to_string(fences.slots.size()) + ")");
  if (fences.slots.size() == 5) {
    const auto &code = fences.slots;
    for (const auto &slot : code)
      check(slot.kind() == BlockSlotKind::Code && slot.id.rfind("code:", 0) == 0, "a code block is a code slot");
    check(code[0].id == "code:" + Markdown::fnv1a64Hex("js") + ":0",
          "a code id hashes the language, got " + code[0].id);
    check(codeOf(code[0]).language == "js" && codeOf(code[0]).code == "let a;",
          "trailing newlines are trimmed, got '" + codeOf(code[0]).code + "'");
    check(code[0].placement == BlockSlotPlacement::Root && code[0].node == fencesRoot->children[0].get(),
          "the fence slot names its code block");
    check(codeOf(code[1]).language.empty() && codeOf(code[1]).code == "indented", "an indented block has no language");
    check(codeOf(code[2]).language.empty() && codeOf(code[2]).code == "plain", "a fence without a language");
    check(suffix(code[1].id) == ":0" && suffix(code[2].id) == ":1" && code[1].id != code[2].id,
          "blocks without a language count up");
    check(code[3].placement == BlockSlotPlacement::Blockquote && codeOf(code[3]).code == "quoted" &&
              suffix(code[3].id) == ":1" &&
              code[3].id.substr(0, code[3].id.rfind(':')) == code[0].id.substr(0, code[0].id.rfind(':')),
          "a quoted js block counts after the root one");
    check(code[4].placement == BlockSlotPlacement::Admonition && codeOf(code[4]).language == "py" &&
              codeOf(code[4]).code == "noted",
          "an admonition code block is a slot");
  }
  check(fences.lastCodeBlock != nullptr && fences.lastCodeBlock->type == Markdown::NodeType::CodeBlock &&
            fences.slotByNode.count(fences.lastCodeBlock) == 0,
        "the last code block is the one in the list, which is no slot");
  check(Markdown::collect(*parse("Text\n")).lastCodeBlock == nullptr, "no code block, no last code block");

  // A fence keeps its id while its code streams in and when it closes.
  auto openFence = Markdown::collect(*parse("Intro\n\n```js\nlet a"));
  auto closedFence = Markdown::collect(*parse("Intro\n\n```js\nlet a = 1;\nlet b;\n```\n"));
  check(openFence.slots.size() == 1 && closedFence.slots.size() == 1 &&
            openFence.slots[0].id == closedFence.slots[0].id,
        "a growing fence keeps its id");
  check(openFence.slots.size() == 1 && openFence.slots[0].node == openFence.lastCodeBlock &&
            codeOf(openFence.slots[0]).code == "let a",
        "an open fence is the last code block");
  check(closedFence.slots.size() == 1 && codeOf(closedFence.slots[0]).code == "let a = 1;\nlet b;", "multi-line code");

  // Streamed, a fence shows once its opening line ends, so its id holds from the first tick it shows.
  auto streamed = [](const std::string &markdown) {
    return Markdown::collect(*parse(Markdown::renderableMarkdownForStreaming(markdown, {}).markdown)).slots;
  };
  auto final = Markdown::collect(*parse("Intro\n\n```mermaid\ngraph TD\n```\n")).slots;
  check(streamed("Intro\n\n```mer").empty(), "a fence whose language is still streaming is no slot yet");
  for (const char *tick : {"Intro\n\n```mermaid\n", "Intro\n\n```mermaid\ngra", "Intro\n\n```mermaid\ngraph TD\n``"}) {
    auto slots = streamed(tick);
    check(slots.size() == 1 && final.size() == 1 && slots[0].id == final[0].id,
          std::string("a streaming fence has its final id: ") + tick);
  }

  // Only the fence still streaming in is incomplete ('o'), in any container and at a line end.
  auto completeness = [](const std::string &markdown) {
    auto filtered = Markdown::renderableMarkdownForStreaming(markdown, {});
    auto tree = parse(filtered.markdown);
    auto blocks = Markdown::collect(*tree);
    std::string states;
    for (const auto &slot : blocks.slots)
      states += Markdown::isSlotComplete(blocks, slot, filtered.endsInsideOpenCodeFence) ? 'c' : 'o';
    return states;
  };
  const std::pair<const char *, const char *> completenessTicks[] = {
      {"```py\nx\n```\n\n```js\nlet a", "co"},
      {"```py\nx\n```\n\n```js\nlet a\n", "co"},
      {"```py\nx\n```\n\n```js\nlet a\n```", "cc"},
      {"> ```js\n> let a", "o"},
      {"> ```js\n> let a\n", "o"},
      {"> ```js\n> let a\n> ```\n", "c"},
      {"> [!NOTE]\n> ```py\n> x\n", "o"},
      {"```py\nx\n```\n\n- ```js\n  let a\n", "c"},
  };
  for (const auto &[tick, states] : completenessTicks) {
    std::string got = completeness(tick);
    check(got == states, std::string("completeness of ") + tick + ": expected " + states + ", got " + got);
  }
  check(fences.slots.empty() || Markdown::isSlotComplete(fences, fences.slots.back(), false),
        "without an open fence even the last code block is complete");

  // The overlay adds only the active ids, on the block node, and image ids on demand.
  Markdown::ParsedDocument document{root, collected};
  std::unordered_set<std::string> active{slots[0].id, slots[4].id};
  auto added = overlaid(*root, Markdown::AstOverlay(document, active, false, {}));
  int withIds = 0;
  for (const auto &child : root->children) {
    auto attributes = added.find(child.get());
    if (attributes == added.end())
      continue;
    withIds++;
    if (child->type == Markdown::NodeType::Paragraph) {
      check(attributes->second[Markdown::kBlockSlotIdAttribute] == slots[0].id, "the image paragraph gets the slot id");
      check(attributes->second[Markdown::kBlockSlotKindAttribute] == "image", "image kind attribute");
    } else {
      check(child->type == Markdown::NodeType::Video &&
                attributes->second[Markdown::kBlockSlotIdAttribute] == slots[4].id,
            "the video gets the slot id");
      check(attributes->second[Markdown::kBlockSlotKindAttribute] == "video", "video kind attribute");
    }
  }
  check(withIds == 2 && added.size() == 2,
        "exactly the active root blocks get ids (got " + std::to_string(withIds) + ")");

  std::unordered_set<std::string> none;
  auto imageIds = overlaid(*root, Markdown::AstOverlay(document, none, true, {}));
  check(imageIds.size() == images.size(), "every image gets its occurrence id");
  const auto *firstImage = root->children[1]->children[0].get();
  check(imageIds[firstImage][Markdown::kImageOccurrenceIdAttribute] == images[0].id, "images carry their id");
  check(root->children[1]->attributes.count(Markdown::kBlockSlotIdAttribute) == 0, "the shared tree is not written to");

  // A link block adds "link" on its paragraph.
  auto linkRoot = parse("[Q3 report.pdf](https://e.com/q3.pdf)\n");
  Markdown::ParsedDocument linkDocument{linkRoot, Markdown::collect(*linkRoot)};
  std::unordered_set<std::string> linkActive{linkDocument.blocks.slots[0].id};
  auto linkAdded = overlaid(*linkRoot, Markdown::AstOverlay(linkDocument, linkActive, false, {}));
  check(linkAdded[linkRoot->children[0].get()][Markdown::kBlockSlotKindAttribute] == "link", "link kind attribute");

  // A code block adds "code" on the CodeBlock node itself.
  Markdown::ParsedDocument fenceDocument{fencesRoot, fences};
  std::unordered_set<std::string> fenceActive{fences.slots[0].id};
  auto fenceAdded = overlaid(*fencesRoot, Markdown::AstOverlay(fenceDocument, fenceActive, false, {}));
  check(fenceAdded.size() == 1 &&
            fenceAdded[fencesRoot->children[0].get()][Markdown::kBlockSlotKindAttribute] == "code",
        "code kind attribute on the code block");

  // Recognized links replace the text they cover only in the overlay's view.
  auto textRoot = parse("Ticket TICKET-1 is open\n");
  Markdown::TextLinkMatchers matchers;
  matchers.text = [](const std::vector<std::string_view> &runs) {
    std::vector<std::vector<Markdown::TextRange>> all;
    for (auto run : runs) {
      size_t at = run.find("TICKET-1");
      all.push_back(at == std::string_view::npos ? std::vector<Markdown::TextRange>{}
                                                 : std::vector<Markdown::TextRange>{{at, at + 8}});
    }
    return all;
  };
  Markdown::ParsedDocument textDocument{textRoot, Markdown::collect(*textRoot)};
  Markdown::AstOverlay textOverlay(textDocument, none, false, Markdown::recognizeTextLinks(*textRoot, matchers));
  std::vector<Markdown::NodeType> seen;
  textOverlay.forEachChild(*textRoot->children[0], [&](const auto &child) { seen.push_back(child->type); });
  check(seen.size() == 3 && seen[1] == Markdown::NodeType::Link, "the overlay shows text, link, text");
  check(textRoot->children[0]->children.size() == 1, "the parsed paragraph keeps its one text node");

  // A recognized code span becomes a link around the very Code node it replaces.
  auto codeRoot = parse("See `TICKET-2` now\n");
  Markdown::TextLinkMatchers codeMatchers;
  codeMatchers.inlineCode = [](const std::vector<std::string_view> &spans) {
    std::vector<uint8_t> matched;
    for (auto span : spans)
      matched.push_back(span == "TICKET-2");
    return matched;
  };
  Markdown::ParsedDocument codeDocument{codeRoot, Markdown::collect(*codeRoot)};
  Markdown::AstOverlay codeOverlay(codeDocument, none, false, Markdown::recognizeTextLinks(*codeRoot, codeMatchers));
  std::vector<Markdown::NodeType> linkChildren;
  codeOverlay.forEachChild(*codeRoot->children[0], [&](const auto &child) {
    if (child->type == Markdown::NodeType::Link)
      codeOverlay.forEachChild(*child, [&](const auto &inner) { linkChildren.push_back(inner->type); });
  });
  check(linkChildren.size() == 1 && linkChildren[0] == Markdown::NodeType::Code,
        "a recognized code link keeps its Code child instead of replacing it again");

  // The shared hash fixture pins the id hash for the web twin.
  if (argc > 1) {
    std::ifstream fixture(argv[1]);
    check(fixture.good(), std::string("fixture readable: ") + argv[1]);
    std::string line;
    int vectors = 0;
    while (std::getline(fixture, line)) {
      if (line.empty() || line[0] == '#')
        continue;
      size_t tab = line.find('\t');
      std::string url = line.substr(0, tab);
      for (size_t at = url.find("\\u001f"); at != std::string::npos; at = url.find("\\u001f", at))
        url.replace(at, 6, "\x1f");
      std::string expected = line.substr(tab + 1);
      std::string got = Markdown::fnv1a64Hex(url);
      check(got == expected, "hash of '" + url + "' is " + expected + " (got " + got + ")");
      vectors++;
    }
    check(vectors > 0, "fixture has vectors");
  }

  // A shared document pins whole ids, text extraction included, for the web twin.
  if (argc > 3) {
    std::ifstream document(argv[2]);
    std::stringstream markdown;
    markdown << document.rdbuf();
    auto shared = Markdown::collect(*parse(markdown.str()));
    std::vector<std::string> got;
    for (const auto &slot : shared.slots)
      got.push_back(slot.id);
    for (const auto &image : shared.images)
      got.push_back(image.id);
    std::ifstream expectedFile(argv[3]);
    std::vector<std::string> expected;
    for (std::string line; std::getline(expectedFile, line);) {
      if (!line.empty() && line[0] != '#')
        expected.push_back(line);
    }
    check(!expected.empty() && got == expected, "the shared document collects the pinned ids");
  }

  if (failures == 0) {
    std::cout << "    block slot collector ok\n";
    return 0;
  }
  return 1;
}
