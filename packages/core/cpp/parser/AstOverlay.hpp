#pragma once

#include "BlockSlots.hpp"
#include "DocumentStore.hpp"
#include "MarkdownASTNode.hpp"
#include "TextLinkRecognizer.hpp"
#include <string>
#include <unordered_set>

namespace Markdown {

// What a host converter adds to a shared document as it copies the tree into its
// own node types: the slot and image ids that renderers and image sources read,
// and the links that text recognition found. The tree itself stays as parsed.
class AstOverlay {
public:
  // `activeSlotIds`: the slots a React child stands in for. `annotateImages`:
  // every image gets its occurrence id. Both are GitHub-flavor features.
  AstOverlay(const ParsedDocument &document, std::unordered_set<std::string> activeSlotIds, bool annotateImages,
             TextLinkReplacements links)
      : blocks_(document.blocks), activeSlotIds_(std::move(activeSlotIds)), annotateImages_(annotateImages),
        links_(std::move(links)) {}

  // Calls f(key, value) for each attribute `node` gets on top of its own.
  template <typename F> void forEachAttribute(const MarkdownASTNode &node, F &&f) const {
    if (!activeSlotIds_.empty()) {
      auto slot = blocks_.slotByNode.find(&node);
      if (slot != blocks_.slotByNode.end() && activeSlotIds_.count(blocks_.slots[slot->second].id) != 0) {
        const BlockSlot &block = blocks_.slots[slot->second];
        f(kBlockSlotIdAttribute, block.id);
        f(kBlockSlotKindAttribute, std::string(blockSlotKindName(block.kind())));
      }
    }
    if (annotateImages_ && node.type == NodeType::Image) {
      auto image = blocks_.imageByNode.find(&node);
      if (image != blocks_.imageByNode.end())
        f(kImageOccurrenceIdAttribute, blocks_.images[image->second].id);
    }
  }

  // Calls f(child) for each child of `node` as the host should see it, with
  // recognized links in place of the text they cover. A recognized code link
  // wraps the very Code node it replaces, so a Link's children are taken as is.
  template <typename F> void forEachChild(const MarkdownASTNode &node, F &&f) const {
    for (const auto &child : node.children) {
      auto replaced = links_.empty() || node.type == NodeType::Link ? links_.end() : links_.find(child.get());
      if (replaced == links_.end()) {
        f(child);
        continue;
      }
      for (const auto &piece : replaced->second)
        f(piece);
    }
  }

private:
  const CollectedBlocks &blocks_;
  std::unordered_set<std::string> activeSlotIds_;
  bool annotateImages_;
  TextLinkReplacements links_;
};

} // namespace Markdown
