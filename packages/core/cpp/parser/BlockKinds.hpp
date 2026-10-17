#pragma once

#include "MarkdownASTNode.hpp"
#include <cstddef>
#include <string>

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
  BlockLineState (*lineState)(const std::string &body);
};

constexpr size_t kBlockKindCount = 3;
extern const BlockKind kBlockKinds[kBlockKindCount];

const BlockKind &blockKindFor(BlockSlotKind kind);
const BlockKind *blockKindNamed(const std::string &name);

} // namespace Markdown
