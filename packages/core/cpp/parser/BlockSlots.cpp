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

std::string fnv1a64Hex(const std::string &text) {
  uint64_t hash = 14695981039346656037ULL;
  for (unsigned char byte : text) {
    hash ^= byte;
    hash *= 1099511628211ULL;
  }
  char buffer[17];
  std::snprintf(buffer, sizeof(buffer), "%016llx", static_cast<unsigned long long>(hash));
  return buffer;
}

std::string attribute(const MarkdownASTNode &node, const std::string &key) {
  auto it = node.attributes.find(key);
  return it == node.attributes.end() ? std::string() : it->second;
}

void appendAltText(const MarkdownASTNode &node, std::string &out) {
  if (!node.content.empty()) {
    out += node.content;
  } else if (node.type == NodeType::SoftBreak || node.type == NodeType::LineBreak) {
    out += ' ';
  }
  for (const auto &child : node.children) {
    appendAltText(*child, out);
  }
}

std::string altText(const MarkdownASTNode &node) {
  std::string text;
  appendAltText(node, text);
  size_t start = text.find_first_not_of(" \t\r\n");
  if (start == std::string::npos)
    return std::string();
  size_t end = text.find_last_not_of(" \t\r\n");
  return text.substr(start, end - start + 1);
}

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

// Ids count earlier occurrences of the same base, in document order.
class IdCounter {
public:
  std::string next(const char *kind, const std::string &url) {
    std::string base = std::string(kind) + ':' + fnv1a64Hex(url);
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

// Walks the tree once, collecting slots and image occurrences. With a non-null
// activeSlotIds or annotateImages it also stamps the attributes; the collect()
// entry point passes neither and never writes.
struct Visitor {
  IdCounter slotIds;
  IdCounter imageIds;
  CollectedBlocks collected;
  const std::unordered_set<std::string> *activeSlotIds = nullptr;
  bool annotateImages = false;

  void recordImage(MarkdownASTNode &image, ImagePlacement placement) {
    std::string url = attribute(image, kUrlAttribute);
    std::string id = imageIds.next("image", url);
    collected.images.push_back({id, url, altText(image), attribute(image, kTitleAttribute), placement});
    if (annotateImages) {
      image.setAttribute(kImageOccurrenceIdAttribute, id);
    }
  }

  void recordSlot(MarkdownASTNode &block, const BlockKind &kind, const MarkdownASTNode &media,
                  BlockSlotPlacement placement) {
    std::string url = attribute(media, kUrlAttribute);
    std::string id = slotIds.next(kind.name, url);
    collected.slots.push_back({id, kind.kind, url, kind.hasText ? altText(media) : std::string(),
                               kind.hasText ? attribute(media, kTitleAttribute) : std::string(), placement});
    if (activeSlotIds && activeSlotIds->count(id)) {
      block.setAttribute(kBlockSlotIdAttribute, id);
      block.setAttribute(kBlockSlotKindAttribute, kind.name);
    }
  }

  void visit(MarkdownASTNode &node, NodeType parentType, Ancestors ancestors) {
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
        BlockSlotPlacement placement = slotPlacement(parentType);
        recordSlot(node, kind, *media, placement);
        if (kind.isImageOccurrence) {
          recordImage(*const_cast<MarkdownASTNode *>(media), imagePlacement(placement));
        }
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
    for (auto &child : node.children) {
      visit(*child, node.type, childAncestors);
    }
  }
};

CollectedBlocks walk(MarkdownASTNode &root, const std::unordered_set<std::string> *activeSlotIds, bool annotateImages) {
  Visitor visitor;
  visitor.activeSlotIds = activeSlotIds;
  visitor.annotateImages = annotateImages;
  for (auto &child : root.children) {
    visitor.visit(*child, root.type, Ancestors{});
  }
  return std::move(visitor.collected);
}

} // namespace

CollectedBlocks collect(const MarkdownASTNode &root) {
  // The read-only walk never calls setAttribute (both flags off).
  return walk(const_cast<MarkdownASTNode &>(root), nullptr, false);
}

void annotate(MarkdownASTNode &root, const std::unordered_set<std::string> &activeSlotIds, bool annotateImages) {
  if (activeSlotIds.empty() && !annotateImages)
    return;
  walk(root, activeSlotIds.empty() ? nullptr : &activeSlotIds, annotateImages);
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
