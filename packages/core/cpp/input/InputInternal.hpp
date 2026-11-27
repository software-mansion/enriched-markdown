#pragma once

#include "MarkdownASTNode.hpp"
#include "MarkdownInput.hpp"
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string_view>
#include <vector>

// Pieces of the module the tests reach into. Not part of the host-facing API.
namespace Markdown::Input {

// Indices in `text` that need a backslash, ascending.
std::vector<uint32_t> markdownEscapePositions(std::u16string_view text);
// Whether the "&" at `at` starts "&name;", "&#123;" or "&#x1F;" before `end`.
bool startsEntity(std::u16string_view text, size_t at, size_t end);

// Start offset of each line (at least one), and a line's end offset.
std::vector<size_t> lineStartsOf(std::u16string_view text);
inline size_t lineEndOf(std::u16string_view text, const std::vector<size_t> &lineStarts, size_t line) {
  return line + 1 < lineStarts.size() ? lineStarts[line + 1] - 1 : text.size();
}

// Sorted by start, same-type ranges that touch or overlap merged (links only
// with the same url), empty ranges dropped.
std::vector<FormattingRange> normalizeFormattingRanges(std::vector<FormattingRange> ranges);
// One block per line, sorted. A multi-line block is copied onto each line; on
// a conflict a list item beats a heading, which beats a paragraph.
std::vector<BlockRange> normalizeBlockRanges(std::u16string_view text, const std::vector<BlockRange> &blocks);

// Walks md4c's AST into `result`, leaving list metadata to
// `normalizeListMetadata`. False when the AST nests too deep.
bool parseResultFromAst(const Markdown::MarkdownASTNode &ast, ParseResult &result);

// md4c drops leading whitespace or reads it as an indented code block. To keep
// it as text, each tab and space is swapped for a private-use stand-in before
// parsing and back afterwards, so offsets don't move.
struct WhitespaceStandIns {
  char16_t tab = 0xE000;
  char16_t space = 0xE001;
};
// The first two private-use characters absent from the markdown, also as
// numeric references. nullopt when none are free.
std::optional<WhitespaceStandIns> chooseWhitespaceStandIns(std::u16string_view markdown);
std::u16string protectLeadingWhitespace(std::u16string_view markdown, WhitespaceStandIns standIns);
void restoreLeadingWhitespace(std::u16string &text, WhitespaceStandIns standIns);

std::u16string serializeInline(std::u16string_view text, const std::vector<FormattingRange> &ranges);
// The marker a block's line starts with. `parentContentColumn` is the parent
// item's content column, or -1 to assume single-digit markers.
std::u16string markdownLinePrefix(const BlockRange &block, int parentContentColumn = -1);

} // namespace Markdown::Input
