#pragma once
#include "ENRMReactHeaders.h"
#include "MeasurementCache.h"
#include <ReactNativeEnrichedMarkdown/EnrichedMarkdownState.h>
#include <ReactNativeEnrichedMarkdown/EventEmitters.h>
#include <ReactNativeEnrichedMarkdown/Props.h>
#include <string>
#include <vector>

namespace facebook::react {

JSI_EXPORT extern const char EnrichedMarkdownComponentName[];

class EnrichedMarkdownShadowNode : public ConcreteViewShadowNode<EnrichedMarkdownComponentName, EnrichedMarkdownProps,
                                                                 EnrichedMarkdownEventEmitter, EnrichedMarkdownState> {
public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  EnrichedMarkdownShadowNode(const ShadowNodeFragment &fragment, const ShadowNodeFamily::Shared &family,
                             ShadowNodeTraits traits);

  EnrichedMarkdownShadowNode(const ShadowNode &sourceShadowNode, const ShadowNodeFragment &fragment);

  void dirtyLayoutIfNeeded();

  Size measureContent(const LayoutContext &layoutContext, const LayoutConstraints &layoutConstraints) const override;

  // Places the block slot children (React replacements for native blocks) where
  // the measurement walk put them, as ParagraphShadowNode does for inline views.
  void layout(LayoutContext layoutContext) override;

  static ShadowNodeTraits BaseTraits()
  {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

private:
  struct SlotChild {
    std::string id;
    const LayoutableShadowNode *node;
  };

  // Where the measurement walk put one slot child, in points relative to the
  // host's content box.
  struct SlotFrame {
    std::string id;
    Float x{0};
    Float y{0};
    Float width{0};
    Float height{0};
    bool placed{false};
  };

  // The last measurement with slots: its inputs (so an unchanged pass reuses it
  // instead of parsing and laying the document out again) and its outputs.
  // Yoga measures several times per pass and streaming commits every tick;
  // without this every pass would redo the whole document for each call.
  struct SlotMeasurement {
    bool valid{false};
    MeasurementCacheKey key;
    int counter{0};
    CGFloat width{-1};
    CGSize size{0, 0};
    std::vector<SlotFrame> frames;
  };

  std::vector<SlotChild> slotChildren() const;
  CGSize measureWithSlots(const std::vector<SlotChild> &slots, const LayoutContext &layoutContext,
                          const LayoutConstraints &layoutConstraints, CGFloat maxWidth) const;
  bool slotMeasurementMatches(const std::vector<SlotChild> &slots, const MeasurementCacheKey &key, int counter,
                              CGFloat width) const;
  std::vector<ENRMBlockSlotPlacement> slotPlacements() const;

  int localHeightRecalculationCounter_{0};
  mutable int lastExactMeasurementCounter_{0};
  mutable CGSize lastExactMeasurementSize_{0, 0};
  mutable SlotMeasurement slotMeasurement_;
};

} // namespace facebook::react
