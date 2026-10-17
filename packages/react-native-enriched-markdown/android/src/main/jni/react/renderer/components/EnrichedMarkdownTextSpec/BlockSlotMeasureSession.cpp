#include "BlockSlotMeasureSession.h"

#include <cmath>
#include <limits>

namespace facebook::react {

namespace {
thread_local BlockSlotMeasureSession *gCurrentSession = nullptr;
}

BlockSlotMeasureSession::BlockSlotMeasureSession(std::vector<BlockSlotChild> children,
                                                 const LayoutContext &layoutContext, LayoutDirection layoutDirection)
    : children_(std::move(children)), layoutContext_(layoutContext), layoutDirection_(layoutDirection) {
  ids_.reserve(children_.size());
  for (const auto &child : children_) {
    ids_.push_back(child.id);
  }
}

BlockSlotMeasureSession *BlockSlotMeasureSession::current() {
  return gCurrentSession;
}

BlockSlotMeasureSession::Scope::Scope(BlockSlotMeasureSession *session) : previous_(gCurrentSession) {
  gCurrentSession = session;
}

BlockSlotMeasureSession::Scope::~Scope() {
  gCurrentSession = previous_;
}

float BlockSlotMeasureSession::measure(const std::string &slotId, float xPx, float yPx, float widthPx) {
  const Float scale = layoutContext_.pointScaleFactor > 0 ? layoutContext_.pointScaleFactor : 1;
  for (const auto &child : children_) {
    if (child.id != slotId) {
      continue;
    }
    const Float width = widthPx / scale;
    // An undefined host width reaches here as +inf; Yoga cannot take an infinite
    // minimum, so the child is measured at its own width then.
    const bool finiteWidth = std::isfinite(width);
    LayoutConstraints constraints;
    constraints.minimumSize = Size{finiteWidth ? width : 0, 0};
    constraints.maximumSize = Size{width, std::numeric_limits<Float>::infinity()};
    constraints.layoutDirection = layoutDirection_;
    const Size size = child.node->measure(layoutContext_, constraints);
    // The child is laid out at its height rounded up to the pixel grid; the walk
    // reserves the same, so the next segment never overlaps it.
    const float heightPx = std::ceil(static_cast<float>(size.height * scale));
    const BlockSlotFrame frame{slotId, xPx / scale, yPx / scale, width, heightPx / scale, true};
    // Re-measuring the same id (a repeated walk) replaces the earlier frame.
    for (auto &placed : placed_) {
      if (placed.id == slotId) {
        placed = frame;
        return heightPx;
      }
    }
    placed_.push_back(frame);
    return heightPx;
  }
  return 0;
}

std::vector<BlockSlotFrame> BlockSlotMeasureSession::frames() const {
  std::vector<BlockSlotFrame> frames;
  frames.reserve(children_.size());
  for (const auto &child : children_) {
    BlockSlotFrame frame;
    frame.id = child.id;
    for (const auto &placed : placed_) {
      if (placed.id == child.id) {
        frame = placed;
        break;
      }
    }
    frames.push_back(std::move(frame));
  }
  return frames;
}

} // namespace facebook::react
