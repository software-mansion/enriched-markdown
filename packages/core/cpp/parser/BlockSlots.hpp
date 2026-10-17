#pragma once

#include "BlockKinds.hpp"
#include "MarkdownASTNode.hpp"
#include <string>
#include <unordered_set>
#include <vector>

namespace Markdown {

// The container a block slot sits in directly.
enum class BlockSlotPlacement { Root, Blockquote, Admonition };

// Where an image occurrence is rendered. The first three match BlockSlotPlacement
// and mean a standalone image paragraph a slot can replace.
enum class ImagePlacement { Root, Blockquote, Admonition, Inline, List, Table, Link };

// A block-level node with a URL that a React element may stand in for (one of
// kBlockKinds in BlockKinds.hpp), placed directly in the document, a blockquote or
// an admonition that is not itself inside a list item (the hosts lay lists out as
// text, so nothing inside one can be replaced).
struct BlockSlot {
  std::string id;
  BlockSlotKind kind;
  std::string url;
  std::string altText; // the image's alt text or the link's label; empty for videos
  std::string title;   // empty for videos
  BlockSlotPlacement placement;
};

struct ImageOccurrence {
  std::string id;
  std::string url;
  std::string altText;
  std::string title;
  ImagePlacement placement;
};

struct CollectedBlocks {
  std::vector<BlockSlot> slots;
  std::vector<ImageOccurrence> images;
};

// Attributes stamped on the AST by annotate().
extern const char *const kBlockSlotIdAttribute;       // on the paragraph or video node a slot replaces
extern const char *const kBlockSlotKindAttribute;     // "image" | "video"
extern const char *const kImageOccurrenceIdAttribute; // on every Image node

// Document order. An id is "<kind>:<fnv1a64 of url, hex>:<n>". For a slot, n counts
// earlier slots of the same kind and url; for an image occurrence, earlier images
// of the same url. Slot ids therefore survive appends, edits elsewhere and inline
// images being added or removed; occurrence ids survive appends and edits elsewhere.
CollectedBlocks collect(const MarkdownASTNode &root);

// One walk that stamps blockSlotId/blockSlotKind on the block nodes whose slot id
// is in activeSlotIds and, when annotateImages, imageOccurrenceId on every Image.
void annotate(MarkdownASTNode &root, const std::unordered_set<std::string> &activeSlotIds, bool annotateImages);

const char *blockSlotKindName(BlockSlotKind kind);
const char *blockSlotPlacementName(BlockSlotPlacement placement);
const char *imagePlacementName(ImagePlacement placement);

} // namespace Markdown
