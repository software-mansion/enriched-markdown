#include "MarkdownTextState.h"

namespace facebook::react {

int MarkdownTextState::getForceHeightRecalculationCounter() const {
  return forceHeightRecalculationCounter_;
}

folly::dynamic MarkdownTextState::getDynamic() const {
  folly::dynamic placements = folly::dynamic::array();
  for (const auto &placement : slotPlacements_) {
    folly::dynamic entry = folly::dynamic::object();
    entry["id"] = placement.id;
    entry["height"] = placement.height;
    entry["placed"] = placement.placed;
    placements.push_back(std::move(entry));
  }
  folly::dynamic state = folly::dynamic::object();
  state["slotPlacements"] = std::move(placements);
  return state;
}

} // namespace facebook::react
