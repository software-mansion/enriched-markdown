/*
 * A streamed document is parsed in parts: its finished blocks once, the rest on
 * every update (DocumentStore). Streams the fixtures and generated documents
 * through the store a byte at a time and in three random chunkings, and checks
 * each state against parsing its text whole: the same tree, slots, images and
 * links. Also checks that the finished blocks keep their nodes from one update
 * to the next.
 * See scripts/test-core-parser.sh.
 */
#include "DocumentStore.hpp"
#include <algorithm>
#include <fstream>
#include <iostream>
#include <map>
#include <random>
#include <sstream>
#include <string>
#include <vector>

namespace {

using namespace Markdown;

int failures = 0;

std::string readFile(const std::string &path) {
  std::ifstream file(path);
  std::stringstream buffer;
  buffer << file.rdbuf();
  return buffer.str();
}

void dump(const MarkdownASTNode &node, std::string &out) {
  out += '(' + std::to_string(static_cast<int>(node.type)) + ' ' + node.content;
  std::map<std::string, std::string> sorted(node.attributes.begin(), node.attributes.end());
  for (const auto &[key, value] : sorted)
    out += " {" + key + '=' + value + '}';
  for (const auto &child : node.children)
    dump(*child, out);
  out += ')';
}

// A node's position in the tree, so two trees' slot and image maps compare.
void indexNodes(const MarkdownASTNode &node, std::map<const MarkdownASTNode *, size_t> &index) {
  size_t next = index.size();
  index[&node] = next;
  for (const auto &child : node.children)
    indexNodes(*child, index);
}

std::string describe(const ParsedDocument &document) {
  std::string out;
  if (!document.ast)
    return "(empty)";
  dump(*document.ast, out);
  std::map<const MarkdownASTNode *, size_t> index;
  indexNodes(*document.ast, index);
  for (const auto &slot : document.blocks.slots)
    out += "\nslot " + slot.id + " at " + std::to_string(index.at(slot.node)) + " in " +
           blockSlotPlacementName(slot.placement);
  for (const auto &image : document.blocks.images)
    out += "\nimage " + image.id + ' ' + image.url + ' ' + image.altText + ' ' + image.title + ' ' +
           imagePlacementName(image.placement);
  for (const auto &link : document.blocks.links)
    out += "\nlink " + link.url + ' ' + link.label + ' ' + link.title;
  for (const auto &[node, slot] : document.blocks.slotByNode)
    if (document.blocks.slots.at(slot).node != node)
      out += "\nslotByNode is off";
  std::vector<std::string> images;
  for (const auto &[node, image] : document.blocks.imageByNode)
    images.push_back("\nimageByNode " + std::to_string(index.at(node)) + ' ' + std::to_string(image));
  std::sort(images.begin(), images.end());
  for (const auto &line : images)
    out += line;
  out += "\nlastCodeBlock " +
         (document.blocks.lastCodeBlock ? std::to_string(index.at(document.blocks.lastCodeBlock)) : "none");
  return out;
}

ParsedDocument parseWhole(const std::string &markdown, const Md4cFlags &flags, bool isGFM) {
  ParsedDocument document;
  if (markdown.empty())
    return document;
  std::shared_ptr<MarkdownASTNode> ast = MD4CParser().parse(markdown, flags, isGFM);
  if (ast)
    document.blocks = collect(*ast);
  document.ast = std::move(ast);
  return document;
}

struct Variant {
  const char *name;
  StreamingOptions options;
  bool isGFM;
};

std::vector<Variant> variants() {
  std::vector<Variant> all;
  all.push_back({"github", {}, true});
  all.push_back({"commonmark", {}, false});
  Variant hidden{"github, hidden blocks", {}, true};
  hidden.options.blocks.tableMode = StreamingBlockMode::Hidden;
  hidden.options.blocks.codeBlockMode = StreamingBlockMode::Hidden;
  hidden.options.blocks.mediaMode = StreamingBlockMode::Hidden;
  all.push_back(hidden);
  Variant flags{"github, every flag", {}, true};
  flags.options.flags.underline = true;
  flags.options.flags.superscript = true;
  flags.options.flags.subscript = true;
  flags.options.flags.strikethrough = true;
  flags.options.flags.highlight = true;
  flags.options.flags.hardSoftBreaks = true;
  flags.options.flags.preserveBlankLines = true;
  all.push_back(flags);
  Variant plain{"commonmark, no math or admonitions", {}, false};
  plain.options.flags.latexMath = false;
  plain.options.flags.admonitions = false;
  plain.options.flags.permissiveAutolinks = false;
  plain.options.flags.preserveBlankLines = true;
  all.push_back(plain);
  return all;
}

size_t reused = 0;
size_t extended = 0;

// Streams `document` in chunks of up to `maxStep` bytes; 0 steps a byte at a time.
void checkStream(const std::string &name, const std::string &document, const Variant &variant, size_t maxStep,
                 std::mt19937 &random) {
  auto &store = DocumentStore::shared();
  store.clear();
  std::shared_ptr<const ParsedDocument> previous;
  StreamingSnapshot previousSnapshot;
  bool previousInParts = false;
  size_t mostFinished = 0; // finishedBytes can go back, as when `$$` opens a block
  size_t reported = 0;
  for (size_t length = 0; length < document.size() && reported < 3;) {
    length += maxStep == 0 ? 1 : 1 + random() % maxStep;
    length = std::min(length, document.size());
    while (length < document.size() && (static_cast<unsigned char>(document[length]) & 0xC0) == 0x80)
      length++;
    StreamingSnapshot snapshot = store.snapshot(document.substr(0, length), variant.options);
    size_t inPartsBefore = store.extendedParseCount();
    auto parsed = store.parse(snapshot.markdown, variant.options.flags, variant.isGFM);
    // Parsed now, not found: a found document keeps the finished blocks it was parsed with.
    bool inParts = store.extendedParseCount() > inPartsBefore;
    std::string expected = describe(parseWhole(snapshot.markdown, variant.options.flags, variant.isGFM));
    std::string actual = describe(*parsed);
    if (actual != expected) {
      std::cerr << "FAIL: " << name << " (" << variant.name << ") after " << length
                << " bytes parses differently in parts:\n--- whole\n"
                << expected << "\n--- in parts\n"
                << actual << "\n--- text\n"
                << snapshot.markdown << "\n";
      failures++;
      reported++;
    }
    // Two states parsed in parts share the nodes of the earlier one's finished blocks, unless an
    // older state finished more.
    const size_t known = previousSnapshot.finishedBytes;
    if (previousInParts && inParts && known > 0 && known == mostFinished && snapshot.finishedBytes >= known &&
        snapshot.markdown.compare(0, known, previousSnapshot.markdown, 0, known) == 0) {
      std::shared_ptr<MarkdownASTNode> finished =
          MD4CParser().parse(snapshot.markdown.substr(0, known), variant.options.flags, variant.isGFM);
      size_t blocks = finished ? finished->children.size() : 0;
      size_t shared = sharedLeadingBlocks(*parsed, *previous);
      if (shared < blocks) {
        std::cerr << "FAIL: " << name << " (" << variant.name << ") after " << length << " bytes shares " << shared
                  << " of the previous state's " << blocks << " finished blocks\n";
        failures++;
        reported++;
      }
      reused += shared;
    }
    previous = parsed;
    previousSnapshot = snapshot;
    previousInParts = inParts;
    mostFinished = std::max(mostFinished, snapshot.finishedBytes);
  }
  extended += store.extendedParseCount();
}

// Several texts take turns in one store, as two streaming messages do, or one message whose view
// shows less than was collected (smooth pacing): each state still parses as its whole text.
void checkInterleaved(const std::vector<std::string> &texts, const Variant &variant, size_t lag, std::mt19937 &random) {
  auto &store = DocumentStore::shared();
  store.clear();
  std::vector<size_t> lengths(texts.size(), 0);
  for (bool growing = true; growing;) {
    growing = false;
    for (size_t i = 0; i < texts.size(); i++) {
      const std::string &document = texts[i];
      if (lengths[i] >= document.size())
        continue;
      growing = true;
      size_t length = std::min(lengths[i] + 1 + random() % 40, document.size());
      while (length < document.size() && (static_cast<unsigned char>(document[length]) & 0xC0) == 0x80)
        length++;
      lengths[i] = length;
      size_t shown = length > lag ? length - lag : 0;
      while (shown > 0 && (static_cast<unsigned char>(document[shown]) & 0xC0) == 0x80)
        shown--;
      for (size_t part : {length, shown}) {
        StreamingSnapshot snapshot = store.snapshot(document.substr(0, part), variant.options);
        auto parsed = store.parse(snapshot.markdown, variant.options.flags, variant.isGFM);
        if (describe(*parsed) != describe(parseWhole(snapshot.markdown, variant.options.flags, variant.isGFM))) {
          std::cerr << "FAIL: interleaved text " << i << " (" << variant.name << ") after " << part
                    << " bytes parses differently in parts\n";
          failures++;
          return;
        }
        if (lag == 0)
          break;
      }
    }
  }
  extended += store.extendedParseCount();
}

// Blocks whose syntax reaches past a blank line, pairs with others or is easy to get wrong.
const char *const kBlocks[] = {
    "A paragraph with **bold**, `code` and a [link](https://e.com/x).",
    "Another one, with a [reference][ref] and a [shortcut].",
    "# A heading",
    "Setext heading\n===",
    "- one\n- two\n\n  continued\n- three",
    "1. first\n2. second\n\n   ```js\n   const a = 1;\n\n   const b = 2;\n   ```\n3. third",
    "- [ ] todo\n- [x] done",
    "> quoted\n> text\n\n> another quote",
    "> ```\n> quoted code\n>\n> more\n> ```",
    "> [!NOTE]\n> An admonition\n>\n> with two paragraphs.",
    "```ts\ntype Map = {\n  [key: string]: number;\n};\n\nconst m: Map = {};\n```",
    "~~~\ntilde fence\n\n```\nnot a closer\n~~~",
    "```\nan open fence",
    "    indented code\n\n    after a blank line",
    "| a | b |\n|---|---|\n| 1 | 2 |",
    "$$\nx^2 +\n\ny^2\n$$",
    "Inline $a+b$ and display $$c$$ math.",
    "![image](https://e.com/a.png)",
    "![image](https://e.com/a.png)",
    "[Only a link](https://e.com/file.pdf)",
    "<video src=\"https://e.com/v.mp4\"></video>",
    "<div>\n```\n</div>",
    "<!-- a comment\n\nwith a blank line -->",
    "<pre>\npreformatted\n\ntext\n</pre>",
    "<SCRIPT>\nlet a;\n\nlet b;\n</SCRIPT>",
    "<details>\n<summary>More</summary>\n\nHidden **text**.\n\n</details>",
    "[ref]: https://e.com/ref \"Title\"",
    "[shortcut]:\n  https://e.com/shortcut",
    "> [quoted]: https://e.com/quoted",
    "Text with a ||spoiler|| and ~~struck~~ words\nover two lines.",
    "***",
    "Line one\\\nline two  \nline three",
    "https://e.com/bare and <https://e.com/auto>",
    "* * *\n\n+ plus list\n\n+ loose item",
    "Trailing spaces   \n\n\n\nafter three blank lines",
    "A [link that\nwraps](https://e.com/wrap) and `code that\nwraps`.",
    "日本語のテキストと **太字**。",
};

std::string generate(std::mt19937 &random) {
  std::string document;
  size_t count = 3 + random() % 10;
  for (size_t i = 0; i < count; i++) {
    document += kBlocks[random() % (sizeof(kBlocks) / sizeof(kBlocks[0]))];
    switch (random() % 6) {
      case 0:
        document += "\n";
        break;
      case 1:
        document += "\n\n\n";
        break;
      case 2:
        document += "\n  \n";
        break;
      default:
        document += "\n\n";
    }
  }
  return document;
}

} // namespace

int main(int argc, char **argv) {
  std::mt19937 random(20261111);
  std::vector<std::pair<std::string, std::string>> documents;
  for (int i = 1; i < argc; i++)
    documents.emplace_back(argv[i], readFile(argv[i]));
  for (int i = 0; i < 400; i++)
    documents.emplace_back("generated " + std::to_string(i), generate(random));

  for (const Variant &variant : variants()) {
    for (const auto &[name, document] : documents) {
      for (size_t maxStep : {size_t(0), size_t(7), size_t(60), size_t(400)})
        checkStream(name, document, variant, maxStep, random);
      if (failures >= 12)
        return 1;
    }
  }

  for (const Variant &variant : variants()) {
    for (size_t i = 0; i + 2 < documents.size(); i += 3) {
      checkInterleaved({documents[i].second, documents[i + 1].second, documents[i + 2].second}, variant, 0, random);
      checkInterleaved({documents[i].second}, variant, 1 + random() % 90, random);
      // The same text twice shares one stream.
      checkInterleaved({documents[i].second, documents[i].second}, variant, 0, random);
    }
  }

  // Finished paragraphs of a long answer are parsed once, not on every update.
  auto &store = DocumentStore::shared();
  store.clear();
  std::string answer;
  std::shared_ptr<const ParsedDocument> last;
  for (int i = 0; i < 200; i++) {
    answer += "Paragraph " + std::to_string(i) + " with **bold** text.\n\n";
    StreamingSnapshot snapshot = store.snapshot(answer + "Still arriv", {});
    last = store.parse(snapshot.markdown, {}, true);
  }
  if (store.extendedParseCount() < 198 || !last->ast || last->ast->children.size() != 201) {
    std::cerr << "FAIL: a growing answer is parsed in parts (" << store.extendedParseCount() << " of 200 updates)\n";
    failures++;
  }

  // Another text with the same finished start, where the line after it continues the list above:
  // parsed whole, not after the start's nodes.
  store.clear();
  for (const char *text : {"- a\n\nNext", "- a\n\n- b\n\nAfter"}) {
    StreamingSnapshot snapshot = store.snapshot(text, {});
    auto parsed = store.parse(snapshot.markdown, {}, true);
    if (describe(*parsed) != describe(parseWhole(snapshot.markdown, {}, true))) {
      std::cerr << "FAIL: a text sharing another's finished start parses differently:\n" << text << "\n";
      failures++;
    }
  }
  if (sharedLeadingBlocks(ParsedDocument{}, *last) != 0) {
    std::cerr << "FAIL: an empty document shares blocks\n";
    failures++;
  }

  if (extended == 0 || reused == 0) {
    std::cerr << "FAIL: no stream was parsed in parts\n";
    failures++;
  }
  if (failures != 0)
    return 1;
  std::cout << "    every streamed state parses as its whole text (" << extended << " parses in parts, " << reused
            << " blocks reused)\n";
  return 0;
}
