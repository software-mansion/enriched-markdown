#pragma once

#include "BlockKinds.hpp"
#include "MarkdownASTNode.hpp"
#include <string>
#include <unordered_map>
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
  std::string occurrenceId;    // the image occurrence of an image block; empty otherwise
  const MarkdownASTNode *node; // the paragraph or video node the slot replaces
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
  // Indexes into slots and images by the node they describe (the paragraph or
  // video a slot replaces, the Image node), valid while the tree lives.
  std::unordered_map<const MarkdownASTNode *, size_t> slotByNode;
  std::unordered_map<const MarkdownASTNode *, size_t> imageByNode;
};

// Attributes the hosts add to converted nodes (AstOverlay.hpp).
extern const char *const kBlockSlotIdAttribute;       // on the paragraph or video node a slot replaces
extern const char *const kBlockSlotKindAttribute;     // "image" | "video" | "link"
extern const char *const kImageOccurrenceIdAttribute; // on every Image node

// Document order, without touching the tree. Ids are opaque to apps; inside they
// are "<kind>:<hash>:<n>" for a slot and "img:<hash>:<n>" for an image
// occurrence, where the hash covers the URL, alt text or label, and title, and n
// counts earlier entries with the same hash. A block keeps its id while it is
// unchanged, across appends, edits elsewhere and inline images coming and going;
// only removing an identical earlier block shifts it.
CollectedBlocks collect(const MarkdownASTNode &root);

// FNV-1a 64 of the bytes, as 16 lowercase hex digits; the web collector matches it.
std::string fnv1a64Hex(const std::string &bytes);
// What a slot or occurrence id hashes: the fields joined by U+001F.
std::string blockIdentity(const std::string &url, const std::string &text, const std::string &title);

const char *blockSlotKindName(BlockSlotKind kind);
const char *blockSlotPlacementName(BlockSlotPlacement placement);
const char *imagePlacementName(ImagePlacement placement);

} // namespace Markdown
