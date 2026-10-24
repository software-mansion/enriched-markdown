#include "MarkdownContainerShadowNode.h"

#include <cmath>
#include <limits>
#include <react/renderer/components/EnrichedMarkdownTextSpec/ShadowNodes.h>
#include <react/renderer/core/LayoutContext.h>
#include <react/renderer/graphics/rounding.h>
#include <string_view>

namespace facebook::react {

extern const char MarkdownContainerComponentName[] = "EnrichedMarkdown";

namespace {

// Widths less than a pixel apart are the same width: Yoga hands measureContent
// the unrounded available width and layout() a frame whose two edges it rounded
// separately.
bool sameWidth(Float a, Float b, Float pointScaleFactor) {
  if (std::isinf(a) || std::isinf(b)) {
    return a == b;
  }
  const Float scale = pointScaleFactor > 0 ? pointScaleFactor : 1;
  return std::abs(a - b) * scale < 1;
}

} // namespace

void MarkdownContainerShadowNode::setMeasurementsManager(
    const std::shared_ptr<MarkdownContainerMeasurementManager> &measurementsManager) {
  ensureUnsealed();
  measurementsManager_ = measurementsManager;
}

void MarkdownContainerShadowNode::dirtyLayoutIfNeeded() {
  const auto state = this->getStateData();
  const auto counter = state.getForceHeightRecalculationCounter();

  if (forceHeightRecalculationCounter_ != counter) {
    forceHeightRecalculationCounter_ = counter;
    dirtyLayout();
  }
}

std::vector<BlockSlotChild> MarkdownContainerShadowNode::slotChildren() const {
  std::vector<BlockSlotChild> children;
  for (const auto &child : getChildren()) {
    // By component name, not RTTI: the slot's shadow node template is instantiated
    // in the app's autolinking library and typeinfo does not match across .so files.
    if (std::string_view(child->getComponentName()) != EnrichedMarkdownBlockSlotComponentName) {
      continue;
    }
    const auto *slot = static_cast<const EnrichedMarkdownBlockSlotShadowNode *>(child.get());
    children.push_back({slot->getConcreteProps().slotId, slot});
  }
  return children;
}

bool MarkdownContainerShadowNode::slotMeasurementMatches(const LayoutContext &layoutContext,
                                                         LayoutDirection layoutDirection,
                                                         const std::vector<BlockSlotChild> &children,
                                                         Float width) const {
  const auto &m = slotMeasurement_;
  if (!m.valid || m.props != getProps().get() || m.counter != getStateData().getForceHeightRecalculationCounter() ||
      !sameWidth(m.width, width, layoutContext.pointScaleFactor) || m.frames.size() != children.size()) {
    return false;
  }
  for (size_t i = 0; i < children.size(); i++) {
    if (m.frames[i].id != children[i].id) {
      return false;
    }
  }
  return slotHeightsUnchanged(layoutContext, layoutDirection, children);
}

// Laying a slot child out is cheap; measuring the document through Kotlin is not.
bool MarkdownContainerShadowNode::slotHeightsUnchanged(const LayoutContext &layoutContext,
                                                       LayoutDirection layoutDirection,
                                                       const std::vector<BlockSlotChild> &children) const {
  auto &m = slotMeasurement_;
  if (m.slotHeightsChecked) {
    return true;
  }
  const Float scale = layoutContext.pointScaleFactor > 0 ? layoutContext.pointScaleFactor : 1;
  for (size_t i = 0; i < children.size(); i++) {
    const auto &frame = m.frames[i];
    if (!frame.placed) {
      continue;
    }
    const float heightPx = measureBlockSlotHeightPx(*children[i].node, layoutContext, layoutDirection, frame.width);
    if (std::abs(heightPx - frame.height * scale) >= 0.5) {
      m.valid = false;
      return false;
    }
  }
  m.slotHeightsChecked = true;
  return true;
}

std::vector<BlockSlotPlacement> MarkdownContainerShadowNode::slotPlacements() const {
  std::vector<BlockSlotPlacement> placements;
  placements.reserve(slotMeasurement_.frames.size());
  for (const auto &frame : slotMeasurement_.frames) {
    placements.push_back({frame.id, frame.height, frame.placed});
  }
  return placements;
}

Size MarkdownContainerShadowNode::measureWithSlots(const LayoutContext &layoutContext,
                                                   const LayoutConstraints &layoutConstraints,
                                                   const std::vector<BlockSlotChild> &children) const {
  const Float width = layoutConstraints.maximumSize.width;
  if (slotMeasurementMatches(layoutContext, layoutConstraints.layoutDirection, children, width)) {
    return slotMeasurement_.size;
  }

  BlockSlotMeasureSession session(children, layoutContext, layoutConstraints.layoutDirection);
  Size size;
  {
    BlockSlotMeasureSession::Scope scope(&session);
    size =
        measurementsManager_->measure(getSurfaceId(), getTag(), getConcreteProps(), session.ids(), layoutConstraints);
  }
  slotMeasurement_ = SlotMeasurement{true,  true, getProps().get(), getStateData().getForceHeightRecalculationCounter(),
                                     width, size, session.frames()};
  return size;
}

// Only new props change the rendered markdown. When a parent is cloned, React Native's adoptYogaChild
// re-clones its children without new props, and dirtying those clones re-measures every settled message
// whenever the list above grows.
bool MarkdownContainerShadowNode::shouldNewRevisionDirtyMeasurement(const ShadowNode & /*sourceShadowNode*/,
                                                                    const ShadowNodeFragment &fragment) const {
  return fragment.props != nullptr;
}

Size MarkdownContainerShadowNode::measureContent(const LayoutContext &layoutContext,
                                                 const LayoutConstraints &layoutConstraints) const {
  const auto children = slotChildren();
  if (children.empty()) {
    slotMeasurement_ = SlotMeasurement{};
    return measurementsManager_->measure(getSurfaceId(), getTag(), getConcreteProps(), {}, layoutConstraints);
  }
  return measureWithSlots(layoutContext, layoutConstraints, children);
}

void MarkdownContainerShadowNode::layout(LayoutContext layoutContext) {
  ensureUnsealed();

  const auto children = slotChildren();
  if (children.empty()) {
    // The last slot child went away: tell the view so it stops reserving space.
    if (!getStateData().getSlotPlacements().empty()) {
      setStateData(MarkdownTextState(getStateData().getForceHeightRecalculationCounter(), {}));
    }
    return;
  }

  const auto layoutMetrics = getLayoutMetrics();
  const auto contentFrame = layoutMetrics.getContentFrame();

  // Yoga may have skipped measureContent (exact size known) after the document,
  // the height counter or the children changed, or measured at another width:
  // measure again then. The width tolerates the pixel rounding Yoga applies.
  bool stale = !slotMeasurement_.valid || slotMeasurement_.props != getProps().get() ||
               slotMeasurement_.counter != getStateData().getForceHeightRecalculationCounter() ||
               !sameWidth(slotMeasurement_.width, contentFrame.size.width, layoutMetrics.pointScaleFactor) ||
               slotMeasurement_.frames.size() != children.size();
  for (size_t i = 0; !stale && i < children.size(); i++) {
    stale = slotMeasurement_.frames[i].id != children[i].id;
  }
  stale = stale || !slotHeightsUnchanged(layoutContext, layoutMetrics.layoutDirection, children);
  if (stale) {
    LayoutConstraints constraints;
    constraints.minimumSize = Size{contentFrame.size.width, 0};
    constraints.maximumSize = Size{contentFrame.size.width, std::numeric_limits<Float>::infinity()};
    constraints.layoutDirection = layoutMetrics.layoutDirection;
    measureWithSlots(layoutContext, constraints, children);
  }

  // Clones walk down to each slot child, so the owning pointer keeps the latest
  // clone of this node alive until its children are adopted below.
  auto owningShadowNode = std::shared_ptr<ShadowNode>{};
  auto containerShadowNode = static_cast<MarkdownContainerShadowNode *>(this);

  for (size_t i = 0; i < children.size(); i++) {
    const auto &child = children[i];
    const BlockSlotFrame &frame = slotMeasurement_.frames[i];

    auto clonedShadowNode = std::shared_ptr<ShadowNode>{};
    owningShadowNode = containerShadowNode->cloneTree(child.node->getFamily(), [&](const ShadowNode &oldShadowNode) {
      clonedShadowNode = oldShadowNode.clone({});
      return clonedShadowNode;
    });
    containerShadowNode = static_cast<MarkdownContainerShadowNode *>(owningShadowNode.get());

    auto &layoutableShadowNode = static_cast<LayoutableShadowNode &>(*clonedShadowNode);
    if (!frame.placed) {
      layoutableShadowNode.setLayoutMetrics(LayoutMetrics{.frame = {}, .displayType = DisplayType::None});
      continue;
    }

    // The height is already on the pixel grid (rounding it up again adds a pixel
    // of float error); the width rounds up so the child keeps its measured width.
    const auto size = Size{roundToPixel<&std::ceil>(frame.width, layoutMetrics.pointScaleFactor),
                           roundToPixel<&std::round>(frame.height, layoutMetrics.pointScaleFactor)};
    const auto origin = roundToPixel<&std::round>(
        Point{contentFrame.origin.x + frame.x, contentFrame.origin.y + frame.y}, layoutMetrics.pointScaleFactor);

    LayoutConstraints constraints;
    constraints.minimumSize = size;
    constraints.maximumSize = size;
    constraints.layoutDirection = layoutMetrics.layoutDirection;
    layoutableShadowNode.layoutTree(layoutContext, constraints);

    auto slotLayoutMetrics = layoutableShadowNode.getLayoutMetrics();
    slotLayoutMetrics.frame.origin = origin;
    layoutableShadowNode.setLayoutMetrics(slotLayoutMetrics);
  }

  if (containerShadowNode != this) {
    this->children_ = static_cast<const MarkdownContainerShadowNode *>(containerShadowNode)->children_;
  }

  auto placements = slotPlacements();
  const auto &state = getStateData();
  if (state.getSlotPlacements() != placements) {
    setStateData(MarkdownTextState(state.getForceHeightRecalculationCounter(), std::move(placements)));
  }
}

} // namespace facebook::react
