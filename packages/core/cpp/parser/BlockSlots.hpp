#pragma once

#include "BlockKinds.hpp"
#include "MarkdownASTNode.hpp"
#include <string>
#include <unordered_map>
#include <variant>
#include <vector>

namespace Markdown {

// The container a block slot sits in directly.
enum class BlockSlotPlacement { Root, Blockquote, Admonition };

// Where an image occurrence is rendered. The first three match BlockSlotPlacement
// and mean a standalone image paragraph a slot can replace.
enum class ImagePlacement { Root, Blockquote, Admonition, Inline, List, Table, Link };

// What each kind of slot carries, filled by its kBlockKinds entry.
struct ImageSlotFields {
  static constexpr BlockSlotKind kind = BlockSlotKind::Image;
  std::string url;
  std::string altText;
  std::string title;
  std::string occurrenceId; // the image's entry in CollectedBlocks::images
};

struct VideoSlotFields {
  static constexpr BlockSlotKind kind = BlockSlotKind::Video;
  std::string url;
};

struct LinkSlotFields {
  static constexpr BlockSlotKind kind = BlockSlotKind::Link;
  std::string url;
  std::string label;
  std::string title;
};

struct CodeSlotFields {
  static constexpr BlockSlotKind kind = BlockSlotKind::Code;
  std::string language; // empty when the block has none
  std::string code;     // without trailing newlines
};

using BlockSlotFields = std::variant<ImageSlotFields, VideoSlotFields, LinkSlotFields, CodeSlotFields>;

// A block-level node that a React element may stand in for (one of kBlockKinds
// in BlockKinds.hpp), placed directly in the document, a blockquote or an
// admonition that is not itself inside a list item (the hosts lay lists out as
// text, so nothing inside one can be replaced).
struct BlockSlot {
  std::string id;
  BlockSlotPlacement placement;
  const MarkdownASTNode *node = nullptr; // the paragraph, video or code block the slot replaces
  BlockSlotFields fields;

  BlockSlotKind kind() const {
    return std::visit([](const auto &kindFields) { return kindFields.kind; }, fields);
  }
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
  // Indexes into slots and images by the node they describe (the paragraph,
  // video or code block a slot replaces, the Image node), valid while the tree
  // lives.
  std::unordered_map<const MarkdownASTNode *, size_t> slotByNode;
  std::unordered_map<const MarkdownASTNode *, size_t> imageByNode;
  // The last code block in document order, a slot or not (one in a list item):
  // the only one whose fence can still be open in a streamed document.
  const MarkdownASTNode *lastCodeBlock = nullptr;
};

// Attributes the hosts add to converted nodes (AstOverlay.hpp).
extern const char *const kBlockSlotIdAttribute;       // on the paragraph, video or code block a slot replaces
extern const char *const kBlockSlotKindAttribute;     // a kind's name: "image" | "video" | "link" | "code"
extern const char *const kImageOccurrenceIdAttribute; // on every Image node

// Document order, without touching the tree. Ids are opaque to apps; inside they
// are "<kind>:<hash>:<n>" for a slot and "img:<hash>:<n>" for an image
// occurrence, where the hash covers the URL, alt text or label, and title (a code
// block's language alone), and n counts earlier entries with the same hash. A
// block keeps its id while it is unchanged, across appends, edits elsewhere and
// inline images coming and going; only removing an identical earlier block
// shifts it. A code block keeps its id while its code changes.
CollectedBlocks collect(const MarkdownASTNode &root);

// False only for the code block a streamed document's open fence parses to, the
// last one, since the fence runs to the end; `endsInsideOpenCodeFence` is the
// streaming filter's flag for the markdown `blocks` came from. A fence inside an
// HTML block is one the filter sees and the parser does not, so it marks the
// code block before it instead.
bool isSlotComplete(const CollectedBlocks &blocks, const BlockSlot &slot, bool endsInsideOpenCodeFence);

// FNV-1a 64 of the bytes, as 16 lowercase hex digits; the web collector matches it.
std::string fnv1a64Hex(const std::string &bytes);
// What a slot or occurrence id hashes: the fields joined by U+001F.
inline std::string blockIdentity(const std::string &url, const std::string &text, const std::string &title) {
  return url + '\x1f' + text + '\x1f' + title;
}

const char *blockSlotKindName(BlockSlotKind kind);
const char *blockSlotPlacementName(BlockSlotPlacement placement);
const char *imagePlacementName(ImagePlacement placement);

} // namespace Markdown
