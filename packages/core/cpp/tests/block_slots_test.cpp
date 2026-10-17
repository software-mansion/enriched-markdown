/*
 * Checks the block slot collector: which blocks are eligible, the id scheme and
 * its stability under appends and inline edits, the shared hash fixture, and
 * the attributes annotate() stamps. See scripts/test-core-parser.sh.
 */
#include "BlockSlots.hpp"
#include "MD4CParser.hpp"
#include <cstdlib>
#include <fstream>
#include <iostream>
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

const Markdown::MarkdownASTNode *findWithAttribute(const Markdown::MarkdownASTNode &node, const std::string &key) {
  if (node.attributes.count(key))
    return &node;
  for (const auto &child : node.children) {
    if (const auto *found = findWithAttribute(*child, key))
      return found;
  }
  return nullptr;
}

std::string suffix(const std::string &id) {
  return id.substr(id.rfind(':'));
}

size_t slotCount(const std::string &markdown) {
  return Markdown::collect(*parse(markdown)).slots.size();
}

// The hash part of an id for a standalone image paragraph of `url`.
std::string hashOf(const std::string &url) {
  auto root = parse("![x](" + url + ")\n");
  auto slots = Markdown::collect(*root).slots;
  if (slots.size() != 1)
    return "";
  std::string id = slots[0].id;
  size_t first = id.find(':');
  size_t last = id.rfind(':');
  return id.substr(first + 1, last - first - 1);
}

} // namespace

int main(int argc, char **argv) {
  using Markdown::BlockSlotKind;
  using Markdown::BlockSlotPlacement;
  using Markdown::ImagePlacement;

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
    check(slots[0].kind == BlockSlotKind::Image && slots[0].placement == BlockSlotPlacement::Root,
          "slot 0 is the root image");
    check(slots[0].altText == "Hero" && slots[0].title == "Hero title", "slot 0 carries alt and title");
    check(slots[1].kind == BlockSlotKind::Link && slots[1].url == "https://e.com" && slots[1].altText == "linked",
          "a linked image paragraph is a link block with the image's alt as label");
    check(slots[2].kind == BlockSlotKind::Image && slots[2].placement == BlockSlotPlacement::Blockquote,
          "slot 2 is the quoted image");
    check(slots[3].kind == BlockSlotKind::Video && slots[3].placement == BlockSlotPlacement::Admonition,
          "slot 3 is the admonition video");
    check(slots[3].altText.empty() && slots[3].title.empty(), "videos carry no alt or title");
    check(slots[4].kind == BlockSlotKind::Video && slots[4].placement == BlockSlotPlacement::Root,
          "slot 4 is the root video");
    check(slots[5].kind == BlockSlotKind::Link && slots[5].altText == "Q3 report.pdf" &&
              slots[5].title == "application/pdf" && slots[5].id.rfind("link:", 0) == 0,
          "the file link is a link block with label and title");
    check(slots[0].id.rfind("image:", 0) == 0 && suffix(slots[0].id) == ":0", "first a.png slot is 0");
    // Slot ids count slots only: the inline a.png in between does not shift the quoted one.
    check(suffix(slots[2].id) == ":1", "quoted a.png is slot 1, got " + slots[2].id);
    check(suffix(slots[3].id) == ":0" && suffix(slots[4].id) == ":1", "videos count per url");
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
    // Occurrence ids count every image of the url: root a.png 0, inline 1, quoted 2, listed quote 3.
    check(suffix(images[4].id) == ":2" && suffix(images[6].id) == ":3", "occurrence ids count all images");
  }

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

  // Annotation stamps only the active ids, on the block node, and image ids on demand.
  std::unordered_set<std::string> active{slots[0].id, slots[4].id};
  Markdown::annotate(*root, active, false);
  int stamped = 0;
  for (const auto &child : root->children) {
    auto it = child->attributes.find(Markdown::kBlockSlotIdAttribute);
    if (it == child->attributes.end())
      continue;
    stamped++;
    if (child->type == Markdown::NodeType::Paragraph) {
      check(it->second == slots[0].id, "the image paragraph carries the slot id");
      check(child->attributes.at(Markdown::kBlockSlotKindAttribute) == "image", "image kind attribute");
    } else {
      check(child->type == Markdown::NodeType::Video && it->second == slots[4].id, "the video carries the slot id");
      check(child->attributes.at(Markdown::kBlockSlotKindAttribute) == "video", "video kind attribute");
    }
  }
  check(stamped == 2, "exactly the active root blocks are stamped (got " + std::to_string(stamped) + ")");
  check(findWithAttribute(*root, Markdown::kImageOccurrenceIdAttribute) == nullptr, "no image ids unless asked for");

  Markdown::annotate(*root, {}, true);
  const auto *image = findWithAttribute(*root, Markdown::kImageOccurrenceIdAttribute);
  check(image != nullptr && image->type == Markdown::NodeType::Image &&
            image->attributes.at(Markdown::kImageOccurrenceIdAttribute) == images[0].id,
        "images carry their occurrence id");

  // A link block stamps "link" on its paragraph.
  auto linkRoot = parse("[Q3 report.pdf](https://e.com/q3.pdf)\n");
  auto linkSlots = Markdown::collect(*linkRoot).slots;
  Markdown::annotate(*linkRoot, {linkSlots[0].id}, false);
  check(linkRoot->children[0]->attributes.at(Markdown::kBlockSlotKindAttribute) == "link", "link kind attribute");

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
      std::string expected = line.substr(tab + 1);
      check(hashOf(url) == expected, "hash of '" + url + "' is " + expected + " (got " + hashOf(url) + ")");
      vectors++;
    }
    check(vectors > 0, "fixture has vectors");
  }

  if (failures == 0) {
    std::cout << "    block slot collector ok\n";
    return 0;
  }
  return 1;
}
