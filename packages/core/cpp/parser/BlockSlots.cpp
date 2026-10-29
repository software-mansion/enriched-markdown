#include "BlockSlots.hpp"
#include <cstdint>
#include <cstdio>
#include <unordered_map>

namespace Markdown {

const char *const kBlockSlotIdAttribute = "blockSlotId";
const char *const kBlockSlotKindAttribute = "blockSlotKind";
const char *const kImageOccurrenceIdAttribute = "imageOccurrenceId";

namespace {

const std::string kUrlAttribute = "url";
const std::string kTitleAttribute = "title";

bool isSlotContainer(NodeType type) {
  return type == NodeType::Document || type == NodeType::Blockquote || type == NodeType::Admonition;
}

BlockSlotPlacement slotPlacement(NodeType container) {
  switch (container) {
    case NodeType::Blockquote:
      return BlockSlotPlacement::Blockquote;
    case NodeType::Admonition:
      return BlockSlotPlacement::Admonition;
    default:
      return BlockSlotPlacement::Root;
  }
}

ImagePlacement imagePlacement(BlockSlotPlacement placement) {
  switch (placement) {
    case BlockSlotPlacement::Blockquote:
      return ImagePlacement::Blockquote;
    case BlockSlotPlacement::Admonition:
      return ImagePlacement::Admonition;
    default:
      return ImagePlacement::Root;
  }
}

// Ids count earlier entries with the same base, in document order.
class IdCounter {
public:
  std::string next(const char *prefix, const std::string &identity) {
    std::string base = std::string(prefix) + ':' + fnv1a64Hex(identity);
    unsigned &count = counts_[base];
    std::string id = base + ':' + std::to_string(count);
    count++;
    return id;
  }

private:
  std::unordered_map<std::string, unsigned> counts_;
};

struct Ancestors {
  bool inLink = false;
  bool inTable = false;
  bool inList = false;
};

// Walks the tree once, collecting slots and image occurrences.
struct Visitor {
  IdCounter slotIds;
  IdCounter imageIds;
  CollectedBlocks collected;

  const ImageOccurrence &recordImage(const MarkdownASTNode &image, ImagePlacement placement) {
    std::string url = nodeAttribute(image, kUrlAttribute);
    std::string alt = inlineText(image);
    std::string title = nodeAttribute(image, kTitleAttribute);
    std::string id = imageIds.next("img", blockIdentity(url, alt, title));
    collected.imageByNode[&image] = collected.images.size();
    collected.images.push_back({std::move(id), std::move(url), std::move(alt), std::move(title), placement});
    return collected.images.back();
  }

  void recordSlot(const MarkdownASTNode &block, const BlockKind &kind, const MarkdownASTNode &media,
                  BlockSlotPlacement placement) {
    BlockSlot slot;
    slot.placement = placement;
    slot.node = &block;
    slot.id = slotIds.next(kind.name, kind.fill(media, slot));
    if (auto *image = std::get_if<ImageSlotFields>(&slot.fields))
      image->occurrenceId = recordImage(media, imagePlacement(placement)).id;
    collected.slotByNode[&block] = collected.slots.size();
    collected.slots.push_back(std::move(slot));
  }

  void visit(const MarkdownASTNode &node, NodeType parentType, Ancestors ancestors) {
    if (node.type == NodeType::CodeBlock)
      collected.lastCodeBlock = &node;
    if (node.type == NodeType::Image) {
      recordImage(node, ancestors.inLink    ? ImagePlacement::Link
                        : ancestors.inTable ? ImagePlacement::Table
                        : ancestors.inList  ? ImagePlacement::List
                                            : ImagePlacement::Inline);
      return;
    }

    if (isSlotContainer(parentType) && !ancestors.inList) {
      for (const auto &kind : kBlockKinds) {
        const MarkdownASTNode *media = kind.media(node);
        if (media == nullptr)
          continue;
        recordSlot(node, kind, *media, slotPlacement(parentType));
        if (!kind.walkChildren)
          return;
        break;
      }
    } else if (node.type == NodeType::Video) {
      return;
    }

    Ancestors childAncestors = ancestors;
    switch (node.type) {
      case NodeType::Link:
        childAncestors.inLink = true;
        break;
      case NodeType::Table:
        childAncestors.inTable = true;
        break;
      case NodeType::ListItem:
        childAncestors.inList = true;
        break;
      default:
        break;
    }
    for (const auto &child : node.children) {
      visit(*child, node.type, childAncestors);
    }
  }
};

} // namespace

CollectedBlocks collect(const MarkdownASTNode &root) {
  Visitor visitor;
  for (const auto &child : root.children) {
    visitor.visit(*child, root.type, Ancestors{});
  }
  return std::move(visitor.collected);
}

bool isSlotComplete(const CollectedBlocks &blocks, const BlockSlot &slot, bool endsInsideOpenCodeFence) {
  return !endsInsideOpenCodeFence || slot.node != blocks.lastCodeBlock;
}

std::string fnv1a64Hex(const std::string &bytes) {
  uint64_t hash = 14695981039346656037ULL;
  for (unsigned char byte : bytes) {
    hash ^= byte;
    hash *= 1099511628211ULL;
  }
  char buffer[17];
  std::snprintf(buffer, sizeof(buffer), "%016llx", static_cast<unsigned long long>(hash));
  return buffer;
}

const char *blockSlotKindName(BlockSlotKind kind) {
  return blockKindFor(kind).name;
}

const char *blockSlotPlacementName(BlockSlotPlacement placement) {
  switch (placement) {
    case BlockSlotPlacement::Blockquote:
      return "blockquote";
    case BlockSlotPlacement::Admonition:
      return "admonition";
    default:
      return "root";
  }
}

const char *imagePlacementName(ImagePlacement placement) {
  switch (placement) {
    case ImagePlacement::Blockquote:
      return "blockquote";
    case ImagePlacement::Admonition:
      return "admonition";
    case ImagePlacement::Inline:
      return "inline";
    case ImagePlacement::List:
      return "list";
    case ImagePlacement::Table:
      return "table";
    case ImagePlacement::Link:
      return "link";
    default:
      return "root";
  }
}

} // namespace Markdown
