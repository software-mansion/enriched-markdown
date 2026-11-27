#pragma once

#include <folly/dynamic.h>
#include <react/renderer/graphics/Float.h>
#include <string>
#include <vector>

namespace facebook::react {

// What the view needs to know about one slot child: whether an eligible block
// carries its id (`placed`) and, if so, the height (dp) the shadow node measured
// for it, which the native placeholder reserves. Positions stay in the shadow
// node; Fabric lays the children out.
struct BlockSlotPlacement {
  std::string id;
  Float height{0};
  bool placed{false};

  bool operator==(const BlockSlotPlacement &other) const {
    return id == other.id && height == other.height && placed == other.placed;
  }
  bool operator!=(const BlockSlotPlacement &other) const {
    return !(*this == other);
  }
};

class MarkdownTextState {
public:
  MarkdownTextState() = default;

  // Kotlin only ever sends the counter; the placements the shadow node published survive.
  MarkdownTextState(MarkdownTextState const &previousState, folly::dynamic data)
      : forceHeightRecalculationCounter_(data.count("forceHeightRecalculationCounter") != 0
                                             ? (int)data["forceHeightRecalculationCounter"].getInt()
                                             : previousState.forceHeightRecalculationCounter_),
        slotPlacements_(previousState.slotPlacements_) {}

  MarkdownTextState(int forceHeightRecalculationCounter, std::vector<BlockSlotPlacement> slotPlacements)
      : forceHeightRecalculationCounter_(forceHeightRecalculationCounter), slotPlacements_(std::move(slotPlacements)) {}

  folly::dynamic getDynamic() const;

  int getForceHeightRecalculationCounter() const;

  const std::vector<BlockSlotPlacement> &getSlotPlacements() const {
    return slotPlacements_;
  }

private:
  int forceHeightRecalculationCounter_{0};
  std::vector<BlockSlotPlacement> slotPlacements_;
};

} // namespace facebook::react
