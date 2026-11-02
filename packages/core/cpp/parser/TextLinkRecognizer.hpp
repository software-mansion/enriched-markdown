#pragma once

#include "MarkdownASTNode.hpp"
#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace Markdown {

// Offsets are UTF-16 code units, as every host regex engine reports them.
struct TextRange {
  size_t start;
  size_t end;
};

// Host-provided matching, one call per kind per parse. A null function is off.
struct TextLinkMatchers {
  // Non-overlapping matches per run, in order.
  std::function<std::vector<std::vector<TextRange>>(const std::vector<std::string_view> &runs)> text;
  std::function<std::vector<uint8_t>(const std::vector<std::string_view> &spans)> inlineCode;
};

// The children that stand in for a Text or Code node of the parsed tree, keyed by
// that node.
using TextLinkReplacements = std::unordered_map<const MarkdownASTNode *, std::vector<std::shared_ptr<MarkdownASTNode>>>;

// The recognized links as replacements; the tree is left as parsed, so one
// document can be shared and each host applies them while converting it.
// Existing links, code blocks, media and math are not entered.
TextLinkReplacements recognizeTextLinks(const MarkdownASTNode &root, const TextLinkMatchers &matchers);

} // namespace Markdown
