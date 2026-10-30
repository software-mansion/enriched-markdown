#pragma once

#include "BlockSlotMeasureSession.h"
#include "ENRMReactHeaders.h"
#include "MarkdownContainerMeasurementManager.h"
#include "MarkdownTextState.h"

#include <react/renderer/components/EnrichedMarkdownTextSpec/EventEmitters.h>
#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>

namespace facebook::react {

JSI_EXPORT extern const char MarkdownContainerComponentName[];

class MarkdownContainerShadowNode final
    : public ConcreteViewShadowNode<MarkdownContainerComponentName, EnrichedMarkdownProps, EnrichedMarkdownEventEmitter,
                                    MarkdownTextState> {
public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  MarkdownContainerShadowNode(ShadowNode const &sourceShadowNode, ShadowNodeFragment const &fragment)
      : ConcreteViewShadowNode(sourceShadowNode, fragment),
        slotMeasurement_(static_cast<const MarkdownContainerShadowNode &>(sourceShadowNode).slotMeasurement_) {
    forceHeightRecalculationCounter_ =
        static_cast<const MarkdownContainerShadowNode &>(sourceShadowNode).forceHeightRecalculationCounter_;
    // New children, e.g. every frame of an animation inside a slot: the next pass
    // re-checks the slot heights before reusing the measurement (the clone already
    // dirtied Yoga for a children change).
    if (fragment.children) {
      slotMeasurement_.slotHeightsChecked = false;
    }
    dirtyLayoutIfNeeded();
  }

  // Slot children are ShadowNode children Yoga ignores; this node measures and
  // places them itself, like ParagraphShadowNode does for inline views.
  static ShadowNodeTraits BaseTraits() {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

  void setMeasurementsManager(const std::shared_ptr<MarkdownContainerMeasurementManager> &measurementsManager);

  void dirtyLayoutIfNeeded();

  Size measureContent(const LayoutContext &layoutContext, const LayoutConstraints &layoutConstraints) const override;

  void layout(LayoutContext layoutContext) override;

protected:
  bool shouldNewRevisionDirtyMeasurement(const ShadowNode &sourceShadowNode,
                                         const ShadowNodeFragment &fragment) const override;

private:
  // The last measurement with slots: its inputs, so an unchanged pass (Yoga
  // measures several times per pass, and streaming commits every tick) reuses
  // it instead of parsing and laying the document out through Kotlin again,
  // and its outputs. Props are immutable, so their identity stands in for a key.
  struct SlotMeasurement {
    bool valid{false};
    bool slotHeightsChecked{true};
    const void *props{nullptr};
    int counter{0};
    Float width{-1};
    Size size;
    std::vector<BlockSlotFrame> frames;
  };

  std::vector<BlockSlotChild> slotChildren() const;

  // Measures through Kotlin with a slot session installed and keeps the frames.
  Size measureWithSlots(const LayoutContext &layoutContext, const LayoutConstraints &layoutConstraints,
                        const std::vector<BlockSlotChild> &children) const;
  bool slotMeasurementMatches(const LayoutContext &layoutContext, LayoutDirection layoutDirection,
                              const std::vector<BlockSlotChild> &children, Float width) const;
  bool slotHeightsUnchanged(const LayoutContext &layoutContext, LayoutDirection layoutDirection,
                            const std::vector<BlockSlotChild> &children) const;
  std::vector<BlockSlotPlacement> slotPlacements() const;

  int forceHeightRecalculationCounter_{0};
  std::shared_ptr<MarkdownContainerMeasurementManager> measurementsManager_;
  mutable SlotMeasurement slotMeasurement_;
};

} // namespace facebook::react
