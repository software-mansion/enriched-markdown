#include "InputInternal.hpp"
#include "MD4CParser.hpp"
#include "Utf16.hpp"
#include <algorithm>
#include <bitset>
#include <charconv>
#include <memory>
#include <optional>
#include <string>

// Markdown to plain text and ranges by walking md4c's AST, building the UTF-16
// text directly.
namespace Markdown::Input {

namespace {

using Markdown::MarkdownASTNode;
using Markdown::NodeType;

// Past this depth the walk gives up rather than overflow the stack.
constexpr int kMaxWalkDepth = 512;

// The BMP private-use area, where the whitespace stand-ins come from.
constexpr char16_t kPrivateUseFirst = 0xE000;
constexpr char16_t kPrivateUseLast = 0xF8FF;

bool isPrivateUse(uint32_t c) {
  return c >= kPrivateUseFirst && c <= kPrivateUseLast;
}

std::optional<StyleType> styleTypeOf(NodeType type) {
  switch (type) {
    case NodeType::Strong:
      return StyleType::Strong;
    case NodeType::Emphasis:
      return StyleType::Em;
    case NodeType::Underline:
      return StyleType::Underline;
    case NodeType::Strikethrough:
      return StyleType::Strikethrough;
    case NodeType::Link:
      return StyleType::Link;
    case NodeType::Spoiler:
      return StyleType::Spoiler;
    default:
      return std::nullopt;
  }
}

// Blocks that start a new line after a sibling.
bool isBlockNodeType(NodeType type) {
  switch (type) {
    case NodeType::Paragraph:
    case NodeType::Heading:
    case NodeType::Blockquote:
    case NodeType::Admonition:
    case NodeType::UnorderedList:
    case NodeType::OrderedList:
    case NodeType::ListItem:
    case NodeType::CodeBlock:
    case NodeType::ThematicBreak:
    case NodeType::Table:
    case NodeType::LatexMathDisplay:
      return true;
    default:
      return false;
  }
}

bool isListNode(const MarkdownASTNode &node) {
  return node.type == NodeType::UnorderedList || node.type == NodeType::OrderedList;
}

const std::string *attributeOf(const MarkdownASTNode &node, const char *name) {
  const auto it = node.attributes.find(name);
  return it == node.attributes.end() ? nullptr : &it->second;
}

std::optional<int> intAttribute(const MarkdownASTNode &node, const char *name) {
  const std::string *value = attributeOf(node, name);
  int parsed = 0;
  if (value == nullptr || std::from_chars(value->data(), value->data() + value->size(), parsed).ec != std::errc()) {
    return std::nullopt;
  }
  return parsed;
}

// Where a list item's first line ends, set when the walk appends that newline.
struct ItemLine {
  int64_t lineEnd = -1;
};

struct ActiveStyle {
  StyleType type;
  size_t startPosition;
  std::u16string url;
};

struct WalkState {
  std::u16string text;
  std::vector<FormattingRange> formattingRanges;
  std::vector<BlockRange> blockRanges;
  std::vector<ActiveStyle> activeStyles;
  // Blank source lines since the last block, written when the next block
  // starts, so trailing ones are dropped.
  size_t pendingBlankLines = 0;
  // Open list items whose first line has not ended yet.
  std::vector<ItemLine *> pendingItemLines;
  bool tooDeep = false;
};

void append(WalkState &state, std::u16string_view chunk) {
  // Scan the incoming chunk, not the accumulated text.
  const size_t newline = chunk.find(u'\n');
  if (newline != std::u16string_view::npos && !state.pendingItemLines.empty()) {
    const int64_t lineEnd = static_cast<int64_t>(state.text.size() + newline);
    for (ItemLine *item : state.pendingItemLines) {
      item->lineEnd = lineEnd;
    }
    state.pendingItemLines.clear();
  }
  state.text.append(chunk);
}

size_t blankLineCount(const MarkdownASTNode &node) {
  const std::optional<int> count = intAttribute(node, "count");
  return count.has_value() ? static_cast<size_t>(std::max(0, *count)) : 1;
}

void walkNode(const MarkdownASTNode &node, WalkState &state, int listDepth, bool orderedContainer, int depth) {
  if (depth > kMaxWalkDepth) {
    state.tooDeep = true;
  }
  if (state.tooDeep) {
    return;
  }
  const std::optional<StyleType> styleType = styleTypeOf(node.type);

  if (styleType.has_value()) {
    ActiveStyle style{*styleType, state.text.size(), {}};
    if (*styleType == StyleType::Link) {
      if (const std::string *url = attributeOf(node, "url")) {
        style.url = Markdown::toUtf16(*url);
      }
    }
    state.activeStyles.push_back(std::move(style));
  }

  // Depth comes from AST nesting, never from counting leading spaces.
  const bool isListContainer = isListNode(node);
  const int childListDepth = isListContainer ? listDepth + 1 : listDepth;
  const bool childOrdered = isListContainer ? node.type == NodeType::OrderedList : orderedContainer;

  const bool isItem = node.type == NodeType::ListItem;
  const size_t itemStart = state.text.size();
  ItemLine itemLine;
  if (isItem) {
    state.pendingItemLines.push_back(&itemLine);
  }

  const int blockLevel = intAttribute(node, "level").value_or(0);
  // An out-of-range heading level falls back to a paragraph.
  const bool isHeadingBlock = node.type == NodeType::Heading && blockLevel >= 1 && blockLevel <= 6;
  const size_t blockStartPosition = state.text.size();

  if (node.type == NodeType::Text) {
    append(state, Markdown::toUtf16(node.content));
  } else if (node.type == NodeType::LineBreak || node.type == NodeType::SoftBreak) {
    append(state, u"\n");
  }

  // A code block's text ends in a newline; the walk writes block boundaries
  // itself, so drop it.
  const auto &children = node.children;
  const bool dropClosingNewline = node.type == NodeType::CodeBlock && !children.empty() &&
                                  children.back()->type == NodeType::Text && !children.back()->content.empty() &&
                                  children.back()->content.back() == '\n';
  for (size_t index = 0; index < children.size(); index++) {
    const MarkdownASTNode &child = *children[index];
    if (child.type == NodeType::BlankLine) {
      // An empty item reports its own line as its first blank line.
      const size_t ownLine = isItem && index == 0 ? 1 : 0;
      const size_t count = blankLineCount(child);
      state.pendingBlankLines += count > ownLine ? count - ownLine : 0;
      continue;
    }
    // md4c emits no separators: a block after a sibling starts a new line,
    // after one empty line per blank source line. An empty item's sublist also
    // starts below the item's line.
    const bool startsLine = index > 0 || (isItem && isListNode(child));
    if (startsLine && isBlockNodeType(child.type)) {
      // An empty line above a nested item would de-nest it, so drop it.
      const bool startsNestedItem =
          (child.type == NodeType::ListItem && childListDepth > 1) || (isItem && isListNode(child));
      if (startsNestedItem) {
        state.pendingBlankLines = 0;
      }
      if (childListDepth > 0 || !state.text.empty()) {
        append(state, std::u16string(1 + state.pendingBlankLines, u'\n'));
      }
      state.pendingBlankLines = 0;
    }
    if (dropClosingNewline && index + 1 == children.size()) {
      MarkdownASTNode trimmed(NodeType::Text);
      trimmed.content.assign(child.content, 0, child.content.size() - 1);
      walkNode(trimmed, state, childListDepth, childOrdered, depth + 1);
    } else {
      walkNode(child, state, childListDepth, childOrdered, depth + 1);
    }
    if (state.tooDeep) {
      return;
    }
  }

  // An item's range is its first line; sublists are on later lines. An empty
  // item keeps a zero-length range.
  if (isItem) {
    int64_t lineEnd = itemLine.lineEnd;
    if (lineEnd < 0) {
      // No newline yet, so this item is the last pending one.
      state.pendingItemLines.pop_back();
      lineEnd = static_cast<int64_t>(state.text.size());
    }
    // The enclosing list has already incremented listDepth.
    const int itemDepth = std::clamp(listDepth - 1, 0, static_cast<int>(kMaxListDepth));
    BlockRange item;
    item.type = orderedContainer ? BlockType::OrderedListItem : BlockType::UnorderedListItem;
    item.start = static_cast<uint32_t>(itemStart);
    item.end = static_cast<uint32_t>(lineEnd);
    item.level = static_cast<uint8_t>(itemDepth);
    state.blockRanges.push_back(item);
  }

  if (styleType.has_value()) {
    ActiveStyle style = std::move(state.activeStyles.back());
    state.activeStyles.pop_back();
    const size_t end = state.text.size();
    if (end > style.startPosition) {
      FormattingRange range;
      range.type = style.type;
      range.start = static_cast<uint32_t>(style.startPosition);
      range.end = static_cast<uint32_t>(end);
      range.url = std::move(style.url);
      state.formattingRanges.push_back(std::move(range));
    }
  }

  // Paragraph is the implicit default; list items were emitted above.
  if (isHeadingBlock) {
    const size_t end = state.text.size();
    if (end > blockStartPosition) {
      BlockRange heading;
      heading.type = static_cast<BlockType>(static_cast<int>(BlockType::H1) + blockLevel - 1);
      heading.start = static_cast<uint32_t>(blockStartPosition);
      heading.end = static_cast<uint32_t>(end);
      heading.level = static_cast<uint8_t>(blockLevel);
      state.blockRanges.push_back(heading);
    }
  }
}

bool isBlank(char16_t c) {
  return c == u' ' || c == u'\t';
}

bool isDigit(char16_t c) {
  return c >= u'0' && c <= u'9';
}

void swapForStandIns(std::u16string &text, size_t from, size_t to, WhitespaceStandIns standIns) {
  for (size_t i = from; i < to; i++) {
    text[i] = text[i] == u'\t' ? standIns.tab : standIns.space;
  }
}

bool isHexDigit(char16_t c) {
  return isDigit(c) || (c >= u'a' && c <= u'f') || (c >= u'A' && c <= u'F');
}

// The code point of a numeric reference ("&#57344;", "&#xE000;") at `at`.
std::optional<uint32_t> numericReferenceAt(std::u16string_view text, size_t at) {
  size_t i = at + 1;
  if (i >= text.size() || text[i] != u'#') {
    return std::nullopt;
  }
  i++;
  const bool hex = i < text.size() && (text[i] == u'x' || text[i] == u'X');
  if (hex) {
    i++;
  }
  const size_t digitsStart = i;
  const size_t maxDigits = hex ? 6 : 7;
  uint32_t value = 0;
  while (i < text.size() && i - digitsStart < maxDigits && (hex ? isHexDigit(text[i]) : isDigit(text[i]))) {
    const char16_t c = text[i];
    const uint32_t digit = isDigit(c) ? c - u'0' : (c | 0x20) - u'a' + 10;
    value = value * (hex ? 16 : 10) + digit;
    i++;
  }
  if (i == digitsStart || i >= text.size() || text[i] != u';') {
    return std::nullopt;
  }
  return value;
}

// The end of a list or heading marker at `at`, with the one blank after it,
// or npos.
size_t markerEnd(const std::u16string &text, size_t at, size_t lineEnd) {
  size_t end = at;
  const char16_t c = text[at];
  if (c == u'-' || c == u'+' || c == u'*') {
    end = at + 1;
  } else if (isDigit(c)) {
    while (end < lineEnd && end - at < 9 && isDigit(text[end])) {
      end++;
    }
    if (end >= lineEnd || (text[end] != u'.' && text[end] != u')')) {
      return std::u16string::npos;
    }
    end++;
  } else if (c == u'#') {
    while (end < lineEnd && end - at < 6 && text[end] == u'#') {
      end++;
    }
  } else {
    return std::u16string::npos;
  }
  if (end == lineEnd) {
    return end;
  }
  return isBlank(text[end]) ? end + 1 : std::u16string::npos;
}

} // namespace

bool parseResultFromAst(const MarkdownASTNode &ast, ParseResult &result) {
  WalkState state;
  walkNode(ast, state, 0, false, 0);
  if (state.tooDeep) {
    return false;
  }
  result.plainText = std::move(state.text);
  result.formattingRanges = normalizeFormattingRanges(std::move(state.formattingRanges));
  result.blockRanges = normalizeBlockRanges(result.plainText, state.blockRanges);
  return true;
}

// Swaps the whitespace that is text for stand-ins: all leading whitespace on a
// line without a marker, or what follows a marker's one separator. Quote lines
// and whitespace-only lines are left alone.
std::u16string protectLeadingWhitespace(std::u16string_view markdown, WhitespaceStandIns standIns) {
  std::u16string text(markdown);
  for (size_t lineStart = 0; lineStart <= text.size();) {
    size_t lineEnd = text.find(u'\n', lineStart);
    if (lineEnd == std::u16string::npos) {
      lineEnd = text.size();
    }
    const size_t next = lineEnd + 1;
    // Lines holding "\r", U+2028 or U+2029 are left as they are.
    bool matchable = true;
    for (size_t i = lineStart; i < lineEnd && matchable; i++) {
      matchable = text[i] != u'\r' && text[i] != u'\u2028' && text[i] != u'\u2029';
    }
    if (matchable) {
      size_t i = lineStart;
      while (i < lineEnd && isBlank(text[i])) {
        i++;
      }
      const size_t indentEnd = i;
      size_t contentStart = indentEnd;
      bool structural = false;
      if (i < lineEnd) {
        const size_t end = markerEnd(text, i, lineEnd);
        if (end != std::u16string::npos) {
          contentStart = end;
        } else if (text[i] == u'>') {
          // A quote keeps its line as it is.
          structural = true;
        }
      }
      if (!structural) {
        size_t textStart = contentStart;
        while (textStart < lineEnd && isBlank(text[textStart])) {
          textStart++;
        }
        // Nothing but whitespace after the structure: a blank line stays blank.
        if (textStart < lineEnd) {
          if (contentStart == indentEnd) {
            // No marker: the indent is text too.
            swapForStandIns(text, lineStart, textStart, standIns);
          } else {
            swapForStandIns(text, contentStart, textStart, standIns);
          }
        }
      }
    }
    lineStart = next;
  }
  return text;
}

void restoreLeadingWhitespace(std::u16string &text, WhitespaceStandIns standIns) {
  for (char16_t &c : text) {
    if (c == standIns.tab) {
      c = u'\t';
    } else if (c == standIns.space) {
      c = u' ';
    }
  }
}

std::optional<WhitespaceStandIns> chooseWhitespaceStandIns(std::u16string_view markdown) {
  std::bitset<kPrivateUseLast - kPrivateUseFirst + 1> taken;
  for (size_t i = 0; i < markdown.size(); i++) {
    uint32_t c = markdown[i];
    if (c == u'&') {
      c = numericReferenceAt(markdown, i).value_or(c);
    }
    if (isPrivateUse(c)) {
      taken.set(c - kPrivateUseFirst);
    }
  }
  WhitespaceStandIns standIns;
  size_t found = 0;
  for (size_t i = 0; i < taken.size() && found < 2; i++) {
    if (!taken.test(i)) {
      (found++ == 0 ? standIns.tab : standIns.space) = static_cast<char16_t>(kPrivateUseFirst + i);
    }
  }
  if (found < 2) {
    return std::nullopt;
  }
  return standIns;
}

ParseResult parse(std::u16string_view markdown) {
  ParseResult result;
  if (markdown.empty()) {
    return result;
  }
  try {
    // Bare URLs stay plain text (hosts autolink them); blank lines come back as
    // BlankLine nodes.
    Markdown::Md4cFlags flags;
    flags.underline = true;
    flags.latexMath = false;
    flags.superscript = false;
    flags.subscript = false;
    flags.highlight = false;
    flags.hardSoftBreaks = false;
    flags.preserveBlankLines = true;
    flags.admonitions = true;
    flags.permissiveAutolinks = false;

    // With no stand-ins free, leading whitespace goes the way md4c takes it.
    const std::optional<WhitespaceStandIns> standIns = chooseWhitespaceStandIns(markdown);
    Markdown::MD4CParser parser;
    const std::shared_ptr<MarkdownASTNode> ast = parser.parse(
        Markdown::toUtf8(standIns ? protectLeadingWhitespace(markdown, *standIns) : std::u16string(markdown)), flags);
    if (ast && parseResultFromAst(*ast, result)) {
      if (standIns) {
        restoreLeadingWhitespace(result.plainText, *standIns);
        // A link destination can sit on an indented line.
        for (FormattingRange &range : result.formattingRanges) {
          range.url.erase(std::remove_if(range.url.begin(), range.url.end(),
                                         [&](char16_t c) { return c == standIns->tab || c == standIns->space; }),
                          range.url.end());
        }
      }
      normalizeListMetadata(result.blockRanges);
      return result;
    }
  } catch (...) {}
  ParseResult fallback;
  fallback.plainText = std::u16string(markdown);
  return fallback;
}

} // namespace Markdown::Input
