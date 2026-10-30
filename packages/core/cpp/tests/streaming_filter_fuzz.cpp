/*
 * Streams every fixture one byte at a time through the filter and parses each
 * prefix with md4c: image, link and video syntax that the whole document
 * parses as syntax must never reach the screen as literal text while it
 * streams. md4c is the oracle, so the filter cannot drift from the parser.
 * See scripts/test-core-parser.sh.
 */
#include "MD4CParser.hpp"
#include "StreamingFilter.hpp"
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

namespace {

using Markdown::MarkdownASTNode;
using Markdown::NodeType;
using Markdown::StreamingBlockMode;

// What an assistant streams: media blocks, inline links, references, quotes,
// lists and fences that hold syntax-like text.
const char *const kCorpus = R"md(# Day two in Kyoto

We started at **Fushimi Inari** and walked the [torii gates](https://e.com/inari "The gates") before
the crowds, then read about [the shrine][inari] over tea.

![Torii at dawn](https://e.com/img/torii.jpg)

> A quote with a [link](https://e.com/q) and an image:
> ![Bamboo](https://e.com/img/bamboo.jpg)

- Matcha at a [tea house](https://e.com/tea)
- Lunch: `kitsune[0](udon)` and [noodles](<https://e.com/a b>)

<video src="https://e.com/clip.mp4"></video>

<video
  src="https://e.com/wrapped.mp4"
  poster="https://e.com/poster.jpg"></video>

A label that [wraps over
two lines](https://e.com/wrapped) and goes on.

[Itinerary.pdf](https://e.com/files/itinerary.pdf)

https://e.com/maps/kyoto

```md
![not an image](https://e.com/x)
```

> ```js
> const link = "[a](b)";
> ```

Prices were [about 500 yen][prices], see [notes] and [![thumb](https://e.com/t.jpg)](https://e.com/full.jpg).

[inari]: https://e.com/inari
[prices]: https://e.com/prices
[notes]: https://e.com/notes
)md";

std::string readFile(const std::string &path) {
  std::ifstream file(path);
  std::stringstream buffer;
  buffer << file.rdbuf();
  return buffer.str();
}

void collectText(const MarkdownASTNode &node, std::string &out) {
  if (node.type == NodeType::Text)
    out += node.content + "\n";
  for (const auto &child : node.children)
    collectText(*child, out);
}

// Literal text fragments that only syntax produces.
bool leaksSyntax(const std::string &fragment, const std::string &wholeText) {
  for (const char *marker : {"](", "![", "<video"}) {
    size_t at = fragment.find(marker);
    while (at != std::string::npos) {
      // Literal in the finished document too (escaped, or not syntax there).
      size_t from = at >= 8 ? at - 8 : 0;
      if (wholeText.find(fragment.substr(from, at - from + std::strlen(marker))) == std::string::npos)
        return true;
      at = fragment.find(marker, at + 1);
    }
  }
  return false;
}

int checkDocument(const std::string &name, const std::string &document) {
  Markdown::MD4CParser parser;
  std::string wholeText;
  if (auto root = parser.parse(document))
    collectText(*root, wholeText);
  int failures = 0;
  for (StreamingBlockMode mode : {StreamingBlockMode::Progressive, StreamingBlockMode::Hidden}) {
    Markdown::StreamingFilterOptions options;
    options.mediaMode = mode;
    options.tableMode = mode;
    for (size_t length = 1; length <= document.size() && failures < 5; length++) {
      if ((static_cast<unsigned char>(document[length - 1]) & 0xC0) == 0x80)
        continue; // inside a UTF-8 sequence
      std::string prefix = document.substr(0, length);
      std::string filtered = Markdown::renderableMarkdownForStreaming(prefix, options).markdown;
      auto root = parser.parse(filtered);
      if (!root)
        continue;
      std::string text;
      collectText(*root, text);
      std::istringstream fragments(text);
      for (std::string fragment; std::getline(fragments, fragment);) {
        if (leaksSyntax(fragment, wholeText)) {
          std::cerr << "FAIL: " << name << (mode == StreamingBlockMode::Hidden ? " (hidden)" : "")
                    << " shows syntax as text after " << length << " bytes: [" << fragment << "]\n";
          failures++;
          break;
        }
      }
    }
  }
  return failures;
}

} // namespace

int main(int argc, char **argv) {
  int failures = checkDocument("corpus", kCorpus);
  for (int i = 1; i < argc; i++)
    failures += checkDocument(argv[i], readFile(argv[i]));
  if (failures != 0)
    return 1;
  std::cout << "    every streamed prefix parses without leaked syntax\n";
  return 0;
}
