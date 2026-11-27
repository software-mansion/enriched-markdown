#pragma once
#import "ENRMHighlightCoordinator.h"
#import "ENRMTextHighlight.h"
#include <string>
#include <vector>

// Shared by EnrichedMarkdown and EnrichedMarkdownText, whose codegen types
// differ only in name.

template <typename HighlightProps>
inline NSArray<ENRMTextHighlight *> *ENRMTextHighlightsFromProps(const std::vector<HighlightProps> &items)
{
  NSMutableArray<ENRMTextHighlight *> *result = [NSMutableArray arrayWithCapacity:items.size()];
  for (const auto &item : items) {
    // An empty range draws nothing but keeps the later entries at their index.
    NSRange range = item.start < 0 || item.end <= item.start
                        ? NSMakeRange(0, 0)
                        : NSMakeRange((NSUInteger)item.start, (NSUInteger)(item.end - item.start));
    [result addObject:[[ENRMTextHighlight alloc] initWithRange:range
                                                         color:ENRMColorFromARGB(item.color)
                                                  borderRadius:item.borderRadius
                                                       padding:item.padding]];
  }
  return result;
}

template <typename HighlightProps>
inline bool ENRMTextHighlightPropsChanged(const std::vector<HighlightProps> &a, const std::vector<HighlightProps> &b)
{
  if (a.size() != b.size()) {
    return true;
  }
  for (size_t i = 0; i < a.size(); i++) {
    if (a[i].start != b[i].start || a[i].end != b[i].end || a[i].color != b[i].color ||
        a[i].borderRadius != b[i].borderRadius || a[i].padding != b[i].padding) {
      return true;
    }
  }
  return false;
}

template <typename Emitter>
inline void ENRMEmitRenderedTextChange(const Emitter &emitter, ENRMHighlightCoordinator *coordinator)
{
  std::vector<typename Emitter::OnRenderedTextChangeBlocks> blocks;
  blocks.reserve(coordinator.renderedBlocks.count);
  for (ENRMRenderedTextBlock *block in coordinator.renderedBlocks) {
    blocks.push_back({.start = (int)block.start, .end = (int)block.end, .kind = std::string(block.kind.UTF8String)});
  }
  emitter.onRenderedTextChange({.text = std::string(coordinator.renderedText.UTF8String ?: ""), .blocks = blocks});
}

template <typename Emitter>
inline void ENRMEmitHighlightLayout(const Emitter &emitter, NSArray<ENRMHighlightRect *> *rects)
{
  std::vector<typename Emitter::OnHighlightLayoutHighlights> highlights;
  highlights.reserve(rects.count);
  for (ENRMHighlightRect *rect in rects) {
    highlights.push_back({
        .index = (int)rect.index,
        .x = rect.rect.origin.x,
        .y = rect.rect.origin.y,
        .width = rect.rect.size.width,
        .height = rect.rect.size.height,
    });
  }
  emitter.onHighlightLayout({.highlights = highlights});
}
