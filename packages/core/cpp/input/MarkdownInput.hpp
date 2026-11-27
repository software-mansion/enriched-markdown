#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

// Markdown import and export for the editable input, shared by iOS, Android
// and web. Offsets are in UTF-16 code units. Nothing here throws.
namespace Markdown::Input {

// Values are stable: hosts pass the type as an integer.
enum class StyleType : uint8_t { Strong = 0, Em = 1, Underline = 2, Strikethrough = 3, Link = 4, Spoiler = 5 };
inline constexpr size_t kStyleTypeCount = 6;

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

// `level`: a heading's level (1-6) or a list item's depth (0-based).
// `ordinal`: 1-based position among adjacent same-depth ordered items.
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

// Markdown to plain text and ranges. Unclosed delimiters stay literal; syntax
// the input can't model (quotes, code, tables, rules) keeps only its content.
// On failure, returns the markdown as plain text.
ParseResult parse(std::u16string_view markdown);

// Plain text and ranges to markdown. Blocks are one per line, sorted by start.
// Text that would read as markup is escaped. On failure, returns the plain text.
std::u16string serialize(std::u16string_view plainText, const std::vector<FormattingRange> &formattingRanges,
                         const std::vector<BlockRange> &blockRanges);

// Nests each list item at most one level below the item above it and numbers
// ordered items from 1 within each run. `parse` already applies it.
void normalizeListMetadata(std::vector<BlockRange> &blockRanges);

} // namespace Markdown::Input
