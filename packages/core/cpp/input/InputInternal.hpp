#pragma once

#include "MarkdownASTNode.hpp"
#include "MarkdownInput.hpp"
#include <cstddef>
#include <cstdint>
#include <string_view>
#include <vector>

// Pieces of the module the tests reach into. Not part of the host-facing API.
namespace Markdown::Input {

// markdownEscape.ts: the indices in `text` to put a backslash in front of,
// ascending. A position does not depend on the delimiters written around it.
std::vector<uint32_t> markdownEscapePositions(std::u16string_view text);

// Start offsets of each line of `text` (always at least one), and a line's end
// offset (the position of its newline, or the text length).
std::vector<size_t> lineStartsOf(std::u16string_view text);
inline size_t lineEndOf(std::u16string_view text, const std::vector<size_t> &lineStarts, size_t line) {
  return line + 1 < lineStarts.size() ? lineStarts[line + 1] - 1 : text.size();
}

// normalizeImport.ts. The parser reports what md4c saw, which the stores'
// invariants do not always admit; these restore them.
//
// Sorted by start, with same-type ranges that overlap or touch merged into one.
// Links merge only when their urls match. Empty ranges are dropped.
std::vector<FormattingRange> normalizeFormattingRanges(std::vector<FormattingRange> ranges);
// One block per line, covering exactly that line, sorted by start. A block
// spanning lines is copied onto each; of two blocks on one line the list item
// wins over the heading over the paragraph.
std::vector<BlockRange> normalizeBlockRanges(std::u16string_view text, const std::vector<BlockRange> &blocks);

// InputParser.ts. Walks md4c's AST the way the TypeScript walks the JSON one.
// Ordinals stay at their placeholder 1 and levels as the walk found them;
// `parse` settles both with `normalizeListMetadata`. Returns false when the AST
// nests deeper than the walk will recurse.
bool parseResultFromAst(const Markdown::MarkdownASTNode &ast, ParseResult &result);

// Leading whitespace is kept as text instead of being dropped or opening an
// indented code block: each tab and space of the run is swapped one for one
// with a private-use stand-in md4c reads as text, and swapped back in the plain
// text afterwards, so offsets never move.
std::u16string protectLeadingWhitespace(std::u16string_view markdown);
void restoreLeadingWhitespace(std::u16string &text);

// MarkdownSerializer.ts.
std::u16string serializeInline(std::u16string_view text, const std::vector<FormattingRange> &ranges);
// The marker a block opens its line with. `parentContentColumn` is the content
// column of the list item it nests under (-1 when unknown, which assumes
// single-digit markers all the way up).
std::u16string markdownLinePrefix(const BlockRange &block, int parentContentColumn = -1);

} // namespace Markdown::Input
