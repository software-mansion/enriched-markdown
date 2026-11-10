#pragma once

#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

// Markdown import and export for the editable input: one implementation for
// iOS, Android and web, so a document saved on one platform loads unchanged on
// another. Both functions work on plain data in UTF-16 offsets (the unit every
// host string indexes in) and never throw.
//
// This is a port of the web input's TypeScript (src/web/input/formatting),
// which is the reference for every behavior here.
namespace Markdown::Input {

// The order is the order of the TypeScript `INPUT_STYLE_TYPES`; hosts that
// pass the type as an integer can rely on these values.
enum class StyleType : uint8_t { Strong = 0, Em = 1, Underline = 2, Strikethrough = 3, Link = 4, Spoiler = 5 };

// Line-scoped block types. Every line is a paragraph until a block claims it.
enum class BlockType : uint8_t {
  Paragraph = 0,
  H1 = 1,
  H2 = 2,
  H3 = 3,
  H4 = 4,
  H5 = 5,
  H6 = 6,
  UnorderedListItem = 7,
  OrderedListItem = 8,
};

// Deepest list nesting a block can carry (0-based).
inline constexpr uint8_t kMaxListDepth = 5;

struct FormattingRange {
  StyleType type = StyleType::Strong;
  uint32_t start = 0; // UTF-16 offsets into the plain text, end exclusive
  uint32_t end = 0;
  std::u16string url; // links only
};

// `level` is a heading's level (1-6) or a list item's depth (0-based).
// `ordinal` is the 1-based position of an ordered item among its adjacent
// siblings at the same depth.
struct BlockRange {
  BlockType type = BlockType::Paragraph;
  uint32_t start = 0;
  uint32_t end = 0;
  uint8_t level = 0;
  uint32_t ordinal = 1;
};

struct ParseResult {
  std::u16string plainText;
  std::vector<FormattingRange> formattingRanges; // sorted by start
  std::vector<BlockRange> blockRanges;           // in line order, one per line, list metadata settled
};

// Markdown to plain text and ranges. Parsed as given: an unclosed delimiter
// stays literal text. Syntax the input has no model for (quotes, code, tables,
// rules) loses its markers and keeps its content. On failure the markdown
// comes back as plain text with no ranges.
ParseResult parse(std::u16string_view markdown);

// The reverse. Blocks must be one per line, sorted by start; a block's marker
// (`- `, `3. `, `## `) is derived from its type, level and ordinal. Plain text
// that would read as markup is escaped. On failure the plain text comes back
// unchanged.
std::u16string serialize(std::u16string_view plainText, const std::vector<FormattingRange> &formattingRanges,
                         const std::vector<BlockRange> &blockRanges);

// What a block store does to a list of blocks sorted by start, and `parse` does
// before returning: an item nests at most one level below the adjacent item
// above it (CommonMark has no orphan nesting), and ordered items are numbered
// from 1 among their adjacent same-depth, same-type run.
void normalizeListMetadata(std::vector<BlockRange> &blockRanges);

} // namespace Markdown::Input
