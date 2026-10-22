#include "MD4CParser.hpp"
#include <cstdlib>
#include <iostream>

using namespace Markdown;

static int count(const std::shared_ptr<MarkdownASTNode> &node, NodeType type) {
  int total = node->type == type;
  for (const auto &child : node->children) {
    total += count(child, type);
  }
  return total;
}

static void check(bool condition, const char *message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << "\n";
    std::exit(1);
  }
}

int main() {
  MD4CParser parser;
  const std::string fixture =
      "    **spaces**\n\nSeparator.\n\n\t*tab*\n\n```js\nconst fenced = true;\n```\n\n~~~\ntilde\n~~~";
  check(count(parser.parse(fixture), NodeType::CodeBlock) == 4, "omitted flag preserves indented code");
  for (bool isGFM : {false, true}) {
    Md4cFlags flags;
    for (bool enabled : {false, true, false}) {
      flags.noIndentedCodeBlocks = enabled;
      auto ast = parser.parse(fixture, flags, isGFM);
      check(count(ast, NodeType::CodeBlock) == (enabled ? 2 : 4), "spaces, tabs and both fences");
      check(count(ast, NodeType::Strong) == (enabled ? 1 : 0), "indented strong text");
      check(count(ast, NodeType::Emphasis) == (enabled ? 1 : 0), "tab-indented emphasis");
      const auto nested = parser.parse("- item\n\n      **nested**\n\n>     *quoted*", flags, isGFM);
      check(count(nested, NodeType::UnorderedList) == 1, "list container retained");
      check(count(nested, NodeType::Blockquote) == 1, "blockquote container retained");
      check(count(nested, NodeType::CodeBlock) == (enabled ? 0 : 2), "nested indented code opt-in");
      check(count(nested, NodeType::Strong) == (enabled ? 1 : 0), "list content parsed as markdown");
      check(count(nested, NodeType::Emphasis) == (enabled ? 1 : 0), "blockquote content parsed as markdown");
    }
  }
  std::cout << "PASS: optional indented code blocks\n";
}
