#include "InputInternal.hpp"
#include "MD4CParser.hpp"
#include "Utf16.hpp"
#include <algorithm>
#include <cstdlib>
#include <memory>
#include <optional>
#include <string>

// InputParser.ts: markdown to plain text, formatting ranges and block ranges,
// by walking md4c's AST. The walk builds the UTF-16 text directly, so every
// offset is already in the unit the hosts index in.
namespace Markdown::Input {

namespace {

using Markdown::MarkdownASTNode;
using Markdown::NodeType;

// Documents nest this deep only on purpose; past it the walk gives up rather
// than overflow the stack, and `parse` hands the markdown back as plain text.
constexpr int kMaxWalkDepth = 512;

constexpr char16_t kTabStandIn = u'';
constexpr char16_t kSpaceStandIn = u'';

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

// Blocks that start a new line after a sibling. Not Admonition, Video or the
// table parts, as in the TypeScript.
bool isBlockNodeType(NodeType type) {
  switch (type) {
    case NodeType::Paragraph:
    case NodeType::Heading:
    case NodeType::Blockquote:
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

// parseInt(value, 10): an optional sign and the digits that follow, whatever
// comes after them.
std::optional<long> jsParseInt(const std::string *value) {
  if (value == nullptr) {
    return std::nullopt;
  }
  size_t i = 0;
  while (i < value->size() && (*value)[i] == ' ') {
    i++;
  }
  bool negative = false;
  if (i < value->size() && ((*value)[i] == '-' || (*value)[i] == '+')) {
    negative = (*value)[i] == '-';
    i++;
  }
  const size_t digitsStart = i;
  long parsed = 0;
  while (i < value->size() && (*value)[i] >= '0' && (*value)[i] <= '9' && parsed < 100000000) {
    parsed = parsed * 10 + ((*value)[i] - '0');
    i++;
  }
  if (i == digitsStart) {
    return std::nullopt;
  }
  return negative ? -parsed : parsed;
}

const std::string *attributeOf(const MarkdownASTNode &node, const char *name) {
  const auto it = node.attributes.find(name);
  return it == node.attributes.end() ? nullptr : &it->second;
}

// A list item's range covers its first line; the end is set when the walk
// appends the first newline after the item starts.
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
  // Blank source lines seen since the last block, written out as empty lines
  // when the next block starts. Deferred so trailing ones are dropped, as
  // leading ones are, rather than leaving empty lines at the end.
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
  const std::optional<long> count = jsParseInt(attributeOf(node, "count"));
  return count.has_value() ? static_cast<size_t>(std::max(0L, *count)) : 1;
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

  const long blockLevel = jsParseInt(attributeOf(node, "level")).value_or(0);
  // An out-of-range heading level falls back to paragraph rather than dropping
  // the line. List items are emitted by the walk with their own per-line bounds
  // and AST-derived depth.
  const bool isHeadingBlock = node.type == NodeType::Heading && blockLevel >= 1 && blockLevel <= 6;
  const size_t blockStartPosition = state.text.size();

  if (node.type == NodeType::Text) {
    append(state, Markdown::toUtf16(node.content));
  } else if (node.type == NodeType::LineBreak || node.type == NodeType::SoftBreak) {
    append(state, u"\n");
  }

  // A code block's text ends with the newline that closes its last line. The
  // input has no code block, so its lines are kept as plain lines, and that
  // newline would add one more. Block boundaries are written by the walk.
  const auto &children = node.children;
  const bool dropClosingNewline = node.type == NodeType::CodeBlock && !children.empty() &&
                                  children.back()->type == NodeType::Text && !children.back()->content.empty() &&
                                  children.back()->content.back() == '\n';
  for (size_t index = 0; index < children.size(); index++) {
    const MarkdownASTNode &child = *children[index];
    if (child.type == NodeType::BlankLine) {
      // An empty item reports its own line as a blank one, first in the item;
      // only the lines past it are blank lines between blocks.
      const size_t ownLine = isItem && index == 0 ? 1 : 0;
      const size_t count = blankLineCount(child);
      state.pendingBlankLines += count > ownLine ? count - ownLine : 0;
      continue;
    }
    // md4c emits no separators, so a block that follows a sibling starts a new
    // line here, after an empty line for each blank source line between them -
    // top-level or inside a list alike. An empty item's sublist is its first
    // child but still starts below the item's own (empty) line. Blank lines
    // before the first block are dropped.
    const bool startsLine = index > 0 || (isItem && isListNode(child));
    if (startsLine && isBlockNodeType(child.type)) {
      // The block store clamps an item to one level below the item right above
      // it, so an empty line above a nested item would de-nest it: the blank
      // line is the smaller loss.
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

  // A list item owns its own first line; a nested sublist lives on later
  // lines, so the item's range ends at the first newline after its start. An
  // empty item keeps a zero-length range, the store's empty-line anchor.
  if (isItem) {
    int64_t lineEnd = itemLine.lineEnd;
    if (lineEnd < 0) {
      // No newline since the item started: its nested items have already
      // exited, so it is the last pending entry.
      state.pendingItemLines.pop_back();
      lineEnd = static_cast<int64_t>(state.text.size());
    }
    // The item sees listDepth already incremented by its enclosing list node,
    // so its 0-based depth is listDepth - 1.
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
      heading.type = static_cast<BlockType>(static_cast<int>(BlockType::H1) + static_cast<int>(blockLevel) - 1);
      heading.start = static_cast<uint32_t>(blockStartPosition);
      heading.end = static_cast<uint32_t>(end);
      heading.level = static_cast<uint8_t>(blockLevel);
      state.blockRanges.push_back(heading);
    }
  }
}

bool isLineTerminator(char16_t c) {
  return c == u'\n' || c == u'\r' || c == u' ' || c == u' ';
}

bool isBlank(char16_t c) {
  return c == u' ' || c == u'\t';
}

bool isDigit(char16_t c) {
  return c >= u'0' && c <= u'9';
}

void swapForStandIns(std::u16string &text, size_t from, size_t to) {
  for (size_t i = from; i < to; i++) {
    text[i] = text[i] == u'\t' ? kTabStandIn : kSpaceStandIn;
  }
}

// The end of a list or heading marker at `at` (`[-+*]`, `\d{1,9}[.)]` or
// `#{1,6}`) together with the one separator after it, which is a blank or the
// line end. npos when the line has no marker there.
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

// `[indent][marker][separator][text]`: a bullet, an ordered "1." / "1)" or an
// ATX "#", each needing a separator or the line end, or a quote's ">".
// Whitespace that is structure stays as it is - the indent in front of a list,
// heading or quote marker - and so does the one separator after a list or
// heading marker; whitespace past that is the line's text. A line of only
// whitespace stays blank.
std::u16string protectLeadingWhitespace(std::u16string_view markdown) {
  std::u16string text(markdown);
  for (size_t lineStart = 0; lineStart <= text.size();) {
    size_t lineEnd = text.find(u'\n', lineStart);
    if (lineEnd == std::u16string::npos) {
      lineEnd = text.size();
    }
    const size_t next = lineEnd + 1;
    // The reference matches a line with a regex whose "." stops at these, so
    // such a line is left as it is.
    bool matchable = true;
    for (size_t i = lineStart; i < lineEnd && matchable; i++) {
      matchable = text[i] != u'\r' && text[i] != u' ' && text[i] != u' ';
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
            swapForStandIns(text, lineStart, textStart);
          } else {
            swapForStandIns(text, contentStart, textStart);
          }
        }
      }
    }
    lineStart = next;
  }
  return text;
}

void restoreLeadingWhitespace(std::u16string &text) {
  for (size_t i = 0; i < text.size(); i++) {
    if (i > 0 && !isLineTerminator(text[i - 1])) {
      continue;
    }
    for (; i < text.size() && (text[i] == kTabStandIn || text[i] == kSpaceStandIn); i++) {
      text[i] = text[i] == kTabStandIn ? u'\t' : u' ';
    }
  }
}

ParseResult parse(std::u16string_view markdown) {
  ParseResult result;
  if (markdown.empty()) {
    return result;
  }
  try {
    // Bare URLs stay plain text until the host's autolink layer claims them.
    // Blank lines come back as BlankLine nodes where they stood, so each one
    // replays as an empty line of its own.
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

    Markdown::MD4CParser parser;
    const std::shared_ptr<MarkdownASTNode> ast =
        parser.parse(Markdown::toUtf8(protectLeadingWhitespace(markdown)), flags);
    if (ast && parseResultFromAst(*ast, result)) {
      restoreLeadingWhitespace(result.plainText);
      normalizeListMetadata(result.blockRanges);
      return result;
    }
  } catch (...) {}
  ParseResult fallback;
  fallback.plainText = std::u16string(markdown);
  return fallback;
}

} // namespace Markdown::Input
