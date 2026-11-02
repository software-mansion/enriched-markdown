#pragma once

#include "MarkdownASTNode.hpp"
#include <cstddef>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace Markdown {

enum class BlockSlotKind { Image, Video, Link };

// How far a block's syntax has streamed in on one line: not this kind, still
// open, or complete.
enum class BlockLineState { None, Open, Complete };

// Everything the core knows about one replaceable block kind. Adding a kind is
// one entry in kBlockKinds (BlockKinds.cpp); the collector, the annotator, the
// streaming filter and the name lookups all iterate the table. The hosts keep a
// matching per-kind entry for the margins the placeholder takes.
struct BlockKind {
  BlockSlotKind kind;
  // The `blockSlotKind` attribute value and the id prefix.
  const char *name;
  // The node carrying the URL when `node` is a block of this kind, else nullptr.
  const MarkdownASTNode *(*media)(const MarkdownASTNode &node);
  // Whether the block carries text (alt or label) and a title.
  bool hasText;
  // Whether the media node is also an image occurrence (resolveImageSource).
  bool isImageOccurrence;
  // Whether the walk continues into the block's children (for occurrences inside it).
  bool walkChildren;
  // Classifies a streamed line whose quote markers are already stripped.
  BlockLineState (*lineState)(std::string_view body);
};

constexpr size_t kBlockKindCount = 3;
extern const BlockKind kBlockKinds[kBlockKindCount];

const BlockKind &blockKindFor(BlockSlotKind kind);
const BlockKind *blockKindNamed(const std::string &name);

// Inline syntax helpers shared by the line classifiers and the streaming
// filter's tail scanner, so both read `[label](destination)` the same way.
namespace InlineSyntax {
// Whether the character at `index` is escaped by an odd run of backslashes.
bool isEscaped(std::string_view text, size_t index);
// The code spans of `text` (backtick runs of equal length), in order, as
// [start, end) byte ranges, found in one pass.
struct CodeSpans {
  explicit CodeSpans(std::string_view text);
  std::vector<std::pair<size_t, size_t>> ranges;

  // Walks the spans alongside a left-to-right scan: the end of the span that
  // holds `index`, or npos when it holds none. Indices must not decrease.
  class Cursor {
  public:
    explicit Cursor(const CodeSpans &spans) : next_(spans.ranges.begin()), end_(spans.ranges.end()) {}
    size_t spanEndAt(size_t index);

  private:
    std::vector<std::pair<size_t, size_t>>::const_iterator next_;
    std::vector<std::pair<size_t, size_t>>::const_iterator end_;
  };
};
// The `]` closing the label that opens at `bracket`, with nested brackets
// balanced the way CommonMark reads them (`[![thumb](u)]`), skipping escapes
// and code spans; npos when it has not arrived.
size_t labelEnd(std::string_view text, size_t bracket, const CodeSpans &spans);
// The `)` closing a `(destination "title")` that opens at `openParen` (the `(`
// after `]`): the destination may be `<pointy>` or hold balanced parentheses,
// the optional title is quoted or parenthesised, and escapes are honoured
// throughout; npos when it has not arrived, kInvalid when what follows can no
// longer close it (`[a](u then prose`), with `stop` set to where it gave up.
constexpr size_t kInvalid = std::string_view::npos - 1;
size_t destinationEnd(std::string_view text, size_t openParen, size_t *stop = nullptr);
// How far a `[label](destination)` or `![alt](destination)` that starts at
// `bracket` (the `[`) has streamed in: Open while its syntax can still close,
// Complete when it closed and only whitespace follows, None when it is prose
// (`[INFO] done`, or text continuing after a closed link).
BlockLineState state(std::string_view text, size_t bracket);
} // namespace InlineSyntax

} // namespace Markdown
