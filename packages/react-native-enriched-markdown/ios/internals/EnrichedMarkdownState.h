#pragma once
#include <memory>
#include <react/renderer/graphics/Float.h>
#include <string>
#include <vector>

namespace facebook::react {

/// What the view needs to know about one slot child: whether an eligible block
/// carries its id (`placed`) and, if so, the height the shadow node measured
/// for it, which the native placeholder reserves. Positions stay in the shadow
/// node; Fabric lays the children out.
struct ENRMBlockSlotPlacement {
  std::string id;
  Float height{0};
  bool placed{false};

  bool operator==(const ENRMBlockSlotPlacement &other) const {
    return id == other.id && height == other.height && placed == other.placed;
  }
  bool operator!=(const ENRMBlockSlotPlacement &other) const {
    return !(*this == other);
  }
};

class EnrichedMarkdownState {
public:
  EnrichedMarkdownState() = default;
  EnrichedMarkdownState(int counter, std::shared_ptr<void> ref) : counter_(counter), viewRef_(ref) {}
  EnrichedMarkdownState(int counter, std::shared_ptr<void> ref, std::vector<ENRMBlockSlotPlacement> slotPlacements)
      : counter_(counter), viewRef_(ref), slotPlacements_(std::move(slotPlacements)) {}

  int getHeightRecalculationCounter() const {
    return counter_;
  }
  std::shared_ptr<void> getComponentViewRef() const {
    return viewRef_;
  }
  const std::vector<ENRMBlockSlotPlacement> &getSlotPlacements() const {
    return slotPlacements_;
  }

  /// The view-initiated update: keeps the placements the shadow node published.
  EnrichedMarkdownState withHeightRecalculationCounter(int counter, std::shared_ptr<void> ref) const {
    return EnrichedMarkdownState(counter, ref, slotPlacements_);
  }

private:
  int counter_{0};
  std::shared_ptr<void> viewRef_{nullptr};
  std::vector<ENRMBlockSlotPlacement> slotPlacements_;
};

} // namespace facebook::react
