#include "MD4CParser.hpp"
#include "StreamingSession.hpp"
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

namespace {

using Markdown::MarkdownASTNode;
using Markdown::NodeType;

const char *const kCorpus = R"md(# Setting up the project

Follow these steps:
1. Install the **dependencies** with `yarn`.
2. Create the config file:
   ```json
   { "name": "demo" }
   ```
3. Run the build.
   - It compiles the sources
   - It copies the assets
4. Start the app.

## What to check

- The first point is short.
- The second point wraps onto
  another line and goes on.
- The third has a [link](https://e.com/a) and `code`.

  It also has a second paragraph.
- [ ] An open task
- [x] A finished task
- > A quote in an item
- The last point.

* A list with stars

* that is loose

* and has three items

10. A list that starts at ten
11. and goes on
12. to twelve

+ One
+ Two

- Then another list
- with its own items

Closing words with **bold** text.

| Step | Done |
|---|---|
| Build | yes |

- After a table
- two more items

<div>
- not a list
- inside HTML
</div>

Final paragraph.
)md";

int failures = 0;
size_t splits = 0;

void dump(const MarkdownASTNode &node, std::string &out, int depth) {
  if (node.type == NodeType::Paragraph && node.children.empty())
    return;
  out += std::string(depth, ' ') + std::to_string(static_cast<int>(node.type));
  if (!node.content.empty())
    out += " \"" + node.content + "\"";
  for (const auto &attribute : node.attributes) {
    if (attribute.first != "tight" && attribute.first != "start")
      out += " " + attribute.first + "=" + attribute.second;
  }
  out += "\n";
  for (const auto &child : node.children)
    dump(*child, out, depth + 1);
}

bool isList(const MarkdownASTNode &node) {
  return node.type == NodeType::UnorderedList || node.type == NodeType::OrderedList;
}

bool isProbe(const MarkdownASTNode &item) {
  if (item.children.size() != 1 || item.children[0]->type != NodeType::Paragraph)
    return false;
  const MarkdownASTNode &paragraph = *item.children[0];
  return paragraph.children.size() == 1 && paragraph.children[0]->type == NodeType::Text &&
         paragraph.children[0]->content == "x";
}

void checkSplit(const std::string &name, const std::string &text, size_t end, size_t lastItem,
                const std::string &marker, const Markdown::Md4cFlags &flags) {
  splits++;
  auto whole = Markdown::MD4CParser().parse(text, flags, true);
  auto finished = Markdown::MD4CParser().parse(text.substr(0, end) + marker + " x\n", flags, true);
  auto rest = Markdown::MD4CParser().parse(text.substr(lastItem), flags, true);
  bool lists = whole && finished && rest && !finished->children.empty() && !rest->children.empty() &&
               isList(*finished->children.back()) && finished->children.back()->type == rest->children.front()->type;
  if (lists) {
    auto &finishedItems = finished->children.back()->children;
    auto &restItems = rest->children.front()->children;
    lists = finishedItems.size() >= 2 && isProbe(*finishedItems.back()) && !restItems.empty();
    if (lists) {
      finishedItems.pop_back();
      restItems.erase(restItems.begin());
    }
  }
  std::string expected, got = "0\n";
  if (lists) {
    dump(*whole, expected, 0);
    for (size_t i = 0; i + 1 < finished->children.size(); i++)
      dump(*finished->children[i], got, 1);
    got += " " + std::to_string(static_cast<int>(finished->children.back()->type)) + "\n";
    for (const auto &item : finished->children.back()->children)
      dump(*item, got, 2);
    for (const auto &item : rest->children.front()->children)
      dump(*item, got, 2);
    for (size_t i = 1; i < rest->children.size(); i++)
      dump(*rest->children[i], got, 1);
  }
  if ((!lists || expected != got) && failures++ < 5) {
    std::cerr << "FAIL: " << name << ": the items split at byte " << end << " do not parse as the whole text:\n"
              << text << "\n";
  }
}

void checkPrefixes(const std::string &name, const std::string &document) {
  for (int variant = 0; variant < 2; variant++) {
    Markdown::StreamingOptions options;
    options.flags.latexMath = variant == 0;
    for (size_t length = 1; length <= document.size() && failures < 5; length++) {
      if ((static_cast<unsigned char>(document[length - 1]) & 0xC0) == 0x80)
        continue;
      std::string prefix = document.substr(0, length);
      Markdown::StreamingSnapshot snapshot = Markdown::streamingSnapshot(prefix, options);
      Markdown::FinishedListItems items = Markdown::streamingListItems(prefix, snapshot, options);
      if (items.end == snapshot.finishedBytes || Markdown::mayDefineLinkReference(snapshot.markdown))
        continue;
      size_t markerEnd = prefix.find_first_of(" \t\r\n", items.end);
      std::string marker = prefix.substr(items.end, markerEnd == std::string::npos ? markerEnd : markerEnd - items.end);
      checkSplit(name, snapshot.markdown.substr(snapshot.finishedBytes), items.end - snapshot.finishedBytes,
                 items.lastItem - snapshot.finishedBytes, marker, options.flags);
    }
  }
}

std::string readFile(const std::string &path) {
  std::ifstream file(path);
  std::stringstream buffer;
  buffer << file.rdbuf();
  return buffer.str();
}

} // namespace

int main(int argc, char **argv) {
  checkPrefixes("the list corpus", kCorpus);
  for (int i = 1; i < argc; i++)
    checkPrefixes(argv[i], readFile(argv[i]));
  if (failures != 0)
    return 1;
  if (splits == 0) {
    std::cerr << "FAIL: no list was split\n";
    return 1;
  }
  std::cout << "    " << splits << " splits at finished list items parse as the whole text\n";
  return 0;
}
