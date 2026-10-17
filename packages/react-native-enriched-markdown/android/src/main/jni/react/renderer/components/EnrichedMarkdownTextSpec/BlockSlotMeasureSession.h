#pragma once

#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>
#include <react/renderer/core/LayoutPrimitives.h>
#include <react/renderer/core/LayoutableShadowNode.h>
#include <string>
#include <vector>

namespace facebook::react {

struct BlockSlotChild {
  std::string id;
  const LayoutableShadowNode *node;
};

// Where the GFM host's shadow node placed one slot child, in dp, relative to the
// host content box. Unplaced slots (no eligible block for their id) carry zeros.
struct BlockSlotFrame {
  std::string id;
  Float x{0};
  Float y{0};
  Float width{0};
  Float height{0};
  bool placed{false};
};

/**
 * One measurement pass of the GFM host's slot children. The shadow node installs
 * it (thread-local) around the Java measure call; Kotlin's measurement walk calls
 * back through MeasurementStore.nativeMeasureBlockSlot with each slot's absolute
 * origin and width in px, the session measures the child at that width and
 * records where it goes, in dp.
 */
class BlockSlotMeasureSession {
public:
  BlockSlotMeasureSession(std::vector<BlockSlotChild> children, const LayoutContext &layoutContext,
                          LayoutDirection layoutDirection);

  static BlockSlotMeasureSession *current();

  // Installs `session` as current for the enclosing scope.
  class Scope {
  public:
    explicit Scope(BlockSlotMeasureSession *session);
    ~Scope();

  private:
    BlockSlotMeasureSession *previous_;
  };

  // Height in whole px (rounded up, as the child is laid out); 0 (and no frame)
  // for an unknown id.
  float measure(const std::string &slotId, float xPx, float yPx, float widthPx);

  const std::vector<std::string> &ids() const {
    return ids_;
  }

  // One frame per child, in child order; unplaced children carry zeros.
  std::vector<BlockSlotFrame> frames() const;

private:
  std::vector<BlockSlotChild> children_;
  std::vector<std::string> ids_;
  LayoutContext layoutContext_;
  LayoutDirection layoutDirection_;
  std::vector<BlockSlotFrame> placed_;
};

} // namespace facebook::react
